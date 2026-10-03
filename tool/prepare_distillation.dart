// Run with: flutter test tool/prepare_distillation.dart
// This offline tool uses flutter_test to load the same Flutter-backed rules as
// the app; it is not discovered by the normal `flutter test` suite.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaibitzer/ai/logos_prompt.dart';
import 'package:kaibitzer/distillation/teacher_example.dart';
import 'package:kaibitzer/engine/game.dart';
import 'package:kaibitzer/engine/point.dart';
import 'package:kaibitzer/engine/rules.dart';

void main() {
  test(
    'prepare existing local teacher probes for review, without inference',
    () {
      const destination = String.fromEnvironment(
        'DISTILLATION_REVIEW_OUTPUT',
        defaultValue: 'outputs/distillation-review.jsonl',
      );
      final rows = <Map<String, Object?>>[];
      final seen = <String>{};
      for (final path in [
        'outputs/logos-fidelity.json',
        'outputs/logos-budget-probes.json',
      ]) {
        final probes = jsonDecode(File(path).readAsStringSync()) as List;
        for (var i = 0; i < probes.length; i++) {
          final probe = probes[i] as Map<String, dynamic>;
          final fixture = probe['fixture'] as Map<String, dynamic>;
          final size = probe['size'] as int? ?? 19;
          final response = probe['response'] as Map<String, dynamic>;
          final text =
              response['response'] as String? ??
              (response['message'] as Map<String, dynamic>)['content']
                  as String;
          final key = '${fixture['user']}\n$text';
          if (!seen.add(key)) continue;
          final game = GoGame(GameRules.preset(boardSize: size));
          // The original 9x9 budget fixture was exported after Black C7.
          final moves =
              fixture['moves'] as List? ?? (size == 9 ? ['C7'] : null);
          expect(
            moves,
            isNotNull,
            reason: 'Missing move provenance in $path:$i',
          );
          for (final move in moves!) {
            final result = move == 'pass'
                ? game.pass()
                : game.play(Point.parse(move as String, size)!);
            expect(
              result.ok,
              isTrue,
              reason: '$path:$i: illegal history move $move',
            );
          }
          expect(
            logosUserPrompt(game),
            fixture['user'],
            reason: '$path:$i prompt drift',
          );
          expect(logosSystemPrompt(size: size), fixture['system']);
          rows.add(
            reviewTeacherExample(
              id: '$path:$i',
              game: game,
              response: text,
              teacher: 'logos-7b/Q8_0 (local Ollama)',
              finishReason: response['done_reason'] as String?,
            ),
          );
        }
      }
      File(
        destination,
      ).writeAsStringSync('${rows.map(jsonEncode).join('\n')}\n');
      final rejected = rows.where((r) => r['status'] == 'rejected').length;
      // No model training records are emitted: legal moves and teacher prose
      // still require review before they can supervise a smaller model.
      stdout.writeln(
        '${rows.length} unique examples: $rejected rejected, '
        '${rows.length - rejected} pending review. Wrote $destination',
      );
    },
  );
}

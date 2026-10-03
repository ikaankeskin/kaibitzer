import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaibitzer/ai/logos_engine.dart';
import 'package:kaibitzer/ai/engine_log.dart';
import 'package:kaibitzer/ai/logos_prompt.dart';
import 'package:kaibitzer/ai/move_engine.dart';
import 'package:kaibitzer/coach/kaibitzer_coach.dart';
import 'package:kaibitzer/engine/game.dart';
import 'package:kaibitzer/engine/point.dart';
import 'package:kaibitzer/engine/rules.dart';

class RecordingFallback extends HeuristicEngine {
  int moves = 0;
  int hints = 0;
  @override
  Future<Point?> genMove(GoGame game, AiLevel level) async {
    moves++;
    return Point.parse('A1', game.size);
  }

  @override
  Future<List<MoveRecommendation>> analyze(GoGame game, {int max = 3}) async {
    hints++;
    return [];
  }
}

void main() {
  test('recorded local inference replays through the current app', () async {
    final probes = jsonDecode(File('outputs/logos-fidelity.json').readAsStringSync()) as List;
    final expected = ['A1', 'A1', 'A1', 'Q3', 'E15', 'A1'];
    expect(probes.length, expected.length);
    for (var i = 0; i < probes.length; i++) {
      final probe = probes[i];
      final fixture = probe['fixture'];
      final game = GoGame(GameRules.preset(boardSize: 19));
      for (final move in fixture['moves']) {
        if (move == 'pass') {
          expect(game.pass().ok, isTrue);
        } else {
          expect(game.play(Point.parse(move, 19)!).ok, isTrue);
        }
      }
      expect(logosUserPrompt(game), fixture['user']);
      expect(logosBoardMatrix(game), fixture['matrix']);
      final response = Map<String, dynamic>.from(probe['response']);
      if (probe['mode'] == 'raw') {
        response['message'] = {'content': response['response']};
      }
      final client = MockClient((_) async => http.Response(jsonEncode(response), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      final fallback = RecordingFallback();
      final engine = LogosEngine(client: client, fallback: fallback);
      expect(await engine.genMove(game, AiLevel.hard), Point.parse(expected[i], 19));
      expect(fallback.moves, expected[i] == 'A1' ? 1 : 0);
      await engine.dispose();
      client.close();
    }
  });

  for (final endpoint in [
    'http://localhost:11435',
    'http://localhost:11435/v1',
  ]) {
    for (final reply in [
      '<answer>\\boxed{下一步颜色:白}\\boxed{下一步位置:D16}</answer>',
      '<answer>\\boxed{下一步位置:D16}</answer>',
      '<reasoning>Try D16',
      '<answer>\\boxed{下一步颜色:黑}\\boxed{下一步位置:D16}',
      '<answer>下一步颜色:黑 下一步颜色:白 下一步位置:D16</answer>',
      '<answer>下一步颜色:黑 We considered D16.</answer>',
      '<answer>下一步颜色:白 下一步位置:pass</answer>',
    ]) {
      test(
        '$endpoint rejects untrusted answer $reply for moves and hints',
        () async {
          final fallback = RecordingFallback();
          final client = MockClient(
            (request) async => http.Response(
              jsonEncode(
                endpoint.endsWith('/v1')
                    ? {
                        'choices': [
                          {
                            'message': {'content': reply},
                          },
                        ],
                      }
                    : {
                        'message': {'content': reply},
                      },
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          );
          final engine = LogosEngine(
            client: client,
            baseUrl: endpoint,
            fallback: fallback,
          );
          final game = GoGame(GameRules.preset(boardSize: 19));
          expect(
            await engine.genMove(game, AiLevel.hard),
            Point.parse('A1', 19),
          );
          expect(await engine.analyze(game), isEmpty);
          expect(fallback.moves, 1);
          expect(fallback.hints, 1);
          await engine.dispose();
          client.close();
        },
      );
    }
  }
  for (final size in [9, 13]) {
    test('$size board uses tutor without requesting unsupported inference', () async {
      final fallback = RecordingFallback();
      final logs = <EngineLogEntry>[];
      final client = MockClient((_) async => throw StateError('must not request'));
      final engine = LogosEngine(client: client, fallback: fallback, log: logs.add);
      final game = GoGame(GameRules.preset(boardSize: size));
      expect(await engine.genMove(game, AiLevel.hard), Point.parse('A1', size));
      expect(await engine.analyze(game), isEmpty);
      expect(fallback.moves, 1); expect(fallback.hints, 1);
      expect(logs.where((e) => e.summary.contains('limited to 19×19')), hasLength(2));
      await engine.dispose(); client.close();
    });
  }

  for (final openai in [false, true]) {
    test('reports token truncation distinctly on ${openai ? 'OpenAI' : 'Ollama'}', () async {
      final logs = <EngineLogEntry>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(openai ? body['max_tokens'] : body['options']['num_predict'], 1024);
        return http.Response(jsonEncode(openai
            ? {'choices': [{'finish_reason': 'length', 'message': {'content': '<reasoning>unfinished'}}]}
            : {'done_reason': 'length', 'message': {'content': '<reasoning>unfinished'}}),
            200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final engine = LogosEngine(client: client, baseUrl: openai ? 'http://localhost/v1' : 'http://localhost',
          fallback: RecordingFallback(), log: logs.add);
      final game = GoGame(GameRules.preset(boardSize: 19));
      await engine.genMove(game, AiLevel.hard);
      await engine.analyze(game);
      expect(logs.where((e) => e.summary.contains('token limit reached')), hasLength(2));
      expect(logs.where((e) => e.summary.contains('Token limit reached before a complete answer')), hasLength(2));
      expect(logs.any((e) => e.summary.contains('request failed')), isFalse);
      await engine.dispose();
      client.close();
    });
  }
  test('wrong player is reply rejection, HTTP failure is request failure', () async {
    final logs = <EngineLogEntry>[];
    var fail = false;
    final client = MockClient((_) async => fail
        ? http.Response('unavailable', 503)
        : http.Response(jsonEncode({'message': {'content': '<answer>下一步颜色:白 下一步位置:D4</answer>'}}),
            200, headers: {'content-type': 'application/json; charset=utf-8'}));
    final engine = LogosEngine(client: client, fallback: RecordingFallback(), log: logs.add);
    final game = GoGame(GameRules.preset(boardSize: 19));
    await engine.genMove(game, AiLevel.hard);
    expect(logs.any((e) => e.summary.contains('Answer names White; expected Black')), isTrue);
    expect(logs.any((e) => e.summary.contains('request failed')), isFalse);
    logs.clear(); fail = true;
    await engine.genMove(game, AiLevel.hard);
    expect(logs.any((e) => e.summary.contains('LoGos request failed')), isTrue);
    expect(logs.any((e) => e.summary.contains('reply rejected')), isFalse);
    await engine.dispose(); client.close();
  });

  test('accepts matching player and pass after a Black move', () async {
    final fallback = RecordingFallback();
    var reply = '<answer>下一步颜色:白 下一步位置:D16 下一步胜率:55</answer>';
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'message': {'content': reply},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final engine = LogosEngine(client: client, fallback: fallback);
    final game = GoGame(GameRules.preset(boardSize: 19));
    game.play(Point.parse('Q16', 19)!);
    expect(await engine.genMove(game, AiLevel.hard), Point.parse('D16', 19));
    expect((await engine.analyze(game)).single.point, Point.parse('D16', 19));
    reply = '<answer>下一步颜色:白 下一步位置:pass</answer>';
    expect(await engine.genMove(game, AiLevel.hard), isNull);
    expect(fallback.moves, 0);
    expect(fallback.hints, 0);
    await engine.dispose();
    client.close();
  });
}

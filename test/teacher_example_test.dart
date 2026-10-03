import 'package:flutter_test/flutter_test.dart';
import 'package:kaibitzer/distillation/teacher_example.dart';
import 'package:kaibitzer/engine/game.dart';
import 'package:kaibitzer/engine/point.dart';
import 'package:kaibitzer/engine/rules.dart';

void main() {
  Map<String, Object?> review(String text, {int size = 19, GoGame? game}) =>
      reviewTeacherExample(
        id: 'test',
        game: game ?? GoGame(GameRules.preset(boardSize: size)),
        response: text,
        teacher: 'test-teacher',
      );
  test('legal teacher answer remains pending explanation and quality review', () {
    final result = review(
      '<reasoning>Example explanation.</reasoning><answer>下一步颜色:黑 下一步位置:D4 下一步胜率:99</answer>',
    );
    expect(result['status'], 'needs_review');
    expect(result['teacher_move'], 'D4');
    expect(result['teacher_explanation'], 'Example explanation.');
    expect(result['explanation_reviewed'], isFalse);
    expect(result['move_quality_reviewed'], isFalse);
    expect(result.containsKey('winrate'), isFalse);
  });
  for (final entry in {
    '<reasoning>D4</reasoning>': 'incomplete_answer',
    '<answer>下一步颜色:白 下一步位置:D4</answer>': 'missing_conflicting_or_wrong_player',
    '<answer>下一步颜色:黑 下一步位置:D20</answer>': 'missing_off_board_or_ambiguous_move',
    '<answer>下一步颜色:黑 下一步位置:D4 下一步位置:Q16</answer>': 'ambiguous_answer',
  }.entries) {
    test(
      'rejects ${entry.value}',
      () => expect(review(entry.key)['rejection'], entry.value),
    );
  }
  test('rejects occupied point, but preserves legal pass', () {
    final game = GoGame(GameRules.preset(boardSize: 19));
    game.play(Point.parse('D4', 19)!);
    expect(
      review('<answer>下一步颜色:白 下一步位置:D4</answer>', game: game)['rejection'],
      'illegal_move',
    );
    expect(
      review('<answer>下一步颜色:白 下一步位置:pass</answer>', game: game)['teacher_move'],
      'pass',
    );
  });
  test('unsupported board never becomes a training candidate', () {
    expect(
      review('<answer>下一步颜色:黑 下一步位置:D4</answer>', size: 9)['rejection'],
      'unsupported_teacher_board_size',
    );
  });
}

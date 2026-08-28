import 'package:flutter_test/flutter_test.dart';
import 'package:kaibitzer/ai/engine_log.dart';
import 'package:kaibitzer/ai/logos_prompt.dart';
import 'package:kaibitzer/engine/point.dart';
import 'package:kaibitzer/engine/rules.dart';
import 'package:kaibitzer/engine/game.dart';

void main() {
  test('parses boxed LoGos coordinates and win rate', () {
    const text = '''
<reasoning>star point</reasoning>
<answer>
\\boxed{下一步颜色:黑}
\\boxed{下一步位置:Q16}
\\boxed{下一步胜率:61.5}
</answer>
''';
    final parsed = parseLogosResponse(text, 19);
    expect(parsed.point, const Point(15, 3));
    expect(parsed.winrate, closeTo(0.615, 0.0001));
    expect(parsed.isPass, isFalse);
  });

  test('parses a pass reply', () {
    const text = '<answer>\\boxed{下一步位置:pass}</answer>';
    final parsed = parseLogosResponse(text, 19);
    expect(parsed.point, isNull);
    expect(parsed.isPass, isTrue);
  });

  test('builds LoGos Chinese board prompt', () {
    final game = GoGame(GameRules.preset(boardSize: 9));
    game.play(const Point(4, 4));
    final prompt = logosUserPrompt(game);
    expect(prompt, contains('以下是当前的对局记录：'));
    expect(prompt, contains('1.X-E5'));
    expect(prompt, contains('当前盘面情况为:[['));
    expect(prompt, contains('1'));
    expect(prompt, contains('下一步颜色为白'));
    expect(prompt, contains('请遵循给出的格式，预测并分析下一步的落子位置。'));
    expect(logosSystemPrompt(size: 9), contains('棋盘的大小为9x9'));
    expect(logosBoardMatrix(game), contains('[0, 0, 0, 0, 1, 0, 0, 0, 0]'));
  });

  test('formats Ollama nanosecond timings', () {
    expect(formatEngineDuration(const Duration(milliseconds: 340)), '340ms');
    expect(formatEngineDuration(const Duration(milliseconds: 12400)), '12.4s');
    expect(durationFromNanos(3013701500), const Duration(microseconds: 3013702));
    expect(tokensPerSecond(298, const Duration(milliseconds: 2571)), '115.9 tok/s');
  });
}

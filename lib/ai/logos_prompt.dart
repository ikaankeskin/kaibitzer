import '../engine/game.dart';
import '../engine/point.dart';
import '../engine/stone.dart';

/// LoGos-7B system prompt, matching the Hugging Face inference template.
String logosSystemPrompt({int size = 19}) {
  return '你是一个精通各种围棋策略、理念和围棋下法的围棋职业棋手。你现在在进行一盘棋局的对弈，你需要根据棋盘信息对接下来的下法进行合理的预测。'
      '你的回复语言风格严谨认真而不失趣味，同时你乐于和对手进行友好的互动。你的任务是根据给定的棋局记录，分析局面信息，挑选若干可能的下一步并进行分析，'
      '推演对应的后续变化，进行合理的分析与思考，总结并挑选出最好的下一步位置，并最终形成一个有趣生动和富含思考的回复。'
      '在给出的棋局中，"X"表示黑棋，"O"表示白棋。棋盘的大小为${size}x$size，每个落子的坐标是一个字母加上一个数字的形式。'
      '字母为A-T(跳过I)，对应于棋盘上从左到右。数字为1-$size，对应于棋盘上从下到上。\n'
      '你需要首先对当前局面进行合理的分析和思考，对后续的步骤进行合理的预测、推演和分析，并最后总结你的思考结果，选择出最合适的下一步。'
      '请进行严谨详细、生动自然的推理和分析，及时进行总结，并最终输出符合格式要求的结果。你的输出格式为:\n\n'
      '<reasoning>\n你的思考过程。\n</reasoning>\n\n'
      '<answer>\n\\boxed{下一步颜色:黑/白}\n\\boxed{下一步位置:落子位置}\n\\boxed{下一步胜率:胜率}\n\n</answer>\n';
}

/// Move list + board matrix in the Chinese template LoGos was trained on.
String logosUserPrompt(GoGame game) {
  final size = game.size;
  final toPlay = game.toPlay == Stone.black ? '黑' : '白';
  final moves = <String>[];
  var n = 0;
  for (final move in game.moves) {
    if (move.kind == MoveKind.place && move.point != null) {
      final mark = move.player == Stone.black ? 'X' : 'O';
      moves.add('${++n}.$mark-${move.point!.toCoordinate(size)}');
    } else if (move.kind == MoveKind.pass) {
      final mark = move.player == Stone.black ? 'X' : 'O';
      moves.add('${++n}.$mark-pass');
    }
  }
  final record = moves.join('\n');
  return '以下是当前的对局记录：\n\n$record\n\n\n'
      '当前盘面情况为:${logosBoardMatrix(game)}\n'
      '其中1表示黑棋，-1表示白棋，0表示空位。\n'
      '下一步颜色为$toPlay。\n\n'
      '请遵循给出的格式，预测并分析下一步的落子位置。';
}

/// Python-style nested list, as produced by LoGos's gogame board renderer.
String logosBoardMatrix(GoGame game) {
  final size = game.size;
  final rows = <String>[];
  for (var y = 0; y < size; y++) {
    final cells = <String>[];
    for (var x = 0; x < size; x++) {
      final stone = game.board.at(Point(x, y));
      cells.add(switch (stone) {
        Stone.black => '1',
        Stone.white => '-1',
        Stone.empty => '0',
      });
    }
    rows.add('[${cells.join(', ')}]');
  }
  return '[${rows.join(', ')}]';
}

class LogosParseResult {
  final Point? point;
  final List<Point> candidates;
  final double? winrate;
  final bool isPass;
  final String raw;

  const LogosParseResult({
    required this.point,
    required this.candidates,
    required this.winrate,
    required this.isPass,
    required this.raw,
  });
}

LogosParseResult parseLogosResponse(String text, int boardSize) {
  final answer = RegExp(r'<answer>(.*?)</answer>', dotAll: true, caseSensitive: false)
          .firstMatch(text)
          ?.group(1) ??
      text;
  final coords = <Point>[];
  final seen = <Point>{};
  void add(Point? p) {
    if (p != null && seen.add(p)) {
      coords.add(p);
    }
  }

  final boxedPos = RegExp(r'下一步位置\s*[:：]\s*([A-HJ-T]\d{1,2})', caseSensitive: false);
  for (final match in boxedPos.allMatches(answer)) {
    add(Point.parse(match.group(1)!, boardSize));
  }
  for (final match in RegExp(r'\\boxed\{([A-HJ-T]\d{1,2})\}', caseSensitive: false)
      .allMatches(answer)) {
    add(Point.parse(match.group(1)!, boardSize));
  }
  if (coords.isEmpty) {
    for (final match in RegExp(r'\b([A-HJ-T]\d{1,2})\b').allMatches(answer)) {
      add(Point.parse(match.group(1)!, boardSize));
    }
  }
  final winMatch = RegExp(r'下一步胜率\s*[:：]\s*([0-9.]+)').firstMatch(answer);
  var winrate = winMatch == null ? null : double.tryParse(winMatch.group(1)!);
  if (winrate != null && winrate > 1) {
    winrate = winrate / 100;
  }
  final isPass = coords.isEmpty &&
      RegExp(r'下一步位置\s*[:：]\s*(pass|PASS|停|虚手)', caseSensitive: false)
          .hasMatch(answer);
  return LogosParseResult(
    point: coords.isEmpty ? null : coords.first,
    candidates: coords,
    winrate: winrate,
    isPass: isPass,
    raw: text,
  );
}

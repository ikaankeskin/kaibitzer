import '../engine/game.dart';
import '../engine/point.dart';
import '../engine/rules.dart';
import '../engine/stone.dart';

class MoveRecommendation {
  final Point point;
  final double score;
  final List<String> reasons;

  const MoveRecommendation({
    required this.point,
    required this.score,
    required this.reasons,
  });

  String get headline => reasons.isEmpty ? 'A solid continuation' : reasons.first;
}

class GroupInfo {
  final Stone color;
  final Set<Point> stones;
  final Set<Point> liberties;

  const GroupInfo({
    required this.color,
    required this.stones,
    required this.liberties,
  });

  int get size => stones.length;
  int get libertyCount => liberties.length;
  bool get inAtari => libertyCount == 1;
  bool get weak => libertyCount <= 2;
}

class PositionAdvice {
  final List<MoveRecommendation> moves;
  final String summary;
  final List<GroupInfo> weakGroups;
  final String scoreHint;

  const PositionAdvice({
    required this.moves,
    required this.summary,
    required this.weakGroups,
    required this.scoreHint,
  });
}

class CoachMessage {
  final bool fromCoach;
  final String text;
  final List<MoveRecommendation> recommendations;

  const CoachMessage({
    required this.fromCoach,
    required this.text,
    this.recommendations = const [],
  });
}

class KaibitzerCoach {
  PositionAdvice analyze(GoGame game, {int maxMoves = 3}) {
    final groups = _groups(game);
    final weak = groups.where((g) => g.weak).toList()
      ..sort((a, b) => a.libertyCount.compareTo(b.libertyCount));
    final recs = recommend(game, max: maxMoves);
    final score = game.currentScore();
    final stoneCount =
        game.board.stoneCount(Stone.black) + game.board.stoneCount(Stone.white);

    final buffer = StringBuffer();
    if (game.phase != GamePhase.playing) {
      buffer.write(game.resultText ?? 'The game is not in progress.');
    } else if (stoneCount < 4) {
      buffer.write(_openingSummary(game));
    } else {
      buffer.write(
        'Move ${game.moves.where((m) => m.kind == MoveKind.place).length + 1}, '
        '${game.toPlay.label} to play. ',
      );
      if (weak.isNotEmpty) {
        final hottest = weak.first;
        final coord = hottest.stones.first.toCoordinate(game.size);
        buffer.write(
          '${hottest.color.label} has a ${hottest.size}-stone group near $coord '
          'with ${hottest.libertyCount} '
          '${hottest.libertyCount == 1 ? 'liberty' : 'liberties'}. ',
        );
      } else {
        buffer.write('Groups look stable for the moment. ');
      }
      buffer.write(
        'Estimated ${score.method.toLowerCase()} score: Black ${score.black} — White ${score.white}.',
      );
    }

    return PositionAdvice(
      moves: recs,
      summary: buffer.toString(),
      weakGroups: weak,
      scoreHint: score.summary,
    );
  }

  List<MoveRecommendation> recommend(GoGame game, {int max = 3}) {
    if (game.phase != GamePhase.playing) {
      return const [];
    }
    final legal = game.legalMoves();
    if (legal.isEmpty) {
      return const [];
    }
    final ranked = <MoveRecommendation>[];
    for (final point in legal) {
      ranked.add(_evaluate(game, point));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(max).toList();
  }

  CoachMessage answer(GoGame game, String question) {
    final q = question.trim();
    if (q.isEmpty) {
      return const CoachMessage(
        fromCoach: true,
        text: 'Ask me for a move, a score estimate, or to look at weak groups.',
      );
    }
    final lower = q.toLowerCase();
    final advice = analyze(game);
    final mentioned = Point.parse(q, game.size);

    if (_matches(lower, ['resign', 'give up'])) {
      return CoachMessage(
        fromCoach: true,
        text: game.currentScore().margin.abs() > 30
            ? 'The gap is large. Resigning is reasonable if this is a teaching game — or keep playing to practice endgame.'
            : 'The position still looks playable. I would keep going.',
      );
    }

    if (mentioned != null &&
        _matches(lower, ['why', 'explain', 'what about', 'how about'])) {
      return CoachMessage(
        fromCoach: true,
        text: _explainPoint(game, mentioned),
      );
    }

    if (_matches(lower, [
      'recommend',
      'hint',
      'suggest',
      'where',
      'what should',
      'best move',
      'good move',
      'play',
    ])) {
      if (advice.moves.isEmpty) {
        return CoachMessage(fromCoach: true, text: advice.summary);
      }
      return CoachMessage(
        fromCoach: true,
        text: _formatRecommendations(game, advice),
        recommendations: advice.moves,
      );
    }

    if (_matches(lower, ['score', 'winning', 'who is', "who's", 'ahead', 'komi'])) {
      final score = game.currentScore();
      return CoachMessage(
        fromCoach: true,
        text:
            '${advice.summary}\n\nThis is a living-stone estimate under ${game.rules.ruleSet.title} rules '
            '(${score.method.toLowerCase()} scoring, komi ${game.rules.komi}). '
            'Mark dead stones after two passes for a real result.',
      );
    }

    if (_matches(lower, ['atari', 'weak', 'danger', 'capture', 'liberty'])) {
      if (advice.weakGroups.isEmpty) {
        return const CoachMessage(
          fromCoach: true,
          text: 'I do not see anything in atari. Both sides still have breathing room.',
        );
      }
      final lines = advice.weakGroups.take(5).map((g) {
        final sample = g.stones.first.toCoordinate(game.size);
        return '• ${g.color.label} group near $sample: ${g.size} stones, ${g.libertyCount} '
            '${g.libertyCount == 1 ? 'liberty (atari!)' : 'liberties'}';
      });
      return CoachMessage(
        fromCoach: true,
        text: 'Urgent shapes:\n${lines.join('\n')}',
      );
    }

    if (_matches(lower, ['rule', 'variant', 'ko', 'suicide', 'komi', 'handicap'])) {
      return CoachMessage(
        fromCoach: true,
        text:
            'This game is ${game.rules.description}. ${game.rules.ruleSet.summary} '
            '${game.rules.suicideAllowed ? 'Suicide is allowed.' : 'Suicide is illegal.'} '
            '${game.rules.usesSuperko ? 'Positional superko is on.' : 'Simple ko is on.'}',
      );
    }

    return CoachMessage(
      fromCoach: true,
      text: '${advice.summary}\n\n${_formatRecommendations(game, advice)}',
      recommendations: advice.moves,
    );
  }

  MoveRecommendation _evaluate(GoGame game, Point point) {
    final reasons = <String>[];
    var score = 0.0;
    final player = game.toPlay;
    final opponent = player.opponent;
    final coord = point.toCoordinate(game.size);
    final fork = game.fork();
    final result = fork.play(point);
    final captured = result.captured;

    if (captured.isNotEmpty) {
      final n = captured.length;
      score += 18 + n * 12;
      reasons.add('Captures $n ${n == 1 ? 'stone' : 'stones'}');
    }

    // Save own groups that were in atari.
    for (final n in game.board.neighbors(point)) {
      if (game.board.at(n) == player && game.board.libertyCount(n) == 1) {
        final size = game.board.groupAt(n).length;
        score += 16 + size * 6;
        reasons.add('Saves your $size-stone group from atari');
      }
      if (game.board.at(n) == opponent && game.board.libertyCount(n) == 2) {
        final size = game.board.groupAt(n).length;
        if (fork.board.at(n) == opponent && fork.board.libertyCount(n) == 1) {
          score += 10 + size * 4;
          reasons.add('Puts a $size-stone group in atari');
        }
      }
    }

    if (result.ok) {
      final libs = fork.board.libertyCount(point);
      if (libs == 1 && captured.isEmpty) {
        score -= 22;
        reasons.add('Self-atari — usually avoid this');
      } else if (libs >= 4) {
        score += 2;
      }
    }

    final neighborsOwn =
        game.board.neighbors(point).where((n) => game.board.at(n) == player).length;
    final neighborsOpp =
        game.board.neighbors(point).where((n) => game.board.at(n) == opponent).length;
    if (neighborsOwn >= 2) {
      score += 5;
      reasons.add('Connects your stones');
    }
    if (neighborsOpp >= 2 && neighborsOwn > 0) {
      score += 4;
      reasons.add('Fights for a cutting point');
    }

    if (_fillsOwnEye(game, point, player)) {
      score -= 80;
      reasons.add('Fills your own eye');
    }

    final stonesOnBoard =
        game.board.stoneCount(Stone.black) + game.board.stoneCount(Stone.white);
    score += _openingBonus(game, point, stonesOnBoard, reasons);
    score += _influence(game, point, player) * 0.35;

    // Prefer staying near the action once the board is populated.
    if (stonesOnBoard >= 8) {
      score += _proximityToStones(game, point) * 1.4;
    }

    if (game.rules.winCondition == WinCondition.captureGo) {
      if (captured.isNotEmpty) {
        score += 40;
        reasons.add('Capture Go: this takes stones toward the goal');
      }
    }

    if (reasons.isEmpty) {
      reasons.add('Extends influence around $coord');
    }

    return MoveRecommendation(point: point, score: score, reasons: reasons);
  }

  String _formatRecommendations(GoGame game, PositionAdvice advice) {
    if (advice.moves.isEmpty) {
      return 'I do not have a legal recommendation right now. Passing may be correct.';
    }
    final lines = <String>[];
    for (var i = 0; i < advice.moves.length; i++) {
      final move = advice.moves[i];
      final coord = move.point.toCoordinate(game.size);
      lines.add('${i + 1}. $coord — ${move.headline}');
    }
    return 'Recommended for ${game.toPlay.label}:\n${lines.join('\n')}';
  }

  String _explainPoint(GoGame game, Point point) {
    final coord = point.toCoordinate(game.size);
    final stone = game.board.at(point);
    if (stone.isPlayer) {
      final libs = game.board.libertyCount(point);
      final size = game.board.groupAt(point).length;
      return '$coord is ${stone.label}, a $size-stone group with $libs '
          '${libs == 1 ? 'liberty (atari)' : 'liberties'}.';
    }
    if (!game.isLegal(point)) {
      return '$coord is not legal for ${game.toPlay.label} right now.';
    }
    final rec = _evaluate(game, point);
    return 'If ${game.toPlay.label} plays $coord: ${rec.reasons.join('; ')}.';
  }

  String _openingSummary(GoGame game) {
    final size = game.size;
    if (size >= 17) {
      return 'Opening on $size×$size. Corners first — 4-4 (star point) is a balanced start, 3-4 leans toward territory.';
    }
    if (size >= 13) {
      return 'On $size×$size the corners still matter, but the center arrives quickly. Take a star point or approach.';
    }
    return 'Small-board opening: the first stone often belongs near the center or a 3-3 point so you do not get boxed in.';
  }

  double _openingBonus(
    GoGame game,
    Point point,
    int stonesOnBoard,
    List<String> reasons,
  ) {
    if (stonesOnBoard > 12) {
      return 0;
    }
    var bonus = 0.0;
    final size = game.size;
    final h = size <= 9 ? 2 : 3;
    final star = game.board.hoshiPoints();
    if (star.contains(point) && stonesOnBoard < 8) {
      bonus += 14;
      reasons.add('Star-point opening');
    }
    // 3-4 and 4-4 style points on larger boards.
    if (size >= 13) {
      final threeFour = <Point>{
        Point(h - 1, h),
        Point(h, h - 1),
        Point(size - h, h),
        Point(size - 1 - h, h - 1),
        Point(h - 1, size - 1 - h),
        Point(h, size - h),
        Point(size - h, size - 1 - h),
        Point(size - 1 - h, size - h),
      };
      if (threeFour.contains(point)) {
        bonus += 11;
        reasons.add('3-4 point: a territorial corner');
      }
    }
    if (size <= 9 && point.x == size ~/ 2 && point.y == size ~/ 2) {
      bonus += 10;
      reasons.add('Tengen is a classic 9×9 opening');
    }
    return bonus;
  }

  double _influence(GoGame game, Point point, Stone player) {
    var value = 0.0;
    for (final p in game.board.intersections) {
      final stone = game.board.at(p);
      if (!stone.isPlayer) {
        continue;
      }
      final dx = (p.x - point.x).abs();
      final dy = (p.y - point.y).abs();
      final dist = dx + dy;
      if (dist == 0 || dist > 6) {
        continue;
      }
      final w = 1 / dist;
      value += stone == player ? w : -w * 0.8;
    }
    return value;
  }

  double _proximityToStones(GoGame game, Point point) {
    var best = 99;
    for (final p in game.board.intersections) {
      if (!game.board.at(p).isPlayer) {
        continue;
      }
      final d = (p.x - point.x).abs() + (p.y - point.y).abs();
      if (d < best) {
        best = d;
      }
    }
    if (best >= 8) {
      return -3;
    }
    return (6 - best).clamp(-3, 5).toDouble();
  }

  bool _fillsOwnEye(GoGame game, Point point, Stone player) {
    final neighbors = game.board.neighbors(point).toList();
    if (neighbors.isEmpty) {
      return false;
    }
    return neighbors.every((n) => game.board.at(n) == player);
  }

  List<GroupInfo> _groups(GoGame game) {
    final seen = <Point>{};
    final groups = <GroupInfo>[];
    for (final p in game.board.intersections) {
      final stone = game.board.at(p);
      if (!stone.isPlayer || seen.contains(p)) {
        continue;
      }
      final stones = game.board.groupAt(p);
      seen.addAll(stones);
      groups.add(
        GroupInfo(
          color: stone,
          stones: stones,
          liberties: game.board.libertiesOf(stones),
        ),
      );
    }
    return groups;
  }

  bool _matches(String text, List<String> keys) =>
      keys.any(text.contains);
}

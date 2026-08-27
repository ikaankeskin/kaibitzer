import 'board.dart';
import 'handicap.dart';
import 'point.dart';
import 'rules.dart';
import 'scoring.dart';
import 'stone.dart';

enum GamePhase { playing, scoring, finished }

enum MoveKind { place, pass, resign }

class GameMove {
  final MoveKind kind;
  final Point? point;
  final Stone player;

  const GameMove({required this.kind, required this.player, this.point});

  String notation(int boardSize) {
    switch (kind) {
      case MoveKind.pass:
        return '${player.label} pass';
      case MoveKind.resign:
        return '${player.label} resigns';
      case MoveKind.place:
        return '${player.label} ${point!.toCoordinate(boardSize)}';
    }
  }
}

class PlayResult {
  final bool ok;
  final String? reason;
  final List<Point> captured;

  const PlayResult._(this.ok, this.reason, this.captured);

  factory PlayResult.success({List<Point> captured = const []}) =>
      PlayResult._(true, null, captured);

  factory PlayResult.illegal(String reason) =>
      PlayResult._(false, reason, const []);
}

class _Snapshot {
  final Board board;
  final Stone toPlay;
  final Point? koPoint;
  final int blackCaptures;
  final int whiteCaptures;
  final int consecutivePasses;
  final int blackPassStones;
  final int whitePassStones;
  final GamePhase phase;
  final Set<Point> deadStones;
  final Stone? winner;
  final String? resultText;
  final GameMove? lastMove;

  _Snapshot({
    required this.board,
    required this.toPlay,
    required this.koPoint,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.consecutivePasses,
    required this.blackPassStones,
    required this.whitePassStones,
    required this.phase,
    required this.deadStones,
    required this.winner,
    required this.resultText,
    required this.lastMove,
  });
}

class GoGame {
  final GameRules rules;
  Board board;
  Stone toPlay;
  Point? koPoint;
  int blackCaptures;
  int whiteCaptures;
  int consecutivePasses;
  int blackPassStones;
  int whitePassStones;
  GamePhase phase;
  Set<Point> deadStones;
  Stone? winner;
  String? resultText;
  GameMove? lastMove;
  final List<GameMove> moves;
  final List<String> _positionHistory;
  final List<_Snapshot> _undo;

  GoGame(this.rules)
      : board = Board.empty(rules.boardSize),
        toPlay = rules.handicap >= 2 ? Stone.white : Stone.black,
        koPoint = null,
        blackCaptures = 0,
        whiteCaptures = 0,
        consecutivePasses = 0,
        blackPassStones = 0,
        whitePassStones = 0,
        phase = GamePhase.playing,
        deadStones = <Point>{},
        winner = null,
        resultText = null,
        lastMove = null,
        moves = <GameMove>[],
        _positionHistory = <String>[],
        _undo = <_Snapshot>[] {
    for (final p in handicapPoints(rules)) {
      board.set(p, Stone.black);
    }
    _positionHistory.add(_situationalKey(board, toPlay));
  }

  int get size => rules.boardSize;

  int capturesFor(Stone stone) =>
      stone == Stone.black ? blackCaptures : whiteCaptures;

  bool get canUndo => _undo.isNotEmpty;

  ScoreResult currentScore() {
    return scoreBoard(
      board: board,
      areaScoring: rules.areaScoring,
      komi: rules.komi,
      blackCaptures: blackCaptures,
      whiteCaptures: whiteCaptures,
      dead: deadStones,
      blackPassStones: blackPassStones,
      whitePassStones: whitePassStones,
    );
  }

  PlayResult play(Point point) {
    if (phase != GamePhase.playing) {
      return PlayResult.illegal('The game is not in progress.');
    }
    final simulated = _simulate(point, toPlay);
    if (simulated == null) {
      return PlayResult.illegal(_illegalReason(point, toPlay));
    }
    _pushUndo();
    final captured = simulated.captured;
    board = simulated.board;
    if (toPlay == Stone.black) {
      blackCaptures += captured.length;
    } else {
      whiteCaptures += captured.length;
    }
    lastMove = GameMove(kind: MoveKind.place, player: toPlay, point: point);
    moves.add(lastMove!);
    consecutivePasses = 0;
    koPoint = simulated.koPoint;
    toPlay = toPlay.opponent;
    _positionHistory.add(_situationalKey(board, toPlay));

    if (rules.winCondition == WinCondition.captureGo) {
      final leader = blackCaptures >= rules.captureGoal
          ? Stone.black
          : whiteCaptures >= rules.captureGoal
              ? Stone.white
              : null;
      if (leader != null) {
        _finish(leader, '${leader.label} captures ${rules.captureGoal} first');
      }
    }
    return PlayResult.success(captured: captured);
  }

  PlayResult pass() {
    if (phase != GamePhase.playing) {
      return PlayResult.illegal('The game is not in progress.');
    }
    _pushUndo();
    lastMove = GameMove(kind: MoveKind.pass, player: toPlay);
    moves.add(lastMove!);
    if (rules.ruleSet == RuleSet.aga) {
      if (toPlay == Stone.black) {
        blackPassStones++;
      } else {
        whitePassStones++;
      }
    }
    consecutivePasses++;
    koPoint = null;
    toPlay = toPlay.opponent;
    _positionHistory.add(_situationalKey(board, toPlay));
    if (consecutivePasses >= 2) {
      if (rules.winCondition == WinCondition.captureGo) {
        _finish(
          null,
          'No captures reached the goal — game ends without a winner',
        );
      } else {
        phase = GamePhase.scoring;
      }
    }
    return PlayResult.success();
  }

  PlayResult resign() {
    if (phase == GamePhase.finished) {
      return PlayResult.illegal('The game is already over.');
    }
    _pushUndo();
    lastMove = GameMove(kind: MoveKind.resign, player: toPlay);
    moves.add(lastMove!);
    _finish(toPlay.opponent, '${toPlay.label} resigns');
    return PlayResult.success();
  }

  void toggleDead(Point point) {
    if (phase != GamePhase.scoring) {
      return;
    }
    if (board.at(point) == Stone.empty) {
      return;
    }
    _pushUndo();
    final group = board.groupAt(point);
    final alreadyDead = group.every(deadStones.contains);
    if (alreadyDead) {
      deadStones.removeAll(group);
    } else {
      deadStones.addAll(group);
    }
  }

  void confirmScore() {
    if (phase != GamePhase.scoring) {
      return;
    }
    _pushUndo();
    final score = currentScore();
    _finish(score.winner, score.summary);
  }

  void undo() {
    if (_undo.isEmpty) {
      return;
    }
    final snap = _undo.removeLast();
    board = snap.board;
    toPlay = snap.toPlay;
    koPoint = snap.koPoint;
    blackCaptures = snap.blackCaptures;
    whiteCaptures = snap.whiteCaptures;
    consecutivePasses = snap.consecutivePasses;
    blackPassStones = snap.blackPassStones;
    whitePassStones = snap.whitePassStones;
    phase = snap.phase;
    deadStones = snap.deadStones;
    winner = snap.winner;
    resultText = snap.resultText;
    lastMove = snap.lastMove;
    if (moves.isNotEmpty) {
      moves.removeLast();
    }
    if (_positionHistory.length > 1) {
      _positionHistory.removeLast();
    }
  }

  bool isLegal(Point point) => _simulate(point, toPlay) != null;

  List<Point> legalMoves() {
    final result = <Point>[];
    for (final p in board.intersections) {
      if (board.at(p) == Stone.empty && isLegal(p)) {
        result.add(p);
      }
    }
    return result;
  }

  GoGame fork() {
    final copy = GoGame(rules);
    copy.board = board.clone();
    copy.toPlay = toPlay;
    copy.koPoint = koPoint;
    copy.blackCaptures = blackCaptures;
    copy.whiteCaptures = whiteCaptures;
    copy.consecutivePasses = consecutivePasses;
    copy.blackPassStones = blackPassStones;
    copy.whitePassStones = whitePassStones;
    copy.phase = phase;
    copy.deadStones = Set<Point>.of(deadStones);
    copy.winner = winner;
    copy.resultText = resultText;
    copy.lastMove = lastMove;
    copy.moves.addAll(moves);
    copy._positionHistory
      ..clear()
      ..addAll(_positionHistory);
    return copy;
  }

  _Sim? _simulate(Point point, Stone player) {
    if (!point.isOnBoard(size) || board.at(point) != Stone.empty) {
      return null;
    }
    if (koPoint == point && !rules.usesSuperko) {
      return null;
    }

    final next = board.clone();
    next.set(point, player);
    final captured = <Point>[];
    final seenGroups = <Point>{};

    for (final n in next.neighbors(point)) {
      if (next.at(n) != player.opponent || seenGroups.contains(n)) {
        continue;
      }
      final group = next.groupAt(n);
      seenGroups.addAll(group);
      if (next.libertiesOf(group).isEmpty) {
        captured.addAll(group);
      }
    }
    for (final p in captured) {
      next.set(p, Stone.empty);
    }

    final ownGroup = next.groupAt(point);
    final ownLibs = next.libertiesOf(ownGroup);
    if (ownLibs.isEmpty) {
      if (!rules.suicideAllowed) {
        return null;
      }
      for (final p in ownGroup) {
        next.set(p, Stone.empty);
      }
    }

    if (rules.usesSuperko) {
      final key = _situationalKey(next, player.opponent);
      if (_positionHistory.contains(key)) {
        return null;
      }
    }

    Point? newKo;
    if (!rules.usesSuperko &&
        captured.length == 1 &&
        ownGroup.length == 1 &&
        ownLibs.length == 1) {
      newKo = captured.first;
    }

    return _Sim(board: next, captured: captured, koPoint: newKo);
  }

  String _illegalReason(Point point, Stone player) {
    if (!point.isOnBoard(size)) {
      return 'Off the board.';
    }
    if (board.at(point) != Stone.empty) {
      return 'That intersection is occupied.';
    }
    if (koPoint == point && !rules.usesSuperko) {
      return 'Simple ko: that recapture is forbidden this turn.';
    }
    final next = board.clone();
    next.set(point, player);
    var captured = 0;
    for (final n in next.neighbors(point)) {
      if (next.at(n) == player.opponent && next.libertyCount(n) == 0) {
        captured += next.groupAt(n).length;
      }
    }
    if (captured == 0 && next.libertyCount(point) == 0 && !rules.suicideAllowed) {
      return 'Suicide is illegal under ${rules.ruleSet.title} rules.';
    }
    if (rules.usesSuperko) {
      return 'Superko: that move repeats an earlier position.';
    }
    return 'Illegal move.';
  }

  void _finish(Stone? who, String text) {
    phase = GamePhase.finished;
    winner = who;
    resultText = text;
  }

  void _pushUndo() {
    _undo.add(
      _Snapshot(
        board: board.clone(),
        toPlay: toPlay,
        koPoint: koPoint,
        blackCaptures: blackCaptures,
        whiteCaptures: whiteCaptures,
        consecutivePasses: consecutivePasses,
        blackPassStones: blackPassStones,
        whitePassStones: whitePassStones,
        phase: phase,
        deadStones: Set<Point>.of(deadStones),
        winner: winner,
        resultText: resultText,
        lastMove: lastMove,
      ),
    );
  }

  String _situationalKey(Board b, Stone side) => '${b.positionKey()}|${side.index}';
}

class _Sim {
  final Board board;
  final List<Point> captured;
  final Point? koPoint;

  _Sim({required this.board, required this.captured, required this.koPoint});
}

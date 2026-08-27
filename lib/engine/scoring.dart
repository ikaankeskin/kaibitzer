import 'board.dart';
import 'point.dart';
import 'stone.dart';

class ScoreResult {
  final double black;
  final double white;
  final int blackTerritory;
  final int whiteTerritory;
  final int blackStones;
  final int whiteStones;
  final String method;

  const ScoreResult({
    required this.black,
    required this.white,
    required this.blackTerritory,
    required this.whiteTerritory,
    required this.blackStones,
    required this.whiteStones,
    required this.method,
  });

  double get margin => black - white;

  Stone? get winner {
    if (margin > 0) {
      return Stone.black;
    }
    if (margin < 0) {
      return Stone.white;
    }
    return null;
  }

  String get summary {
    final lead = margin.abs();
    if (winner == null) {
      return 'Jigo (draw)';
    }
    return '${winner!.label} wins by $lead';
  }
}

class TerritoryMap {
  final Map<Point, Stone> owner;
  final Set<Point> dame;

  const TerritoryMap({required this.owner, required this.dame});
}

TerritoryMap mapTerritory(Board board, {Set<Point> dead = const {}}) {
  final working = board.clone();
  for (final p in dead) {
    if (p.isOnBoard(working.size)) {
      working.set(p, Stone.empty);
    }
  }

  final owner = <Point, Stone>{};
  final dame = <Point>{};
  final seen = <Point>{};

  for (final p in working.intersections) {
    if (working.at(p) != Stone.empty || seen.contains(p)) {
      continue;
    }
    final region = <Point>{};
    final stack = <Point>[p];
    final bordering = <Stone>{};
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      if (!region.add(cur)) {
        continue;
      }
      for (final n in working.neighbors(cur)) {
        final stone = working.at(n);
        if (stone == Stone.empty) {
          if (!region.contains(n)) {
            stack.add(n);
          }
        } else {
          bordering.add(stone);
        }
      }
    }
    seen.addAll(region);
    if (bordering.length == 1) {
      final color = bordering.first;
      for (final empty in region) {
        owner[empty] = color;
      }
    } else {
      dame.addAll(region);
    }
  }
  return TerritoryMap(owner: owner, dame: dame);
}

ScoreResult scoreBoard({
  required Board board,
  required bool areaScoring,
  required double komi,
  required int blackCaptures,
  required int whiteCaptures,
  Set<Point> dead = const {},
  int blackPassStones = 0,
  int whitePassStones = 0,
}) {
  final working = board.clone();
  var extraBlackCaptures = 0;
  var extraWhiteCaptures = 0;
  for (final p in dead) {
    if (!p.isOnBoard(working.size)) {
      continue;
    }
    final stone = working.at(p);
    if (stone == Stone.black) {
      extraWhiteCaptures++;
    } else if (stone == Stone.white) {
      extraBlackCaptures++;
    }
    working.set(p, Stone.empty);
  }

  final territory = mapTerritory(working);
  final blackTerritory =
      territory.owner.values.where((s) => s == Stone.black).length;
  final whiteTerritory =
      territory.owner.values.where((s) => s == Stone.white).length;
  final blackStones = working.stoneCount(Stone.black);
  final whiteStones = working.stoneCount(Stone.white);

  if (areaScoring) {
    final black = (blackStones + blackTerritory + whitePassStones).toDouble();
    final white =
        whiteStones + whiteTerritory + blackPassStones + komi;
    return ScoreResult(
      black: black,
      white: white,
      blackTerritory: blackTerritory,
      whiteTerritory: whiteTerritory,
      blackStones: blackStones,
      whiteStones: whiteStones,
      method: 'Area',
    );
  }

  final black = (blackTerritory + blackCaptures + extraBlackCaptures).toDouble();
  final white = whiteTerritory + whiteCaptures + extraWhiteCaptures + komi;
  return ScoreResult(
    black: black,
    white: white,
    blackTerritory: blackTerritory,
    whiteTerritory: whiteTerritory,
    blackStones: blackStones,
    whiteStones: whiteStones,
    method: 'Territory',
  );
}

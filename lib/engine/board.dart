import 'point.dart';
import 'stone.dart';

class Board {
  final int size;
  final List<Stone> _cells;

  Board.empty(this.size) : _cells = List<Stone>.filled(size * size, Stone.empty);

  Board._(this.size, this._cells);

  Board clone() => Board._(size, List<Stone>.of(_cells));

  int _index(Point p) => p.y * size + p.x;

  Stone at(Point p) => _cells[_index(p)];

  void set(Point p, Stone stone) => _cells[_index(p)] = stone;

  bool get isEmpty => _cells.every((stone) => stone == Stone.empty);

  int stoneCount(Stone stone) =>
      _cells.where((cell) => cell == stone).length;

  Iterable<Point> get intersections sync* {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        yield Point(x, y);
      }
    }
  }

  Iterable<Point> neighbors(Point p) sync* {
    const deltas = [Point(0, -1), Point(1, 0), Point(0, 1), Point(-1, 0)];
    for (final d in deltas) {
      final n = Point(p.x + d.x, p.y + d.y);
      if (n.isOnBoard(size)) {
        yield n;
      }
    }
  }

  Set<Point> groupAt(Point origin) {
    final color = at(origin);
    final group = <Point>{};
    if (color == Stone.empty) {
      return group;
    }
    final stack = <Point>[origin];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      if (!group.add(p)) {
        continue;
      }
      for (final n in neighbors(p)) {
        if (at(n) == color && !group.contains(n)) {
          stack.add(n);
        }
      }
    }
    return group;
  }

  Set<Point> libertiesOf(Set<Point> group) {
    final libs = <Point>{};
    for (final p in group) {
      for (final n in neighbors(p)) {
        if (at(n) == Stone.empty) {
          libs.add(n);
        }
      }
    }
    return libs;
  }

  int libertyCount(Point p) => libertiesOf(groupAt(p)).length;

  String positionKey() => _cells.map((s) => s.index).join();

  List<Point> hoshiPoints() {
    final h = size <= 9 ? 2 : 3;
    final mid = size ~/ 2;
    final points = <Point>{
      Point(h, h),
      Point(size - 1 - h, h),
      Point(h, size - 1 - h),
      Point(size - 1 - h, size - 1 - h),
    };
    if (size >= 13 && size.isOdd) {
      points.addAll([
        Point(mid, h),
        Point(mid, size - 1 - h),
        Point(h, mid),
        Point(size - 1 - h, mid),
        Point(mid, mid),
      ]);
    } else if (size.isOdd) {
      points.add(Point(mid, mid));
    }
    return points.where((p) => p.isOnBoard(size)).toList();
  }
}

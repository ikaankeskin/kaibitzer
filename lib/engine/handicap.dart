import 'point.dart';
import 'rules.dart';

/// Traditional Japanese handicap order, adapted to any odd board with star points.
List<Point> handicapPoints(GameRules rules) {
  final count = rules.handicap;
  if (count < 2) {
    return const [];
  }
  final size = rules.boardSize;
  final h = size <= 9 ? 2 : 3;
  final mid = size ~/ 2;
  final upperRight = Point(size - 1 - h, h);
  final lowerLeft = Point(h, size - 1 - h);
  final upperLeft = Point(h, h);
  final lowerRight = Point(size - 1 - h, size - 1 - h);
  final tengen = Point(mid, mid);
  final left = Point(h, mid);
  final right = Point(size - 1 - h, mid);
  final top = Point(mid, h);
  final bottom = Point(mid, size - 1 - h);

  final sequence = <Point>[
    upperRight,
    lowerLeft,
    upperLeft,
    lowerRight,
    tengen,
    left,
    right,
    top,
    bottom,
  ];

  // Six- and eight-stone handicaps omit tengen.
  if (count == 6) {
    return [upperRight, lowerLeft, upperLeft, lowerRight, left, right];
  }
  if (count == 8) {
    return [upperRight, lowerLeft, upperLeft, lowerRight, left, right, top, bottom];
  }
  return sequence.take(count.clamp(2, sequence.length)).toList();
}

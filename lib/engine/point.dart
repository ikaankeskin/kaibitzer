import 'package:flutter/foundation.dart';

/// Intersection on the goban. `(0, 0)` is the top-left (A at the highest rank).
@immutable
class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  bool isOnBoard(int size) => x >= 0 && y >= 0 && x < size && y < size;

  /// Standard Go coordinates: columns A–T skipping I, ranks counted from the bottom.
  String toCoordinate(int boardSize) {
    const letters = 'ABCDEFGHJKLMNOPQRSTUVWXYZ';
    if (x < 0 || x >= letters.length) {
      return '($x,$y)';
    }
    return '${letters[x]}${boardSize - y}';
  }

  static Point? parse(String text, int boardSize) {
    final raw = text.trim().toUpperCase().replaceAll('-', '').replaceAll(' ', '');
    final match = RegExp(r'^([A-HJ-Z])(\d{1,2})$').firstMatch(raw);
    if (match == null) {
      return null;
    }
    const letters = 'ABCDEFGHJKLMNOPQRSTUVWXYZ';
    final x = letters.indexOf(match.group(1)!);
    final rank = int.parse(match.group(2)!);
    final y = boardSize - rank;
    final point = Point(x, y);
    return point.isOnBoard(boardSize) ? point : null;
  }

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}

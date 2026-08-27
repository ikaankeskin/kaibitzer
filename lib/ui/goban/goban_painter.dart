import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../coach/kaibitzer_coach.dart';
import '../../engine/board.dart';
import '../../engine/point.dart';
import '../../engine/stone.dart';
import 'goban_style.dart';

class GobanPainter extends CustomPainter {
  final Board board;
  final GobanAppearance appearance;
  final Point? lastMove;
  final Point? hover;
  final Stone hoverColor;
  final List<MoveRecommendation> hints;
  final Set<Point> deadStones;
  final Map<Point, int> moveNumbers;
  final bool scoring;

  GobanPainter({
    required this.board,
    required this.appearance,
    required this.lastMove,
    required this.hover,
    required this.hoverColor,
    required this.hints,
    required this.deadStones,
    required this.moveNumbers,
    required this.scoring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final palette = GobanPalette.fromId(appearance.themeId);
    final layout = GobanLayout.fromSize(size, board.size, appearance.showCoordinates);

    _paintBoard(canvas, size, layout, palette);
    _paintGrid(canvas, layout, palette);
    if (appearance.showHoshi) {
      _paintHoshi(canvas, layout, palette);
    }
    if (appearance.showCoordinates) {
      _paintCoordinates(canvas, layout, palette);
    }
    _paintStones(canvas, layout, palette);
    if (scoring) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.05),
      );
    }
    _paintHints(canvas, layout, palette);
    if (hover != null && board.at(hover!) == Stone.empty) {
      _paintStone(canvas, layout.centerOf(hover!), layout.stoneRadius, hoverColor, palette,
          opacity: 0.45);
    }
  }

  void _paintBoard(Canvas canvas, Size size, GobanLayout layout, GobanPalette palette) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final fill = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [palette.boardFrom, palette.boardTo],
      );
    canvas.drawRRect(rrect, fill);

    final grain = Paint()
      ..color = palette.woodGrain
      ..strokeWidth = 1;
    for (var i = 0; i < 18; i++) {
      final x = size.width * (i + 1) / 20 + math.sin(i * 1.3) * 6;
      canvas.drawLine(Offset(x, 0), Offset(x + 8, size.height), grain);
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = palette.line.withValues(alpha: 0.45),
    );
  }

  void _paintGrid(Canvas canvas, GobanLayout layout, GobanPalette palette) {
    final paint = Paint()
      ..color = palette.line
      ..strokeWidth = appearance.lineWidth
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < board.size; i++) {
      canvas.drawLine(layout.centerOf(Point(0, i)), layout.centerOf(Point(board.size - 1, i)), paint);
      canvas.drawLine(layout.centerOf(Point(i, 0)), layout.centerOf(Point(i, board.size - 1)), paint);
    }
  }

  void _paintHoshi(Canvas canvas, GobanLayout layout, GobanPalette palette) {
    final paint = Paint()..color = palette.hoshi;
    final r = math.max(2.5, layout.cell * 0.08);
    for (final p in board.hoshiPoints()) {
      canvas.drawCircle(layout.centerOf(p), r, paint);
    }
  }

  void _paintCoordinates(Canvas canvas, GobanLayout layout, GobanPalette palette) {
    const letters = 'ABCDEFGHJKLMNOPQRSTUVWXYZ';
    final color = palette.coordinate;
    final fontSize = math.max(9.0, layout.margin * 0.38);
    for (var i = 0; i < board.size && i < letters.length; i++) {
      _drawLabel(
        canvas,
        letters[i],
        Offset(layout.centerOf(Point(i, 0)).dx, layout.margin * 0.42),
        color,
        fontSize,
      );
      _drawLabel(
        canvas,
        letters[i],
        Offset(layout.centerOf(Point(i, 0)).dx, layout.size.height - layout.margin * 0.42),
        color,
        fontSize,
      );
      final rank = '${board.size - i}';
      _drawLabel(
        canvas,
        rank,
        Offset(layout.margin * 0.42, layout.centerOf(Point(0, i)).dy),
        color,
        fontSize,
      );
      _drawLabel(
        canvas,
        rank,
        Offset(layout.size.width - layout.margin * 0.42, layout.centerOf(Point(0, i)).dy),
        color,
        fontSize,
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintStones(Canvas canvas, GobanLayout layout, GobanPalette palette) {
    for (final p in board.intersections) {
      final stone = board.at(p);
      if (!stone.isPlayer) {
        continue;
      }
      final dead = deadStones.contains(p);
      _paintStone(
        canvas,
        layout.centerOf(p),
        layout.stoneRadius,
        stone,
        palette,
        opacity: dead ? 0.38 : 1,
      );
      if (lastMove == p && !dead) {
        final mark = Paint()
          ..color = stone == Stone.black ? palette.lastMove : palette.lastMove
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.6, layout.cell * 0.06);
        canvas.drawCircle(layout.centerOf(p), layout.stoneRadius * 0.34, mark);
      }
      if (appearance.showMoveNumbers && moveNumbers[p] != null) {
        _drawLabel(
          canvas,
          '${moveNumbers[p]}',
          layout.centerOf(p),
          stone == Stone.black ? Colors.white : Colors.black87,
          math.max(8, layout.stoneRadius * 0.7),
        );
      }
    }
  }

  void _paintStone(
    Canvas canvas,
    Offset center,
    double radius,
    Stone stone,
    GobanPalette palette, {
    double opacity = 1,
  }) {
    final isBlack = stone == Stone.black;
    if (appearance.stoneFinish == StoneFinish.flat) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = (isBlack ? palette.blackStone : palette.whiteStone).withValues(alpha: opacity),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = (isBlack ? Colors.black : const Color(0xFF9A9A9A)).withValues(alpha: opacity),
      );
      return;
    }

    canvas.drawCircle(
      center.translate(radius * 0.12, radius * 0.16),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.22 * opacity),
    );

    final highlight = Offset(center.dx - radius * 0.28, center.dy - radius * 0.32);
    final base = isBlack ? palette.blackStone : palette.whiteStone;
    final shine = isBlack ? palette.blackHighlight : palette.whiteHighlight;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          highlight,
          radius * 1.35,
          [
            shine.withValues(alpha: opacity),
            base.withValues(alpha: opacity),
          ],
          const [0.0, 1.0],
        ),
    );

    if (appearance.stoneFinish == StoneFinish.shell && !isBlack) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x55A0A0A0).withValues(alpha: 0.4 * opacity);
      canvas.drawCircle(center, radius * 0.55, ring);
      canvas.drawCircle(center, radius * 0.28, ring);
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.black.withValues(alpha: 0.25 * opacity),
    );
  }

  void _paintHints(Canvas canvas, GobanLayout layout, GobanPalette palette) {
    for (var i = 0; i < hints.length; i++) {
      final rec = hints[i];
      if (board.at(rec.point).isPlayer) {
        continue;
      }
      final c = layout.centerOf(rec.point);
      canvas.drawCircle(
        c,
        layout.stoneRadius * 0.72,
        Paint()..color = palette.hint.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        c,
        layout.stoneRadius * 0.72,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = palette.hint,
      );
      _drawLabel(
        canvas,
        '${i + 1}',
        c,
        palette.hint,
        math.max(11, layout.stoneRadius * 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant GobanPainter oldDelegate) => true;
}

class GobanLayout {
  final Size size;
  final int boardSize;
  final double margin;
  final double cell;

  GobanLayout({
    required this.size,
    required this.boardSize,
    required this.margin,
    required this.cell,
  });

  factory GobanLayout.fromSize(Size size, int boardSize, bool coordinates) {
    final side = math.min(size.width, size.height);
    final margin = coordinates ? side * 0.08 : side * 0.045;
    final usable = side - margin * 2;
    final cell = boardSize == 1 ? usable : usable / (boardSize - 1);
    return GobanLayout(size: size, boardSize: boardSize, margin: margin, cell: cell);
  }

  double get stoneRadius => cell * 0.46;

  Offset centerOf(Point p) => Offset(margin + p.x * cell, margin + p.y * cell);

  Point? pointAt(Offset local) {
    final x = ((local.dx - margin) / cell).round();
    final y = ((local.dy - margin) / cell).round();
    final p = Point(x, y);
    if (!p.isOnBoard(boardSize)) {
      return null;
    }
    final c = centerOf(p);
    if ((c - local).distance > cell * 0.48) {
      return null;
    }
    return p;
  }
}

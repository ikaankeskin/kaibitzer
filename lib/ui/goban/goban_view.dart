import 'package:flutter/material.dart';

import '../../coach/kaibitzer_coach.dart';
import '../../engine/board.dart';
import '../../engine/game.dart';
import '../../engine/point.dart';
import '../../engine/stone.dart';
import 'goban_painter.dart';
import 'goban_style.dart';

class GobanView extends StatefulWidget {
  final Board board;
  final GobanAppearance appearance;
  final Point? lastMove;
  final Point? hover;
  final Stone toPlay;
  final List<MoveRecommendation> hints;
  final Set<Point> deadStones;
  final GamePhase phase;
  final Map<Point, int> moveNumbers;
  final ValueChanged<Point> onTap;
  final ValueChanged<Point?> onHover;

  const GobanView({
    super.key,
    required this.board,
    required this.appearance,
    required this.lastMove,
    required this.hover,
    required this.toPlay,
    required this.hints,
    required this.deadStones,
    required this.phase,
    required this.moveNumbers,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<GobanView> createState() => _GobanViewState();
}

class _GobanViewState extends State<GobanView> {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final layout = GobanLayout.fromSize(
            size,
            widget.board.size,
            widget.appearance.showCoordinates,
          );
          return MouseRegion(
            onHover: (event) {
              widget.onHover(layout.pointAt(event.localPosition));
            },
            onExit: (_) => widget.onHover(null),
            child: GestureDetector(
              onTapDown: (details) {
                final point = layout.pointAt(details.localPosition);
                if (point != null) {
                  widget.onTap(point);
                }
              },
              child: CustomPaint(
                painter: GobanPainter(
                  board: widget.board,
                  appearance: widget.appearance,
                  lastMove: widget.lastMove,
                  hover: widget.hover,
                  hoverColor: widget.toPlay,
                  hints: widget.hints,
                  deadStones: widget.deadStones,
                  moveNumbers: widget.moveNumbers,
                  scoring: widget.phase == GamePhase.scoring,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
  final Stone toPlay;
  final List<MoveRecommendation> hints;
  final Set<Point> deadStones;
  final GamePhase phase;
  final Map<Point, int> moveNumbers;
  final ValueChanged<Point> onTap;

  const GobanView({
    super.key,
    required this.board,
    required this.appearance,
    required this.lastMove,
    required this.toPlay,
    required this.hints,
    required this.deadStones,
    required this.phase,
    required this.moveNumbers,
    required this.onTap,
  });

  @override
  State<GobanView> createState() => _GobanViewState();
}

class _GobanViewState extends State<GobanView> {
  Point? _hover;
  GobanLayout? _layout;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _layout = GobanLayout.fromSize(
            size,
            widget.board.size,
            widget.appearance.showCoordinates,
          );
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onHover: (event) => _updateHover(event.localPosition),
            onExit: (_) {
              if (_hover != null) {
                setState(() => _hover = null);
              }
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                final point = _layout?.pointAt(event.localPosition);
                if (point != null) {
                  widget.onTap(point);
                }
              },
              child: CustomPaint(
                painter: GobanPainter(
                  board: widget.board,
                  appearance: widget.appearance,
                  lastMove: widget.lastMove,
                  hover: _hover,
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

  void _updateHover(Offset local) {
    final point = _layout?.pointAt(local);
    if (point == _hover) {
      return;
    }
    setState(() => _hover = point);
  }
}

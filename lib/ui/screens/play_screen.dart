import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../ai/engine_kind.dart';
import '../../coach/computer_player.dart';
import '../../engine/game.dart';
import '../../engine/point.dart';
import '../../state/game_session.dart';
import '../app_theme.dart';
import '../goban/goban_style.dart';
import '../goban/goban_view.dart';
import 'coach_panel.dart';
import 'debug_console.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameSession>(
      builder: (context, session, _) {
        final game = session.game;
        final wide = MediaQuery.sizeOf(context).width >= 920;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyH): session.recommendMoves,
            const SingleActivator(LogicalKeyboardKey.slash): session.recommendMoves,
            const SingleActivator(LogicalKeyboardKey.digit1): () => session.playHint(0),
            const SingleActivator(LogicalKeyboardKey.digit2): () => session.playHint(1),
            const SingleActivator(LogicalKeyboardKey.digit3): () => session.playHint(2),
            const SingleActivator(LogicalKeyboardKey.numpad1): () => session.playHint(0),
            const SingleActivator(LogicalKeyboardKey.numpad2): () => session.playHint(1),
            const SingleActivator(LogicalKeyboardKey.numpad3): () => session.playHint(2),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
          appBar: AppBar(
            title: Text(game.rules.description),
            actions: [
              IconButton(
                tooltip: session.showDebugConsole
                    ? 'Hide engine console'
                    : 'Show engine console',
                onPressed: session.toggleDebugConsole,
                icon: Icon(
                  session.showDebugConsole
                      ? Icons.terminal
                      : Icons.terminal_outlined,
                ),
              ),
              PopupMenuButton<EngineKind>(
                tooltip: 'Engine',
                initialValue: session.engineKind,
                onSelected: session.setEngine,
                itemBuilder: (context) => [
                  for (final kind in EngineKind.values)
                    PopupMenuItem(
                      value: kind,
                      child: Text('${kind.title}${session.engineKind == kind ? '  ✓' : ''}'),
                    ),
                ],
                icon: const Icon(Icons.smart_toy_outlined),
              ),
              if (session.vsComputer)
                PopupMenuButton<AiLevel>(
                  tooltip: 'Difficulty',
                  initialValue: session.aiLevel,
                  onSelected: session.setAiLevel,
                  itemBuilder: (context) => [
                    for (final level in AiLevel.values)
                      PopupMenuItem(
                        value: level,
                        child: Text('${level.title}${session.aiLevel == level ? '  ✓' : ''}'),
                      ),
                  ],
                  icon: const Icon(Icons.speed),
                ),
              IconButton(
                tooltip: session.appearance.showMoveNumbers
                    ? 'Hide move numbers'
                    : 'Show move numbers',
                onPressed: () {
                  session.updateAppearance(
                    session.appearance.copyWith(
                      showMoveNumbers: !session.appearance.showMoveNumbers,
                    ),
                  );
                },
                icon: const Icon(Icons.format_list_numbered),
              ),
              PopupMenuButton<GobanThemeId>(
                tooltip: 'Board theme',
                onSelected: (id) {
                  session.updateAppearance(session.appearance.copyWith(themeId: id));
                },
                itemBuilder: (context) => [
                  for (final id in GobanThemeId.values)
                    PopupMenuItem(value: id, child: Text(id.title)),
                ],
                icon: const Icon(Icons.palette_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              _StatusBar(session: session),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(flex: 5, child: _BoardPane(session: session)),
                          const VerticalDivider(width: 1),
                          const Expanded(flex: 3, child: CoachPanel()),
                        ],
                      )
                    : _BoardPane(session: session),
              ),
              _ActionBar(session: session, showCoachButton: !wide),
              if (session.showDebugConsole)
                DebugConsole(
                  logs: session.debugLogs,
                  onClear: session.clearDebugLogs,
                  onHide: session.toggleDebugConsole,
                ),
            ],
          ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPane extends StatelessWidget {
  final GameSession session;
  const _BoardPane({required this.session});

  @override
  Widget build(BuildContext context) {
    final game = session.game;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: IgnorePointer(
            ignoring: session.inputLocked && game.phase != GamePhase.scoring,
            child: GobanView(
            board: game.board,
            appearance: session.appearance,
            lastMove: game.lastMove?.point,
            toPlay: game.toPlay,
            hints: session.showHints ? session.hints : const [],
            deadStones: game.deadStones,
            phase: game.phase,
            moveNumbers: _moveNumbers(game),
            onTap: session.tapPoint,
            ),
          ),
        ),
      ),
    );
  }

  Map<Point, int> _moveNumbers(GoGame game) {
    final map = <Point, int>{};
    var n = 0;
    for (final move in game.moves) {
      if (move.kind == MoveKind.place && move.point != null) {
        n++;
        map[move.point!] = n;
      }
    }
    return map;
  }
}

class _StatusBar extends StatelessWidget {
  final GameSession session;
  const _StatusBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final game = session.game;
    String status;
    switch (game.phase) {
      case GamePhase.playing:
        if (session.thinking) {
          status = '${game.toPlay.label} (computer) thinking…';
        } else if (session.vsComputer) {
          status = session.isHumanTurn
              ? '${game.toPlay.label} to play · you'
              : '${game.toPlay.label} to play · computer';
        } else {
          status = '${game.toPlay.label} to play';
        }
        break;
      case GamePhase.scoring:
        status = 'Scoring — tap dead groups';
        break;
      case GamePhase.finished:
        status = game.resultText ?? 'Game over';
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.lacquer,
      child: Row(
        children: [
          Expanded(
            child: Text(
              status,
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            session.vsComputer
                ? '${session.aiLevel.title} · ${session.engineName}'
                : session.engineName,
            style: TextStyle(color: AppColors.paper.withValues(alpha: 0.75)),
          ),
          const SizedBox(width: 12),
          Text(
            'Captures B ${game.blackCaptures}  W ${game.whiteCaptures}',
            style: TextStyle(color: AppColors.paper.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final GameSession session;
  final bool showCoachButton;

  const _ActionBar({required this.session, required this.showCoachButton});

  @override
  Widget build(BuildContext context) {
    final game = session.game;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          children: [
            _Tool(
              icon: Icons.undo,
              label: 'Undo',
              onPressed: game.canUndo ? session.undo : null,
            ),
            _Tool(
              icon: Icons.pan_tool_outlined,
              label: 'Pass',
              onPressed:
                  game.phase == GamePhase.playing && !session.inputLocked
                      ? session.pass
                      : null,
            ),
            _Tool(
              icon: Icons.flag_outlined,
              label: 'Resign',
              onPressed: game.phase != GamePhase.finished ? session.resign : null,
            ),
            if (game.phase == GamePhase.scoring)
              _Tool(
                icon: Icons.check,
                label: 'Score',
                onPressed: session.confirmScore,
              ),
            const Spacer(),
            if (showCoachButton)
              FilledButton.icon(
                onPressed: () => _openCoach(context),
                icon: const Icon(Icons.psychology_alt),
                label: const Text('Coach'),
              )
            else
              FilledButton.icon(
                onPressed: session.recommendMoves,
                icon: const Icon(Icons.tips_and_updates_outlined),
                label: const Text('Hint'),
              ),
          ],
        ),
      ),
    );
  }

  void _openCoach(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.lacquer,
      showDragHandle: true,
      builder: (context) {
        return ChangeNotifierProvider.value(
          value: session,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: const CoachPanel(),
          ),
        );
      },
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _Tool({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/game_session.dart';
import '../app_theme.dart';

class CoachPanel extends StatefulWidget {
  const CoachPanel({super.key});

  @override
  State<CoachPanel> createState() => _CoachPanelState();
}

class _CoachPanelState extends State<CoachPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<GameSession>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Kaibitzer',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Recommend a move'),
                onPressed: session.recommendMoves,
              ),
              ActionChip(
                label: const Text("Who's ahead?"),
                onPressed: () => session.ask("Who's ahead?"),
              ),
              ActionChip(
                label: const Text('Weak groups'),
                onPressed: () => session.ask('Show weak groups and atari'),
              ),
              ActionChip(
                label: const Text('Explain the rules'),
                onPressed: () => session.ask('Explain the rules of this game'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: session.messages.length,
            itemBuilder: (context, index) {
              final message = session.messages[index];
              final mine = !message.fromCoach;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: mine ? const Color(0xFF3A2A20) : const Color(0xFF241E19),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: mine
                          ? AppColors.vermillion.withValues(alpha: 0.4)
                          : AppColors.gold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(color: AppColors.paper, height: 1.4),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: const InputDecoration(
                    hintText: 'Ask for a move, or a coordinate like Q16…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _send(_controller.text),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    context.read<GameSession>().ask(trimmed);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

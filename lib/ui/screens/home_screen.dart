import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_version.dart';
import '../../engine/rules.dart';
import '../../state/game_session.dart';
import '../../state/match_config.dart';
import '../app_theme.dart';
import '../goban/goban_style.dart';
import 'play_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          children: [
              Text(
                'KAIBITZER',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '$appVersionLabel · web preview',
                key: const Key('app-version'),
                style: TextStyle(
                  color: AppColors.paper.withValues(alpha: 0.45),
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play Go. Ask the sideline tutor. Works in the browser without extra software.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.paper.withValues(alpha: 0.82),
                    ),
              ),
              const SizedBox(height: 28),
              Text(
                'A kaibitzer is the spectator who cannot help offering advice. '
                'This one is invited: a customizable goban, several rule variants, '
                'and a coach that suggests moves with reasons.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.paper.withValues(alpha: 0.78),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 36),
              _QuickStartCard(
                title: '9×9 vs computer',
                subtitle: 'Japanese rules · you play Black',
                onTap: () => _start(
                  context,
                  GameRules.preset(boardSize: 9, ruleSet: RuleSet.japanese),
                  match: const MatchConfig.computer(),
                ),
              ),
              const SizedBox(height: 12),
              _QuickStartCard(
                title: '19×19 vs computer',
                subtitle: 'Japanese rules · komi 6.5',
                onTap: () => _start(
                  context,
                  GameRules.preset(boardSize: 19, ruleSet: RuleSet.japanese),
                  match: const MatchConfig.computer(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    );
                  },
                  child: const Text('Customize board & rules'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _showHelp(context),
                  child: const Text('How Go works in Kaibitzer'),
                ),
              ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  void _start(
    BuildContext context,
    GameRules rules, {
    MatchConfig match = const MatchConfig.computer(),
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => GameSession.start(
            rules: rules,
            appearance: const GobanAppearance(),
            match: match,
          ),
          child: const PlayScreen(),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.lacquer,
      builder: (context) {
        return const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The shape of the game',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Players alternate placing black and white stones on intersections. '
                'Surround a group and take its last liberty to capture it.\n\n'
                'Japanese rules score empty territory plus captives. Chinese and AGA '
                'count stones on the board as well. New Zealand allows suicide. '
                'Capture Go ends when someone takes the agreed number of stones.\n\n'
                'After two passes, tap dead groups, then confirm the score. '
                'The Kaibitzer can recommend a move at any time.',
                style: TextStyle(color: AppColors.paper, height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickStartCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
      color: const Color(0xFF241E19),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.4),
                ),
                child: const Icon(Icons.grid_4x4, color: AppColors.gold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.paper,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.paper.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.paper.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

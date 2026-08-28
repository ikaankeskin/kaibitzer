import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/engine_kind.dart';
import '../../engine/rules.dart';
import '../../engine/stone.dart';
import '../../state/game_session.dart';
import '../../state/match_config.dart';
import '../../coach/computer_player.dart';
import '../app_theme.dart';
import '../goban/goban_style.dart';
import 'play_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int boardSize = 13;
  RuleSet ruleSet = RuleSet.japanese;
  WinCondition winCondition = WinCondition.standard;
  int handicap = 0;
  int captureGoal = 1;
  late double komi;
  GobanAppearance appearance = const GobanAppearance();
  OpponentKind opponent = OpponentKind.computer;
  AiLevel aiLevel = AiLevel.medium;
  Stone humanColor = Stone.black;
  EngineKind engine = EngineKind.heuristic;

  @override
  void initState() {
    super.initState();
    komi = ruleSet.defaultKomi;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New game')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const _SectionTitle('Board size'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in const [9, 13, 19])
                ChoiceChip(
                  label: Text('$size×$size'),
                  selected: boardSize == size,
                  onSelected: (_) => setState(() => boardSize = size),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Custom size: $boardSize', style: const TextStyle(color: AppColors.paper)),
          Slider(
            min: 5,
            max: 21,
            divisions: 16,
            value: boardSize.toDouble(),
            label: '$boardSize',
            onChanged: (value) => setState(() => boardSize = value.round()),
          ),
          const _SectionTitle('Opponent'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Computer'),
                selected: opponent == OpponentKind.computer,
                onSelected: (_) => setState(() => opponent = OpponentKind.computer),
              ),
              ChoiceChip(
                label: const Text('Pass and play'),
                selected: opponent == OpponentKind.local,
                onSelected: (_) => setState(() => opponent = OpponentKind.local),
              ),
            ],
          ),
          if (opponent == OpponentKind.computer) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final level in AiLevel.values)
                  ChoiceChip(
                    label: Text(level.title),
                    selected: aiLevel == level,
                    onSelected: (_) => setState(() => aiLevel = level),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Play Black'),
                  selected: humanColor == Stone.black,
                  onSelected: (_) => setState(() => humanColor = Stone.black),
                ),
                ChoiceChip(
                  label: const Text('Play White'),
                  selected: humanColor == Stone.white,
                  onSelected: (_) => setState(() => humanColor = Stone.white),
                ),
              ],
            ),
          ],
          const _SectionTitle('Engine'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in EngineKind.values)
                ChoiceChip(
                  label: Text(kind.title),
                  selected: engine == kind,
                  onSelected: (_) => setState(() => engine = kind),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              engine.summary,
              style: TextStyle(color: AppColors.paper.withValues(alpha: 0.65), height: 1.4),
            ),
          ),
          const _SectionTitle('Rules'),
          for (final set in RuleSet.values)
            ListTile(
              selected: ruleSet == set,
              leading: Icon(
                ruleSet == set ? Icons.radio_button_checked : Icons.radio_button_off,
                color: AppColors.gold,
              ),
              title: Text(set.title),
              subtitle: Text(set.summary),
              onTap: () {
                setState(() {
                  ruleSet = set;
                  if (handicap < 2) {
                    komi = set.defaultKomi;
                  }
                });
              },
            ),
          const _SectionTitle('Win condition'),
          SegmentedButton<WinCondition>(
            segments: [
              for (final w in WinCondition.values)
                ButtonSegment(value: w, label: Text(w.title)),
            ],
            selected: {winCondition},
            onSelectionChanged: (value) {
              setState(() => winCondition = value.first);
            },
          ),
          const SizedBox(height: 8),
          Text(winCondition.summary, style: TextStyle(color: AppColors.paper.withValues(alpha: 0.7))),
          if (winCondition == WinCondition.captureGo) ...[
            const SizedBox(height: 8),
            Text('Capture goal: $captureGoal'),
            Slider(
              min: 1,
              max: 10,
              divisions: 9,
              value: captureGoal.toDouble(),
              onChanged: (value) => setState(() => captureGoal = value.round()),
            ),
          ],
          const _SectionTitle('Handicap & komi'),
          Text('Handicap stones: $handicap'),
          Slider(
            min: 0,
            max: 9,
            divisions: 9,
            value: handicap.toDouble(),
            onChanged: (value) {
              setState(() {
                handicap = value.round();
                komi = handicap >= 2 ? 0.5 : ruleSet.defaultKomi;
              });
            },
          ),
          Text('Komi: ${komi.toStringAsFixed(1)}'),
          Slider(
            min: 0,
            max: 9,
            divisions: 18,
            value: komi,
            onChanged: (value) => setState(() => komi = value),
          ),
          const _SectionTitle('Goban look'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in GobanThemeId.values)
                ChoiceChip(
                  label: Text(theme.title),
                  selected: appearance.themeId == theme,
                  onSelected: (_) {
                    setState(() => appearance = appearance.copyWith(themeId: theme));
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final finish in StoneFinish.values)
                ChoiceChip(
                  label: Text(finish.title),
                  selected: appearance.stoneFinish == finish,
                  onSelected: (_) {
                    setState(() => appearance = appearance.copyWith(stoneFinish: finish));
                  },
                ),
            ],
          ),
          SwitchListTile(
            title: const Text('Coordinates'),
            value: appearance.showCoordinates,
            onChanged: (value) {
              setState(() => appearance = appearance.copyWith(showCoordinates: value));
            },
          ),
          SwitchListTile(
            title: const Text('Star points'),
            value: appearance.showHoshi,
            onChanged: (value) {
              setState(() => appearance = appearance.copyWith(showHoshi: value));
            },
          ),
          SwitchListTile(
            title: const Text('Move numbers'),
            value: appearance.showMoveNumbers,
            onChanged: (value) {
              setState(() => appearance = appearance.copyWith(showMoveNumbers: value));
            },
          ),
          Text('Line width: ${appearance.lineWidth.toStringAsFixed(1)}'),
          Slider(
            min: 0.6,
            max: 3,
            divisions: 12,
            value: appearance.lineWidth,
            onChanged: (value) {
              setState(() => appearance = appearance.copyWith(lineWidth: value));
            },
          ),
        ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _start,
            child: const Text('Start game'),
          ),
        ),
      ),
    );
  }

  void _start() {
    final rules = GameRules.preset(
      ruleSet: ruleSet,
      winCondition: winCondition,
      boardSize: boardSize,
      handicap: handicap,
      komi: komi,
      captureGoal: captureGoal,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => GameSession.start(
            rules: rules,
            appearance: appearance,
            match: MatchConfig(
              opponent: opponent,
              aiLevel: aiLevel,
              humanColor: humanColor,
              engine: engine,
            ),
          ),
          child: const PlayScreen(),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

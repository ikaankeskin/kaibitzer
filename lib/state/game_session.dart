import 'package:flutter/material.dart';

import '../coach/computer_player.dart';
import '../coach/kaibitzer_coach.dart';
import '../engine/game.dart';
import '../engine/point.dart';
import '../engine/rules.dart';
import '../engine/stone.dart';
import '../ui/goban/goban_style.dart';
import 'match_config.dart';

class GameSession extends ChangeNotifier {
  GoGame game;
  GobanAppearance appearance;
  final MatchConfig match;
  final KaibitzerCoach coach;
  final ComputerPlayer computer;
  final List<CoachMessage> messages;
  List<MoveRecommendation> hints;
  bool showHints;
  bool thinking;
  int _aiGeneration;

  GameSession({
    required this.game,
    required this.appearance,
    this.match = const MatchConfig.local(),
    KaibitzerCoach? coach,
  })  : coach = coach ?? KaibitzerCoach(),
        computer = ComputerPlayer(coach: coach),
        messages = [
          CoachMessage(
            fromCoach: true,
            text: match.vsComputer
                ? 'I will play ${match.computerColor.label} at ${match.aiLevel.title} strength. '
                    'Ask if you want a hint on your turn.'
                : 'I am the Kaibitzer — a sideline tutor. Ask for a recommended move, '
                    'or tap the hint button and I will mark candidates on the board.',
          ),
        ],
        hints = const [],
        showHints = false,
        thinking = false,
        _aiGeneration = 0 {
    Future.microtask(scheduleAiMove);
  }

  @override
  void dispose() {
    _aiGeneration++;
    super.dispose();
  }

  factory GameSession.start({
    required GameRules rules,
    GobanAppearance appearance = const GobanAppearance(),
    MatchConfig match = const MatchConfig.local(),
  }) {
    return GameSession(
      game: GoGame(rules),
      appearance: appearance,
      match: match,
    );
  }

  Stone get toPlay => game.toPlay;

  bool get vsComputer => match.vsComputer;

  bool get isHumanTurn =>
      !vsComputer || game.toPlay == match.humanColor;

  bool get inputLocked =>
      thinking ||
      game.phase != GamePhase.playing ||
      (vsComputer && !isHumanTurn);

  void tapPoint(Point point) {
    if (game.phase == GamePhase.scoring) {
      game.toggleDead(point);
      notifyListeners();
      return;
    }
    if (inputLocked) {
      return;
    }
    final result = game.play(point);
    if (!result.ok) {
      messages.add(CoachMessage(fromCoach: true, text: result.reason ?? 'Illegal move.'));
      notifyListeners();
      return;
    }
    hints = const [];
    showHints = false;
    notifyListeners();
    scheduleAiMove();
  }

  void pass() {
    if (inputLocked) {
      return;
    }
    final result = game.pass();
    if (!result.ok && result.reason != null) {
      messages.add(CoachMessage(fromCoach: true, text: result.reason!));
    } else if (game.phase == GamePhase.scoring) {
      messages.add(
        const CoachMessage(
          fromCoach: true,
          text:
              'Both players passed. Tap groups that are dead, then confirm the score. '
              'I can still estimate the living-stone score if you ask.',
        ),
      );
    }
    hints = const [];
    showHints = false;
    notifyListeners();
    scheduleAiMove();
  }

  void resign() {
    _aiGeneration++;
    thinking = false;
    if (vsComputer) {
      game.toPlay = match.humanColor;
    }
    game.resign();
    hints = const [];
    notifyListeners();
  }

  void undo() {
    if (!game.canUndo) {
      return;
    }
    _aiGeneration++;
    thinking = false;
    game.undo();
    if (vsComputer && game.toPlay == match.computerColor && game.canUndo) {
      game.undo();
    }
    hints = const [];
    showHints = false;
    notifyListeners();
  }

  void confirmScore() {
    game.confirmScore();
    notifyListeners();
  }

  void updateAppearance(GobanAppearance next) {
    appearance = next;
    notifyListeners();
  }

  void ask(String question) {
    messages.add(CoachMessage(fromCoach: false, text: question));
    final reply = coach.answer(game, question);
    messages.add(reply);
    if (reply.recommendations.isNotEmpty) {
      hints = reply.recommendations;
      showHints = true;
    }
    notifyListeners();
  }

  void recommendMoves() {
    ask('Recommend a move');
  }

  void clearHints() {
    showHints = false;
    hints = const [];
    notifyListeners();
  }

  void scheduleAiMove() {
    if (!vsComputer ||
        game.phase != GamePhase.playing ||
        game.toPlay != match.computerColor) {
      return;
    }
    final token = ++_aiGeneration;
    thinking = true;
    notifyListeners();
    Future<void>.delayed(Duration(milliseconds: 280 + match.aiLevel.index * 140), () {
      if (token != _aiGeneration) {
        return;
      }
      final point = computer.choose(game, match.aiLevel);
      if (point == null) {
        game.pass();
      } else {
        final result = game.play(point);
        if (!result.ok) {
          game.pass();
        }
      }
      thinking = false;
      notifyListeners();
    });
  }
}

import 'package:flutter/material.dart';

import '../coach/kaibitzer_coach.dart';
import '../engine/game.dart';
import '../engine/point.dart';
import '../engine/rules.dart';
import '../engine/stone.dart';
import '../ui/goban/goban_style.dart';

class GameSession extends ChangeNotifier {
  GoGame game;
  GobanAppearance appearance;
  final KaibitzerCoach coach;
  final List<CoachMessage> messages;
  List<MoveRecommendation> hints;
  bool showHints;
  Point? hover;

  GameSession({
    required this.game,
    required this.appearance,
    KaibitzerCoach? coach,
  })  : coach = coach ?? KaibitzerCoach(),
        messages = [
          CoachMessage(
            fromCoach: true,
            text:
                'I am the Kaibitzer — a sideline tutor. Ask for a recommended move, '
                'or tap the hint button and I will mark candidates on the board.',
          ),
        ],
        hints = const [],
        showHints = false;

  factory GameSession.start({
    required GameRules rules,
    GobanAppearance appearance = const GobanAppearance(),
  }) {
    return GameSession(game: GoGame(rules), appearance: appearance);
  }

  Stone get toPlay => game.toPlay;

  void tapPoint(Point point) {
    if (game.phase == GamePhase.scoring) {
      game.toggleDead(point);
      notifyListeners();
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
    hover = null;
    notifyListeners();
  }

  void pass() {
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
  }

  void resign() {
    game.resign();
    hints = const [];
    notifyListeners();
  }

  void undo() {
    game.undo();
    hints = const [];
    showHints = false;
    notifyListeners();
  }

  void confirmScore() {
    game.confirmScore();
    notifyListeners();
  }

  void setHover(Point? point) {
    if (hover == point) {
      return;
    }
    hover = point;
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
}

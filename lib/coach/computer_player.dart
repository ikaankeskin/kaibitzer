import 'dart:math';

import '../engine/game.dart';
import '../engine/point.dart';
import 'kaibitzer_coach.dart';

enum AiLevel { easy, medium, hard }

extension AiLevelLabels on AiLevel {
  String get title => switch (this) {
        AiLevel.easy => 'Easy',
        AiLevel.medium => 'Medium',
        AiLevel.hard => 'Hard',
      };
}

class ComputerPlayer {
  final KaibitzerCoach coach;
  final Random _random;

  ComputerPlayer({KaibitzerCoach? coach, Random? random})
      : coach = coach ?? KaibitzerCoach(),
        _random = random ?? Random();

  /// Returns a legal point, or `null` to pass.
  Point? choose(GoGame game, AiLevel level) {
    if (game.phase != GamePhase.playing) {
      return null;
    }
    final take = switch (level) {
      AiLevel.easy => 7,
      AiLevel.medium => 3,
      AiLevel.hard => 1,
    };
    final ranked = coach.recommend(game, max: take);
    if (ranked.isEmpty) {
      return null;
    }
    if (level == AiLevel.hard || ranked.length == 1) {
      return ranked.first.point;
    }
    if (level == AiLevel.easy && _random.nextDouble() < 0.2) {
      return ranked[_random.nextInt(ranked.length)].point;
    }
    var total = 0.0;
    final weights = <double>[];
    for (var i = 0; i < ranked.length; i++) {
      final weight = ranked.length - i.toDouble();
      weights.add(weight);
      total += weight;
    }
    var pick = _random.nextDouble() * total;
    for (var i = 0; i < ranked.length; i++) {
      pick -= weights[i];
      if (pick <= 0) {
        return ranked[i].point;
      }
    }
    return ranked.first.point;
  }
}

import '../coach/computer_player.dart';
import '../coach/kaibitzer_coach.dart';
import '../engine/game.dart';
import '../engine/point.dart';
import '../engine/rules.dart';
import '../engine/stone.dart';

export '../coach/computer_player.dart' show AiLevel, AiLevelLabels;

abstract class MoveEngine {
  String get name;
  bool get isNeuralNet;

  Future<Point?> genMove(GoGame game, AiLevel level);

  Future<List<MoveRecommendation>> analyze(GoGame game, {int max = 3});

  Future<void> dispose() async {}
}

class HeuristicEngine implements MoveEngine {
  HeuristicEngine({KaibitzerCoach? coach, ComputerPlayer? computer})
      : coach = coach ?? KaibitzerCoach(),
        computer = computer ?? ComputerPlayer(coach: coach);

  final KaibitzerCoach coach;
  final ComputerPlayer computer;

  @override
  String get name => 'Built-in tutor';

  @override
  bool get isNeuralNet => false;

  @override
  Future<Point?> genMove(GoGame game, AiLevel level) async {
    return computer.choose(game, level);
  }

  @override
  Future<List<MoveRecommendation>> analyze(GoGame game, {int max = 3}) async {
    return coach.recommend(game, max: max);
  }

  @override
  Future<void> dispose() async {}
}

String gtpColor(Stone stone) => switch (stone) {
      Stone.black => 'B',
      Stone.white => 'W',
      Stone.empty => '',
    };

String kataRulesName(RuleSet ruleSet) => switch (ruleSet) {
      RuleSet.japanese => 'japanese',
      RuleSet.chinese => 'chinese',
      RuleSet.aga => 'aga',
      RuleSet.newZealand => 'newzealand',
    };

double searchSeconds(AiLevel level) => switch (level) {
      AiLevel.easy => 0.25,
      AiLevel.medium => 1.0,
      AiLevel.hard => 3.0,
    };

int analyzeVisits(AiLevel level) => switch (level) {
      AiLevel.easy => 24,
      AiLevel.medium => 80,
      AiLevel.hard => 200,
    };

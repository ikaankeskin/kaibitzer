enum RuleSet {
  japanese,
  chinese,
  aga,
  newZealand;

  String get title => switch (this) {
        RuleSet.japanese => 'Japanese',
        RuleSet.chinese => 'Chinese',
        RuleSet.aga => 'AGA',
        RuleSet.newZealand => 'New Zealand',
      };

  String get summary => switch (this) {
        RuleSet.japanese =>
          'Territory scoring, simple ko, suicide forbidden. The East Asian tournament standard.',
        RuleSet.chinese =>
          'Area scoring, positional superko, suicide forbidden. Stones on the board count.',
        RuleSet.aga =>
          'American Go Association: area scoring with pass stones and superko.',
        RuleSet.newZealand =>
          'Area scoring, superko, and suicide allowed — useful for teaching rare shapes.',
      };

  double get defaultKomi => switch (this) {
        RuleSet.japanese => 6.5,
        RuleSet.chinese => 7.5,
        RuleSet.aga => 7.5,
        RuleSet.newZealand => 7,
      };

  bool get suicideAllowed => this == RuleSet.newZealand;

  bool get usesSuperko => this != RuleSet.japanese;

  bool get areaScoring => this != RuleSet.japanese;
}

enum WinCondition {
  standard,
  captureGo;

  String get title => switch (this) {
        WinCondition.standard => 'Standard game',
        WinCondition.captureGo => 'Capture Go',
      };

  String get summary => switch (this) {
        WinCondition.standard => 'Play until both sides pass, then score the board.',
        WinCondition.captureGo =>
          'First player to capture the goal number of stones wins. Great for beginners.',
      };
}

class GameRules {
  final RuleSet ruleSet;
  final WinCondition winCondition;
  final int boardSize;
  final double komi;
  final int handicap;
  final int captureGoal;

  const GameRules({
    required this.ruleSet,
    this.winCondition = WinCondition.standard,
    this.boardSize = 19,
    required this.komi,
    this.handicap = 0,
    this.captureGoal = 1,
  });

  factory GameRules.preset({
    RuleSet ruleSet = RuleSet.japanese,
    WinCondition winCondition = WinCondition.standard,
    int boardSize = 19,
    int handicap = 0,
    double? komi,
    int captureGoal = 1,
  }) {
    final defaultKomi = handicap >= 2 ? 0.5 : ruleSet.defaultKomi;
    return GameRules(
      ruleSet: ruleSet,
      winCondition: winCondition,
      boardSize: boardSize,
      komi: komi ?? defaultKomi,
      handicap: handicap,
      captureGoal: captureGoal,
    );
  }

  bool get suicideAllowed => ruleSet.suicideAllowed;
  bool get usesSuperko => ruleSet.usesSuperko;
  bool get areaScoring => ruleSet.areaScoring;

  String get description {
    final size = '$boardSize×$boardSize';
    final variant = winCondition == WinCondition.captureGo
        ? 'Capture Go (first to $captureGoal)'
        : ruleSet.title;
    return '$size · $variant · komi $komi';
  }

  GameRules copyWith({
    RuleSet? ruleSet,
    WinCondition? winCondition,
    int? boardSize,
    double? komi,
    int? handicap,
    int? captureGoal,
  }) {
    return GameRules(
      ruleSet: ruleSet ?? this.ruleSet,
      winCondition: winCondition ?? this.winCondition,
      boardSize: boardSize ?? this.boardSize,
      komi: komi ?? this.komi,
      handicap: handicap ?? this.handicap,
      captureGoal: captureGoal ?? this.captureGoal,
    );
  }
}

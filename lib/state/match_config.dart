import '../coach/computer_player.dart';
import '../engine/stone.dart';

enum OpponentKind { local, computer }

class MatchConfig {
  final OpponentKind opponent;
  final AiLevel aiLevel;
  final Stone humanColor;

  const MatchConfig({
    this.opponent = OpponentKind.local,
    this.aiLevel = AiLevel.medium,
    this.humanColor = Stone.black,
  });

  const MatchConfig.local() : this();

  const MatchConfig.computer({
    AiLevel level = AiLevel.medium,
    Stone humanColor = Stone.black,
  }) : this(
          opponent: OpponentKind.computer,
          aiLevel: level,
          humanColor: humanColor,
        );

  bool get vsComputer => opponent == OpponentKind.computer;

  Stone get computerColor => humanColor.opponent;

  String get subtitle {
    if (!vsComputer) {
      return 'Pass and play';
    }
    return 'You ${humanColor.label} · computer ${aiLevel.title}';
  }
}

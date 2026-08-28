import '../ai/engine_kind.dart';
import '../coach/computer_player.dart';
import '../engine/stone.dart';

enum OpponentKind { local, computer }

class MatchConfig {
  final OpponentKind opponent;
  final AiLevel aiLevel;
  final Stone humanColor;
  final EngineKind engine;
  final String? logosUrl;
  final String? logosModel;
  final String? logosApiKey;
  final String? kataGoUrl;

  const MatchConfig({
    this.opponent = OpponentKind.local,
    this.aiLevel = AiLevel.medium,
    this.humanColor = Stone.black,
    this.engine = EngineKind.heuristic,
    this.logosUrl,
    this.logosModel,
    this.logosApiKey,
    this.kataGoUrl,
  });

  const MatchConfig.local({EngineKind engine = EngineKind.heuristic})
      : this(engine: engine);

  const MatchConfig.computer({
    AiLevel level = AiLevel.medium,
    Stone humanColor = Stone.black,
    EngineKind engine = EngineKind.heuristic,
  }) : this(
          opponent: OpponentKind.computer,
          aiLevel: level,
          humanColor: humanColor,
          engine: engine,
        );

  bool get vsComputer => opponent == OpponentKind.computer;

  Stone get computerColor => humanColor.opponent;

  String get subtitle {
    if (!vsComputer) {
      return 'Pass and play · ${engine.title} hints';
    }
    return 'You ${humanColor.label} · ${engine.title} ${aiLevel.title}';
  }
}

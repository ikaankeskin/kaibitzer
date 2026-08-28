import 'engine_kind.dart';
import 'engine_log.dart';
import 'logos_engine.dart';
import 'move_engine.dart';

Future<MoveEngine> createMoveEngine({
  EngineKind kind = EngineKind.heuristic,
  HeuristicEngine? fallback,
  EngineLogSink? log,
}) async {
  final heuristic = fallback ?? HeuristicEngine();
  return switch (kind) {
    EngineKind.heuristic => heuristic,
    EngineKind.katago => heuristic,
    EngineKind.logos => LogosEngine(fallback: heuristic, log: log),
  };
}

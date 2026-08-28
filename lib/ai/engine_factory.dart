import 'engine_factory_stub.dart'
    if (dart.library.io) 'engine_factory_io.dart' as impl;
import 'engine_kind.dart';
import 'engine_log.dart';
import 'move_engine.dart';

export 'engine_kind.dart';
export 'engine_log.dart';
export 'move_engine.dart';

Future<MoveEngine> createMoveEngine({
  EngineKind kind = EngineKind.heuristic,
  HeuristicEngine? fallback,
  EngineLogSink? log,
}) {
  return impl.createMoveEngine(kind: kind, fallback: fallback, log: log);
}

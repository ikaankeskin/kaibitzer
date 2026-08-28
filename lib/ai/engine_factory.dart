import 'engine_factory_stub.dart'
    if (dart.library.io) 'engine_factory_io.dart' as impl;
import 'engine_kind.dart';
import 'engine_log.dart';
import 'move_engine.dart';

export 'engine_kind.dart';
export 'engine_log.dart';
export 'move_engine.dart';
export 'remote_config.dart';

Future<MoveEngine> createMoveEngine({
  EngineKind kind = EngineKind.heuristic,
  HeuristicEngine? fallback,
  EngineLogSink? log,
  String? logosUrl,
  String? logosModel,
  String? logosApiKey,
  String? kataGoUrl,
}) {
  return impl.createMoveEngine(
    kind: kind,
    fallback: fallback,
    log: log,
    logosUrl: logosUrl,
    logosModel: logosModel,
    logosApiKey: logosApiKey,
    kataGoUrl: kataGoUrl,
  );
}

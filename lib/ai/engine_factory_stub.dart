import 'engine_kind.dart';
import 'engine_log.dart';
import 'katago_http.dart';
import 'logos_engine.dart';
import 'move_engine.dart';
import 'remote_config.dart';

Future<MoveEngine> createMoveEngine({
  EngineKind kind = EngineKind.heuristic,
  HeuristicEngine? fallback,
  EngineLogSink? log,
  String? logosUrl,
  String? logosModel,
  String? logosApiKey,
  String? kataGoUrl,
}) async {
  final heuristic = fallback ?? HeuristicEngine();
  final config = RemoteEngineConfig.resolve(
    logosUrl: logosUrl,
    logosModel: logosModel,
    logosApiKey: logosApiKey,
    kataGoUrl: kataGoUrl,
  );
  switch (kind) {
    case EngineKind.heuristic:
      return heuristic;
    case EngineKind.katago:
      final url = config.kataGoUrl;
      if (url == null) {
        log?.call(
          EngineLogEntry(
            source: 'session',
            summary:
                'KataGo has no public web API; set a HTTP server URL or use the desktop app',
            isError: true,
          ),
        );
        return heuristic;
      }
      log?.call(
        EngineLogEntry(
          source: 'session',
          summary: 'Trying KataGo HTTP at $url',
        ),
      );
      if (!await KataGoHttpEngine.reachable(url)) {
        log?.call(
          EngineLogEntry(
            source: 'session',
            summary: 'KataGo HTTP not reachable, using built-in tutor',
            isError: true,
          ),
        );
        return heuristic;
      }
      return KataGoHttpEngine(baseUrl: url, fallback: heuristic, log: log);
    case EngineKind.logos:
      log?.call(
        EngineLogEntry(
          source: 'session',
          summary: 'LoGos via ${config.logosModel} @ ${config.logosUrl}',
        ),
      );
      return LogosEngine(
        fallback: heuristic,
        baseUrl: config.logosUrl,
        model: config.logosModel,
        apiKey: config.logosApiKey,
        log: log,
      );
  }
}

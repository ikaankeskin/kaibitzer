import 'dart:io';

import 'engine_kind.dart';
import 'engine_log.dart';
import 'katago_gtp_io.dart';
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
    logosUrl: logosUrl ?? Platform.environment['LOGOS_URL'],
    logosModel: logosModel ?? Platform.environment['LOGOS_MODEL'],
    logosApiKey: logosApiKey ?? Platform.environment['LOGOS_API_KEY'],
    kataGoUrl: kataGoUrl ?? Platform.environment['KATAGO_URL'],
  );
  switch (kind) {
    case EngineKind.heuristic:
      return heuristic;
    case EngineKind.katago:
      final local = await KataGoGtpEngine.tryLaunch();
      if (local != null) {
        return local;
      }
      final url = config.kataGoUrl;
      if (url != null && await KataGoHttpEngine.reachable(url)) {
        log?.call(
          EngineLogEntry(
            source: 'session',
            summary: 'Local katago.exe missing, using KataGo HTTP at $url',
          ),
        );
        return KataGoHttpEngine(baseUrl: url, fallback: heuristic, log: log);
      }
      return heuristic;
    case EngineKind.logos:
      final local = _isLoopback(config.logosUrl);
      if (local) {
        log?.call(
          EngineLogEntry(
            source: 'session',
            summary: 'Starting Ollama if needed at ${config.logosUrl}',
          ),
        );
        await ensureOllamaRunning(config.logosUrl);
      } else {
        log?.call(
          EngineLogEntry(
            source: 'session',
            summary: 'LoGos via ${config.logosModel} @ ${config.logosUrl}',
          ),
        );
      }
      return LogosEngine(
        fallback: heuristic,
        baseUrl: config.logosUrl,
        model: config.logosModel,
        apiKey: config.logosApiKey,
        log: log,
      );
  }
}

bool _isLoopback(String url) {
  final host = Uri.tryParse(url)?.host;
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

Future<void> ensureOllamaRunning(String baseUrl) async {
  if (await _ollamaUp(baseUrl)) {
    return;
  }
  final localApp = Platform.environment['LOCALAPPDATA'];
  final candidates = <String>[
    if (localApp != null) '$localApp\\Programs\\Ollama\\ollama.exe',
    'ollama',
  ];
  String? exe;
  for (final candidate in candidates) {
    if (candidate == 'ollama') {
      exe = candidate;
      break;
    }
    if (File(candidate).existsSync()) {
      exe = candidate;
      break;
    }
  }
  if (exe == null) {
    return;
  }
  try {
    await Process.start(
      exe,
      const ['serve'],
      mode: ProcessStartMode.detached,
      environment: {
        ...Platform.environment,
        'OLLAMA_ORIGINS': Platform.environment['OLLAMA_ORIGINS'] ?? '*',
      },
    );
  } catch (_) {
    return;
  }
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (await _ollamaUp(baseUrl)) {
      return;
    }
  }
}

Future<bool> _ollamaUp(String baseUrl) async {
  final root = baseUrl.replaceAll(RegExp(r'/$'), '');
  final origin =
      root.endsWith('/v1') ? root.substring(0, root.length - 3) : root;
  final uri = Uri.parse('$origin/api/tags');
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

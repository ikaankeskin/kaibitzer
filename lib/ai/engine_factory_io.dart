import 'dart:io';

import 'engine_kind.dart';
import 'engine_log.dart';
import 'katago_gtp_io.dart';
import 'logos_engine.dart';
import 'move_engine.dart';

Future<MoveEngine> createMoveEngine({
  EngineKind kind = EngineKind.heuristic,
  HeuristicEngine? fallback,
  EngineLogSink? log,
}) async {
  final heuristic = fallback ?? HeuristicEngine();
  switch (kind) {
    case EngineKind.heuristic:
      return heuristic;
    case EngineKind.katago:
      return await KataGoGtpEngine.tryLaunch() ?? heuristic;
    case EngineKind.logos:
      final baseUrl =
          Platform.environment['LOGOS_URL'] ?? 'http://127.0.0.1:11434';
      log?.call(
        EngineLogEntry(
          source: 'session',
          summary: 'Starting Ollama if needed at $baseUrl',
        ),
      );
      await ensureOllamaRunning(baseUrl);
      return LogosEngine(
        fallback: heuristic,
        baseUrl: baseUrl,
        model: Platform.environment['LOGOS_MODEL'] ?? 'logos-7b',
        log: log,
      );
  }
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

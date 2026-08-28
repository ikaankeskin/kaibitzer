import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../coach/kaibitzer_coach.dart';
import '../engine/game.dart';
import '../engine/point.dart';
import 'engine_log.dart';
import 'logos_prompt.dart';
import 'move_engine.dart';

class LogosCompletion {
  final String text;
  final String endpoint;
  final Duration wall;
  final Duration? total;
  final Duration? load;
  final Duration? promptEval;
  final Duration? eval;
  final int? promptTokens;
  final int? evalTokens;

  const LogosCompletion({
    required this.text,
    required this.endpoint,
    required this.wall,
    this.total,
    this.load,
    this.promptEval,
    this.eval,
    this.promptTokens,
    this.evalTokens,
  });

  String get timingSummary {
    final parts = <String>[formatEngineDuration(total ?? wall)];
    if (load != null) {
      parts.add('load ${formatEngineDuration(load!)}');
    }
    if (promptTokens != null && promptEval != null) {
      parts.add(
        'prompt $promptTokens tok / ${formatEngineDuration(promptEval!)}',
      );
    }
    if (evalTokens != null && eval != null) {
      final rate = tokensPerSecond(evalTokens, eval);
      parts.add(
        'gen $evalTokens tok / ${formatEngineDuration(eval!)}'
        '${rate == null ? '' : ' · $rate'}',
      );
    }
    return parts.join(', ');
  }
}

class LogosEngine implements MoveEngine {
  LogosEngine({
    http.Client? client,
    String? baseUrl,
    String? model,
    String? apiKey,
    HeuristicEngine? fallback,
    EngineLogSink? log,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'LOGOS_URL',
              defaultValue: 'http://127.0.0.1:11434',
            ),
        model = model ??
            const String.fromEnvironment(
              'LOGOS_MODEL',
              defaultValue: 'logos-7b',
            ),
        apiKey = apiKey ??
            const String.fromEnvironment(
              'LOGOS_API_KEY',
              defaultValue: '',
            ),
        fallback = fallback ?? HeuristicEngine(),
        _log = log;

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final String model;
  final String apiKey;
  final HeuristicEngine fallback;
  final EngineLogSink? _log;

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    return headers;
  }

  @override
  String get name => 'LoGos-7B';

  @override
  bool get isNeuralNet => true;

  static const _requestTimeout = Duration(minutes: 10);

  double _temperature(AiLevel level) => switch (level) {
        AiLevel.easy => 1.0,
        AiLevel.medium => 0.7,
        AiLevel.hard => 0.2,
      };

  String get _root => baseUrl.replaceAll(RegExp(r'/$'), '');

  bool get _openaiOnly => _root.endsWith('/v1');

  void _emit({
    required String summary,
    String? detail,
    Duration? elapsed,
    bool isError = false,
  }) {
    _log?.call(
      EngineLogEntry(
        source: 'logos',
        summary: summary,
        detail: detail,
        elapsed: elapsed,
        isError: isError,
      ),
    );
  }

  Future<LogosCompletion> _complete(GoGame game, AiLevel level) async {
    final user = logosUserPrompt(game);
    final system = logosSystemPrompt(size: game.size);
    final wall = Stopwatch()..start();
    _emit(
      summary: 'Sending board to $model (${game.size}×${game.size}, ${game.toPlay.label} to play)',
      detail: user,
    );

    if (!_openaiOnly) {
      try {
        final completion = await _completeOllama(system, user, level);
        _logCompletion(completion);
        return completion;
      } on TimeoutException catch (error) {
        _emit(
          summary: 'Ollama /api/chat timed out after ${_requestTimeout.inMinutes} min',
          detail: '$error',
          elapsed: wall.elapsed,
          isError: true,
        );
        rethrow;
      } catch (error) {
        _emit(
          summary: 'Ollama /api/chat failed, trying OpenAI-compatible /v1',
          detail: '$error',
          elapsed: wall.elapsed,
          isError: true,
        );
      }
    }

    final completion = await _completeOpenAi(system, user, level);
    _logCompletion(completion);
    return completion;
  }

  void _logCompletion(LogosCompletion completion) {
    _emit(
      summary: '${completion.endpoint} reply from $model · ${completion.timingSummary}',
      detail: completion.text,
      elapsed: completion.total ?? completion.wall,
    );
  }

  Future<LogosCompletion> _completeOllama(
    String system,
    String user,
    AiLevel level,
  ) async {
    final wall = Stopwatch()..start();
    final origin = _openaiOnly ? _root.substring(0, _root.length - 3) : _root;
    final url = Uri.parse('$origin/api/chat');
    final response = await _client
        .post(
          url,
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'stream': false,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'keep_alive': '30m',
            'options': {
              'temperature': _temperature(level),
              'num_predict': 512,
            },
          }),
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Ollama /api/chat returned ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final message = data['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw StateError('Ollama returned an empty reply.');
    }
    wall.stop();
    return LogosCompletion(
      text: content,
      endpoint: 'Ollama /api/chat',
      wall: wall.elapsed,
      total: durationFromNanos(data['total_duration']),
      load: durationFromNanos(data['load_duration']),
      promptEval: durationFromNanos(data['prompt_eval_duration']),
      eval: durationFromNanos(data['eval_duration']),
      promptTokens: data['prompt_eval_count'] is num
          ? (data['prompt_eval_count'] as num).toInt()
          : null,
      evalTokens: data['eval_count'] is num ? (data['eval_count'] as num).toInt() : null,
    );
  }

  Future<LogosCompletion> _completeOpenAi(
    String system,
    String user,
    AiLevel level,
  ) async {
    final wall = Stopwatch()..start();
    final openaiUrl = Uri.parse(
      _root.endsWith('/v1') ? '$_root/chat/completions' : '$_root/v1/chat/completions',
    );
    final response = await _client
        .post(
          openaiUrl,
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'temperature': _temperature(level),
            'max_tokens': 512,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
          }),
        )
        .timeout(_requestTimeout);
    wall.stop();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'OpenAI /v1/chat/completions returned ${response.statusCode}: ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final message = choices?.first as Map<String, dynamic>?;
    final content = (message?['message'] as Map<String, dynamic>?)?['content'] ??
        message?['text'];
    if (content is! String || content.trim().isEmpty) {
      throw StateError('LoGos returned an empty OpenAI-compatible reply.');
    }
    final usage = data['usage'] as Map<String, dynamic>?;
    final promptTokens = usage?['prompt_tokens'];
    final evalTokens = usage?['completion_tokens'];
    return LogosCompletion(
      text: content,
      endpoint: 'OpenAI /v1/chat/completions',
      wall: wall.elapsed,
      promptTokens: promptTokens is num ? promptTokens.toInt() : null,
      evalTokens: evalTokens is num ? evalTokens.toInt() : null,
    );
  }

  Point? _legalPoint(GoGame game, LogosParseResult parsed) {
    for (final point in [parsed.point, ...parsed.candidates]) {
      if (point != null && game.isLegal(point)) {
        return point;
      }
    }
    return null;
  }

  String _moveLabel(GoGame game, Point? point, {required bool isPass}) {
    if (isPass || point == null) {
      return 'pass';
    }
    return point.toCoordinate(game.size);
  }

  @override
  Future<Point?> genMove(GoGame game, AiLevel level) async {
    try {
      final completion = await _complete(game, level);
      final parsed = parseLogosResponse(completion.text, game.size);
      if (parsed.isPass) {
        _emit(summary: 'Parsed pass from LoGos');
        return null;
      }
      final point = _legalPoint(game, parsed);
      if (point != null) {
        final win = parsed.winrate == null
            ? ''
            : ' · win ${(parsed.winrate! * 100).toStringAsFixed(1)}%';
        _emit(summary: 'Parsed ${_moveLabel(game, point, isPass: false)}$win');
        return point;
      }
      _emit(
        summary: 'Illegal or unparsed LoGos reply, falling back to ${fallback.name}',
        detail: parsed.raw,
        isError: true,
      );
    } catch (error) {
      _emit(
        summary: 'LoGos request failed, falling back to ${fallback.name}',
        detail: '$error',
        isError: true,
      );
    }
    final point = await fallback.genMove(game, level);
    _emit(
      summary: 'Fallback ${fallback.name} chose ${_moveLabel(game, point, isPass: point == null)}',
    );
    return point;
  }

  @override
  Future<List<MoveRecommendation>> analyze(GoGame game, {int max = 3}) async {
    try {
      final completion = await _complete(game, AiLevel.medium);
      final parsed = parseLogosResponse(completion.text, game.size);
      final recs = <MoveRecommendation>[];
      for (final point in parsed.candidates) {
        if (!game.isLegal(point)) {
          continue;
        }
        recs.add(
          MoveRecommendation(
            point: point,
            score: parsed.winrate ?? 0,
            reasons: [
              if (parsed.winrate != null)
                'LoGos win rate ${(parsed.winrate! * 100).toStringAsFixed(1)}%',
              'From LoGos-7B',
            ],
          ),
        );
        if (recs.length >= max) {
          break;
        }
      }
      if (recs.isNotEmpty) {
        _emit(
          summary:
              'Hint ${recs.map((r) => r.point.toCoordinate(game.size)).join(', ')}',
        );
        return recs;
      }
      _emit(
        summary: 'No legal LoGos candidates, falling back to ${fallback.name}',
        isError: true,
      );
    } catch (error) {
      _emit(
        summary: 'LoGos analyze failed, falling back to ${fallback.name}',
        detail: '$error',
        isError: true,
      );
    }
    return fallback.analyze(game, max: max);
  }

  @override
  Future<void> dispose() async {
    if (_ownsClient) {
      _client.close();
    }
    await fallback.dispose();
  }
}

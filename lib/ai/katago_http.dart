import 'dart:convert';

import 'package:http/http.dart' as http;

import '../coach/kaibitzer_coach.dart';
import '../engine/game.dart';
import '../engine/handicap.dart';
import '../engine/point.dart';
import 'engine_log.dart';
import 'move_engine.dart';

/// KataGo via a REST analysis server (e.g. goban-app / stubbi katago-server).
class KataGoHttpEngine implements MoveEngine {
  KataGoHttpEngine({
    required this.baseUrl,
    http.Client? client,
    HeuristicEngine? fallback,
    EngineLogSink? log,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        fallback = fallback ?? HeuristicEngine(),
        _log = log;

  final String baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final HeuristicEngine fallback;
  final EngineLogSink? _log;

  static const _timeout = Duration(seconds: 45);

  @override
  String get name => 'KataGo';

  @override
  bool get isNeuralNet => true;

  String get _root => baseUrl.replaceAll(RegExp(r'/$'), '');

  static Future<bool> reachable(
    String baseUrl, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final owns = client == null;
    final httpClient = client ?? http.Client();
    final root = baseUrl.replaceAll(RegExp(r'/$'), '');
    try {
      for (final path in ['/api/v1/health', '/health', '/']) {
        try {
          final response = await httpClient
              .get(Uri.parse('$root$path'))
              .timeout(timeout);
          if (response.statusCode >= 200 && response.statusCode < 500) {
            return true;
          }
        } catch (_) {
          continue;
        }
      }
      return false;
    } finally {
      if (owns) {
        httpClient.close();
      }
    }
  }

  Map<String, dynamic> analysisBody(GoGame game, {required int maxVisits}) {
    final handicap = [
      for (final point in handicapPoints(game.rules))
        ['B', point.toCoordinate(game.size)],
    ];
    final moves = <String>[];
    for (final move in game.moves) {
      if (move.kind == MoveKind.pass) {
        moves.add('pass');
      } else if (move.kind == MoveKind.place && move.point != null) {
        moves.add(move.point!.toCoordinate(game.size));
      }
    }
    return {
      'moves': moves,
      'komi': game.rules.komi,
      'rules': kataRulesName(game.rules.ruleSet),
      'boardXSize': game.size,
      'boardYSize': game.size,
      'maxVisits': maxVisits,
      if (handicap.isNotEmpty) 'initialStones': handicap,
      if (handicap.isNotEmpty) 'initialPlayer': 'W',
    };
  }

  Future<Map<String, dynamic>> _analyze(GoGame game, AiLevel level) async {
    final url = Uri.parse('$_root/api/v1/analysis');
    final response = await _client
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(analysisBody(game, maxVisits: analyzeVisits(level))),
        )
        .timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'KataGo HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw StateError('KataGo HTTP returned a non-object JSON body.');
    }
    return data;
  }

  void _emit(String summary, {String? detail, bool isError = false}) {
    _log?.call(
      EngineLogEntry(
        source: 'katago',
        summary: summary,
        detail: detail,
        isError: isError,
      ),
    );
  }

  @override
  Future<Point?> genMove(GoGame game, AiLevel level) async {
    try {
      final data = await _analyze(game, level);
      final recs = parseKataGoHttpAnalysis(data, game.size, max: 1);
      if (recs.isEmpty) {
        _emit('KataGo HTTP suggested pass / no move');
        return null;
      }
      final point = recs.first.point;
      if (!game.isLegal(point)) {
        throw StateError('Illegal KataGo HTTP move ${point.toCoordinate(game.size)}');
      }
      _emit('KataGo HTTP chose ${point.toCoordinate(game.size)}');
      return point;
    } catch (error) {
      _emit(
        'KataGo HTTP failed, falling back to ${fallback.name}',
        detail: '$error',
        isError: true,
      );
      return fallback.genMove(game, level);
    }
  }

  @override
  Future<List<MoveRecommendation>> analyze(GoGame game, {int max = 3}) async {
    try {
      final data = await _analyze(game, AiLevel.medium);
      final recs = parseKataGoHttpAnalysis(data, game.size, max: max)
          .where((rec) => game.isLegal(rec.point))
          .toList();
      if (recs.isNotEmpty) {
        return recs;
      }
    } catch (error) {
      _emit(
        'KataGo HTTP analyze failed, falling back to ${fallback.name}',
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

List<MoveRecommendation> parseKataGoHttpAnalysis(
  Map<String, dynamic> data,
  int boardSize, {
  int max = 3,
}) {
  final raw = data['moveInfos'] ?? data['move_infos'];
  if (raw is! List) {
    return const [];
  }
  final parsed = <({int order, int visits, MoveRecommendation rec})>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final coord = (map['moveCoord'] ?? map['move'] ?? map['move_coord']) as String?;
    if (coord == null || coord.toLowerCase() == 'pass') {
      continue;
    }
    final point = Point.parse(coord, boardSize);
    if (point == null) {
      continue;
    }
    final winrate = (map['winrate'] as num?)?.toDouble();
    final visits = (map['visits'] as num?)?.toInt() ?? 0;
    final order = (map['order'] as num?)?.toInt() ?? 999;
    parsed.add(
      (
        order: order,
        visits: visits,
        rec: MoveRecommendation(
          point: point,
          score: winrate ?? visits.toDouble(),
          reasons: [
            if (winrate != null) 'Win ${(winrate * 100).toStringAsFixed(1)}%',
            if (visits > 0) '$visits visits',
            'KataGo HTTP',
          ],
        ),
      ),
    );
  }
  parsed.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) {
      return byOrder;
    }
    return b.visits.compareTo(a.visits);
  });
  return [for (final row in parsed.take(max)) row.rec];
}

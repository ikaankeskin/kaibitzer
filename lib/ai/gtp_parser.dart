import '../coach/kaibitzer_coach.dart';
import '../engine/point.dart';

/// Parses GTP and KataGo analyze output. Pure Dart so tests do not need a binary.
class GtpParser {
  static String? genmoveCoordinate(String response) {
    final match = RegExp(r'^[=?](?:\s+id)?\s*(pass|resign|[A-HJ-T]\d{1,2})\s*$',
            caseSensitive: false, multiLine: true)
        .firstMatch(response.trim());
    if (match == null) {
      final loose = RegExp(r'=\s*(pass|resign|[A-HJ-T]\d{1,2})', caseSensitive: false)
          .firstMatch(response);
      if (loose == null) {
        return null;
      }
      return loose.group(1)!.toUpperCase();
    }
    return match.group(1)!.toUpperCase();
  }

  static Point? genmovePoint(String response, int boardSize) {
    final coord = genmoveCoordinate(response);
    if (coord == null || coord == 'PASS' || coord == 'RESIGN') {
      return null;
    }
    return Point.parse(coord, boardSize);
  }

  static List<MoveRecommendation> analyzeRecommendations(
    String buffer,
    int boardSize, {
    int max = 3,
  }) {
    final recs = <MoveRecommendation>[];
    final infos = RegExp(r'info move ([A-HJ-T]\d{1,2})(.*?)(?=info move |\s*$)',
            caseSensitive: false, dotAll: true)
        .allMatches(buffer);
    final parsed = <_KataInfo>[];
    for (final match in infos) {
      final point = Point.parse(match.group(1)!, boardSize);
      if (point == null) {
        continue;
      }
      final rest = match.group(2) ?? '';
      final visits = int.tryParse(RegExp(r'visits (\d+)').firstMatch(rest)?.group(1) ?? '') ?? 0;
      final win = double.tryParse(RegExp(r'winrate ([0-9.]+)').firstMatch(rest)?.group(1) ?? '');
      final order = int.tryParse(RegExp(r'order (\d+)').firstMatch(rest)?.group(1) ?? '') ?? 99;
      parsed.add(_KataInfo(point: point, visits: visits, winrate: win, order: order));
    }
    parsed.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) {
        return byOrder;
      }
      return b.visits.compareTo(a.visits);
    });
    for (final info in parsed.take(max)) {
      final reasons = <String>[
        if (info.winrate != null)
          'KataGo win rate ${(info.winrate! * 100).toStringAsFixed(1)}%',
        '${info.visits} visits',
      ];
      recs.add(
        MoveRecommendation(
          point: info.point,
          score: info.visits.toDouble(),
          reasons: reasons,
        ),
      );
    }
    return recs;
  }
}

class _KataInfo {
  final Point point;
  final int visits;
  final double? winrate;
  final int order;

  _KataInfo({
    required this.point,
    required this.visits,
    required this.winrate,
    required this.order,
  });
}

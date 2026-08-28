import 'package:flutter_test/flutter_test.dart';
import 'package:kaibitzer/ai/gtp_parser.dart';
import 'package:kaibitzer/coach/kaibitzer_coach.dart';
import 'package:kaibitzer/engine/point.dart';
import 'package:kaibitzer/engine/rules.dart';
import 'package:kaibitzer/engine/stone.dart';
import 'package:kaibitzer/state/game_session.dart';
import 'package:kaibitzer/state/match_config.dart';

void main() {
  test('parses a genmove coordinate', () {
    expect(GtpParser.genmoveCoordinate('= Q16\n'), 'Q16');
    expect(GtpParser.genmovePoint('= pass', 19), isNull);
    expect(GtpParser.genmovePoint('= D4', 19), const Point(3, 15));
  });

  test('parses katago analyze info lines', () {
    const buffer =
        'info move Q16 visits 120 winrate 0.61 order 0 pv Q16 D4 '
        'info move D4 visits 80 winrate 0.55 order 1 pv D4 Q16 '
        'info move C3 visits 20 winrate 0.44 order 2 pv C3';
    final recs = GtpParser.analyzeRecommendations(buffer, 19, max: 3);
    expect(recs, hasLength(3));
    expect(recs[0].point, const Point(15, 3));
    expect(recs[0].headline, contains('61'));
  });

  test('playHint places the numbered suggestion', () {
    final session = GameSession.start(
      rules: GameRules.preset(boardSize: 9),
      match: const MatchConfig.local(),
    );
    session.hints = [
      const MoveRecommendation(
        point: Point(2, 2),
        score: 1,
        reasons: ['test'],
      ),
    ];
    session.showHints = true;
    session.playHint(0);
    expect(session.game.board.at(const Point(2, 2)), Stone.black);
    session.dispose();
  });
}

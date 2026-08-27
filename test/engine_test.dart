import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaibitzer/coach/computer_player.dart';
import 'package:kaibitzer/coach/kaibitzer_coach.dart';
import 'package:kaibitzer/engine/game.dart';
import 'package:kaibitzer/engine/point.dart';
import 'package:kaibitzer/engine/rules.dart';
import 'package:kaibitzer/engine/stone.dart';

void main() {
  group('Go engine', () {
    test('white can play after black opening', () {
      final game = GoGame(GameRules.preset(boardSize: 9));
      expect(game.toPlay, Stone.black);
      expect(game.play(const Point(4, 4)).ok, isTrue);
      expect(game.toPlay, Stone.white);
      expect(game.play(const Point(3, 3)).ok, isTrue);
      expect(game.board.at(const Point(4, 4)), Stone.black);
      expect(game.board.at(const Point(3, 3)), Stone.white);
      expect(game.toPlay, Stone.black);
    });

    test('captures a surrounded stone', () {
      final game = GoGame(GameRules.preset(boardSize: 9));
      expect(game.play(const Point(1, 0)).ok, isTrue);
      expect(game.play(const Point(0, 0)).ok, isTrue);
      expect(game.play(const Point(0, 1)).ok, isTrue);
      expect(game.board.at(const Point(0, 0)), Stone.empty);
      expect(game.blackCaptures, 1);
    });

    test('japanese suicide is illegal, new zealand suicide is legal', () {
      final jp = GoGame(GameRules.preset(boardSize: 5, ruleSet: RuleSet.japanese));
      jp.play(const Point(2, 2));
      jp.play(const Point(1, 0));
      jp.play(const Point(2, 3));
      jp.play(const Point(0, 1));
      expect(jp.play(const Point(0, 0)).ok, isFalse);

      final nz = GoGame(GameRules.preset(boardSize: 5, ruleSet: RuleSet.newZealand));
      nz.play(const Point(2, 2));
      nz.play(const Point(1, 0));
      nz.play(const Point(2, 3));
      nz.play(const Point(0, 1));
      expect(nz.play(const Point(0, 0)).ok, isTrue);
      expect(nz.board.at(const Point(0, 0)), Stone.empty);
    });

    test('simple ko forbids immediate recapture', () {
      final game = GoGame(GameRules.preset(boardSize: 7, ruleSet: RuleSet.japanese));
      // Classic ko around (2,1)/(3,1).
      // Black stones: (2,0), (1,1), (2,2)
      // White stones: (3,0), (4,1), (3,2), and White occupies (2,1)
      // Black then plays (3,1) capturing (2,1). White cannot immediately recapture at (2,1).
      final setup = <Point>[
        const Point(2, 0), // B
        const Point(3, 0), // W
        const Point(1, 1), // B
        const Point(4, 1), // W
        const Point(2, 2), // B
        const Point(3, 2), // W
        const Point(5, 5), // B tenuki
        const Point(2, 1), // W in the ko
      ];
      for (final p in setup) {
        expect(game.play(p).ok, isTrue, reason: 'setup $p');
      }
      expect(game.play(const Point(3, 1)).ok, isTrue); // Black captures
      expect(game.board.at(const Point(2, 1)), Stone.empty);
      expect(game.play(const Point(2, 1)).ok, isFalse); // ko
      expect(game.play(const Point(6, 6)).ok, isTrue); // White tenuki
      expect(game.play(const Point(0, 0)).ok, isTrue); // Black tenuki
      expect(game.play(const Point(2, 1)).ok, isTrue); // now legal
    });

    test('two passes enter scoring in a standard game', () {
      final game = GoGame(GameRules.preset(boardSize: 9));
      expect(game.pass().ok, isTrue);
      expect(game.pass().ok, isTrue);
      expect(game.phase, GamePhase.scoring);
    });

    test('capture go ends when the goal is reached', () {
      final game = GoGame(
        GameRules.preset(
          boardSize: 9,
          winCondition: WinCondition.captureGo,
          captureGoal: 1,
        ),
      );
      game.play(const Point(1, 0));
      game.play(const Point(0, 0));
      game.play(const Point(0, 1));
      expect(game.phase, GamePhase.finished);
      expect(game.winner, Stone.black);
    });

    test('handicap places black stones and white moves first', () {
      final game = GoGame(GameRules.preset(boardSize: 19, handicap: 4));
      expect(game.board.stoneCount(Stone.black), 4);
      expect(game.toPlay, Stone.white);
    });

    test('chinese area scoring counts stones', () {
      final game = GoGame(
        GameRules.preset(boardSize: 5, ruleSet: RuleSet.chinese, komi: 0),
      );
      game.play(const Point(0, 0));
      game.play(const Point(4, 4));
      game.pass();
      game.pass();
      game.confirmScore();
      final score = game.currentScore();
      expect(score.method, 'Area');
      expect(score.blackStones, greaterThan(0));
    });
  });

  group('Coach', () {
    test('recommends a legal move', () {
      final game = GoGame(GameRules.preset(boardSize: 9));
      final recs = KaibitzerCoach().recommend(game, max: 3);
      expect(recs, isNotEmpty);
      for (final rec in recs) {
        expect(game.isLegal(rec.point), isTrue);
      }
    });

    test('answers a recommendation question', () {
      final game = GoGame(GameRules.preset(boardSize: 9));
      final reply = KaibitzerCoach().answer(game, 'What is a good move?');
      expect(reply.fromCoach, isTrue);
      expect(reply.recommendations, isNotEmpty);
    });

    test('computer replies with a legal move', () {
      final game = GoGame(GameRules.preset(boardSize: 9));
      expect(game.play(const Point(4, 4)).ok, isTrue);
      final point = ComputerPlayer(random: Random(7)).choose(game, AiLevel.hard);
      expect(point, isNotNull);
      expect(game.isLegal(point!), isTrue);
    });
  });

  test('coordinates skip the letter I', () {
    expect(const Point(8, 0).toCoordinate(19), 'J19');
    expect(Point.parse('Q16', 19), const Point(15, 3));
  });
}

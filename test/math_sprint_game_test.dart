import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindmaster/features/games/math_sprint/math_sprint_game.dart';

void main() {
  group('question generation', () {
    // A fixed seed keeps generation failures reproducible. Without this, a rare
    // bad draw would only appear in production.
    MathSprintGame seeded() => MathSprintGame(random: Random(1234));

    test('always produces a question with a correct answer', () {
      final game = seeded();
      for (var i = 0; i < 500; i++) {
        final q = game.next(Difficulty.medium);
        final expected = switch (q.operation) {
          Operation.add => q.first + q.second,
          Operation.subtract => q.first - q.second,
          Operation.multiply => q.first * q.second,
          Operation.divide => q.first ~/ q.second,
        };
        expect(q.answer, expected, reason: 'wrong answer for ${q.expression}');
      }
    });

    test('subtraction never yields a negative answer', () {
      final game = seeded();
      for (var i = 0; i < 500; i++) {
        final q = game.next(Difficulty.easy);
        if (q.operation == Operation.subtract) {
          expect(q.answer, greaterThan(0), reason: 'got ${q.expression}');
        }
      }
    });

    test('division is always exact', () {
      final game = seeded();
      var sawDivision = false;
      for (var i = 0; i < 500; i++) {
        final q = game.next(Difficulty.hard);
        if (q.operation == Operation.divide) {
          sawDivision = true;
          expect(q.first % q.second, 0,
              reason: '${q.expression} is not an exact division');
        }
      }
      expect(sawDivision, isTrue, reason: 'division never appeared at hard');
    });

    test('easy tier never generates multiplication or division', () {
      final game = seeded();
      for (var i = 0; i < 300; i++) {
        final q = game.next(Difficulty.easy);
        expect(q.operation, isNot(Operation.multiply));
        expect(q.operation, isNot(Operation.divide));
      }
    });

    test('operands stay positive', () {
      final game = seeded();
      for (var i = 0; i < 300; i++) {
        final q = game.next(Difficulty.hard);
        expect(q.first, greaterThan(0));
        expect(q.second, greaterThan(0));
      }
    });

    test('does not repeat one operation more than twice in a row', () {
      final game = seeded();
      final seen = <Operation>[];
      for (var i = 0; i < 400; i++) {
        seen.add(game.next(Difficulty.hard).operation);
      }
      for (var i = 2; i < seen.length; i++) {
        final triple = [seen[i - 2], seen[i - 1], seen[i]];
        expect(triple.toSet().length, greaterThan(1),
            reason: 'three identical operations in a row: $triple');
      }
    });

    test('generator counter advances', () {
      final game = seeded();
      expect(game.questionsGenerated, 0);
      game.next(Difficulty.easy);
      game.next(Difficulty.easy);
      expect(game.questionsGenerated, 2);
    });
  });

  group('expression rendering', () {
    test('uses real operator glyphs, not enum names', () {
      expect(const MathQuestion(2, 3, Operation.add, 5).expression, '2 + 3');
      expect(const MathQuestion(5, 3, Operation.subtract, 2).expression, '5 − 3');
      expect(const MathQuestion(2, 3, Operation.multiply, 6).expression, '2 × 3');
      expect(const MathQuestion(6, 3, Operation.divide, 2).expression, '6 ÷ 3');
    });
  });

  group('difficulty scaling', () {
    test('score maps to increasing tiers', () {
      expect(Difficulty.forScore(0), Difficulty.easy);
      expect(Difficulty.forScore(59), Difficulty.easy);
      expect(Difficulty.forScore(60), Difficulty.medium);
      expect(Difficulty.forScore(179), Difficulty.medium);
      expect(Difficulty.forScore(180), Difficulty.hard);
    });

    test('harder tiers allow larger operands', () {
      expect(Difficulty.medium.maxOperand, greaterThan(Difficulty.easy.maxOperand));
      expect(Difficulty.hard.maxOperand, greaterThan(Difficulty.medium.maxOperand));
    });
  });

  group('streak multiplier', () {
    test('starts at 1x and never exceeds 5x', () {
      expect(MathSprintGame.multiplierFor(0), 1);
      expect(MathSprintGame.multiplierFor(2), 1);
      expect(MathSprintGame.multiplierFor(50), 5);
    });

    test('is monotonically non-decreasing', () {
      var previous = 0;
      for (var streak = 0; streak < 40; streak++) {
        final m = MathSprintGame.multiplierFor(streak);
        expect(m, greaterThanOrEqualTo(previous));
        previous = m;
      }
    });

    test('points grow with streak and difficulty', () {
      final low = MathSprintGame.pointsFor(streak: 1, difficultyLevel: 1);
      final highStreak = MathSprintGame.pointsFor(streak: 10, difficultyLevel: 1);
      final highTier = MathSprintGame.pointsFor(streak: 1, difficultyLevel: 3);
      expect(highStreak, greaterThan(low));
      expect(highTier, greaterThan(low));
    });
  });

  group('round state', () {
    test('correct answers raise score, streak and best streak', () {
      final s = RoundState(durationSeconds: 60);
      final first = s.answerCorrect();
      final second = s.answerCorrect();
      expect(s.score, first + second);
      expect(s.streak, 2);
      expect(s.bestStreak, 2);
    });

    test('a wrong answer resets the streak but keeps best streak', () {
      final s = RoundState(durationSeconds: 60);
      s.answerCorrect();
      s.answerCorrect();
      s.answerWrong();
      expect(s.streak, 0);
      expect(s.bestStreak, 2);
      expect(s.wrong, 1);
      expect(s.correct, 2);
    });

    test('timer counts down and stops at zero', () {
      final s = RoundState(durationSeconds: 60);
      s.tick(30);
      expect(s.remaining, closeTo(30, 0.001));
      s.tick(300); // overshoot
      expect(s.remaining, 0);
      expect(s.finished, isTrue);
    });

    test('finished round ignores further ticks', () {
      final s = RoundState(durationSeconds: 10)..tick(10);
      expect(s.finished, isTrue);
      s.tick(5);
      expect(s.remaining, 0);
    });

    test('final five seconds flag only true near the end', () {
      final s = RoundState(durationSeconds: 60);
      expect(s.isLastFiveSeconds, isFalse);
      s.tick(56);
      expect(s.isLastFiveSeconds, isTrue);
    });

    test('accuracy is percentage of total attempts', () {
      final s = RoundState(durationSeconds: 60);
      for (var i = 0; i < 7; i++) {
        s.answerCorrect();
      }
      s.answerWrong();
      s.answerWrong();
      // 7 of 9 is 77.8%, and the score intentionally truncates rather than
      // rounding, so 9 questions can never display 78%.
      expect(s.toResult().accuracy, 77);
      expect(s.toResult().accuracy, lessThanOrEqualTo(100));
    });

    test('accuracy truncates instead of rounding', () {
      final s = RoundState(durationSeconds: 60);
      for (var i = 0; i < 8; i++) {
        s.answerCorrect();
      }
      s.answerWrong();
      s.answerWrong();
      // 8 of 10 is exactly 80, and must not become 79 or 81.
      expect(s.toResult().accuracy, 80);
    });

    test('accuracy of an empty round is zero, not a crash', () {
      expect(RoundState(durationSeconds: 60).toResult().accuracy, 0);
    });
  });
}
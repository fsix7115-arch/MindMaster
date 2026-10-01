/// Pure Dart game logic for Math Sprint.
///
/// Deliberately free of any Flutter import so it can be unit-tested on the JVM/CI
/// without a display, and so the scoring rules can be reviewed in isolation from
/// the widget code that renders them.
///
/// Rules implemented:
///   - a 60 second round
///   - questions get harder as the score rises
///   - a correct answer extends nothing; the clock is the only limit
///   - streak multiplier rewards consecutive correct answers, and a wrong answer
///     resets it
///   - a question that would be too slow to read (very large operands) is not
///     generated, because it measures reading speed rather than arithmetic
library;

import 'dart:math';

/// Difficulty tiers. The index is the "level"; higher means harder.
enum Difficulty {
  easy(1, 10, 2),
  medium(2, 25, 3),
  hard(3, 60, 4);

  const Difficulty(this.level, this.maxOperand, this.maxTerms);

  final int level;
  final int maxOperand;

  /// Most terms a single question may contain at this level (2 = "a + b").
  final int maxTerms;

  /// Difficulty for a given score. Chosen so that the first minute stays easy
  /// enough to be fun and the difficulty genuinely climbs within a round.
  static Difficulty forScore(int score) {
    if (score < 60) return easy;
    if (score < 180) return medium;
    return hard;
  }
}

/// Which operation a question uses.
enum Operation { add, subtract, multiply, divide }

/// A single generated question. [answer] is always a whole number; division is
/// only ever generated as exact division so the answer is never a decimal.
class MathQuestion {
  const MathQuestion(this.first, this.second, this.operation, this.answer);

  final int first;
  final int second;
  final Operation operation;
  final int answer;

  /// Rendered form, e.g. `12 + 7`. Uses the real operator glyph so it reads
  /// correctly for a user, not the Dart enum name.
  String get expression {
    final symbol = switch (operation) {
      Operation.add => '+',
      Operation.subtract => '−', // minus sign, not hyphen
      Operation.multiply => '×', // multiplication sign, not letter x
      Operation.divide => '÷',
    };
    return '$first $symbol $second';
  }

  @override
  String toString() => 'MathQuestion($expression = $answer)';
}

/// Round-wide scoring and question generation.
class MathSprintGame {
  MathSprintGame({this.durationSeconds = 60, Random? random})
      : _random = random ?? Random();

  final int durationSeconds;
  final Random _random;

  /// Tracks whether the generator produced anything usable, so the widget layer
  /// can assert on it rather than silently showing an empty question.
  int questionsGenerated = 0;

  final List<Operation> _recentOps = [];

  /// Base points for a correct answer before streak multiplier.
  static const int basePoints = 10;

  /// Streak multiplier grows to at most 5x. Jumping straight to a high
  /// multiplier rewards a lucky opening, so it steps rather than ramps.
  static int multiplierFor(int streak) {
    if (streak < 3) return 1;
    if (streak < 6) return 2;
    if (streak < 10) return 3;
    if (streak < 15) return 4;
    return 5;
  }

  /// Points awarded for one correct answer at the given streak.
  static int pointsFor({required int streak, required int difficultyLevel}) {
    final multiplier = multiplierFor(streak);
    final tierBonus = difficultyLevel - Difficulty.easy.level + 1; // 1..3
    return basePoints * multiplier * tierBonus;
  }

  int _lastAnswer(Operation op, int a, int b) => switch (op) {
        Operation.add => a + b,
        Operation.subtract => a - b,
        Operation.multiply => a * b,
        Operation.divide => a ~/ b,
      };

  /// Generates the next question, tuned to [difficulty].
  ///
  /// Guarantees:
  ///   - subtraction never goes negative, since a negative answer is confusing
  ///     for an arithmetic trainer and breaks a simple number pad
  ///   - division is exact (the divisor divides the dividend), so no rounding
  ///   - the operation is not the same one three times running, to stop the
  ///     player from rhythm-guessing "+" without reading
  MathQuestion next(Difficulty difficulty) {
    final max = difficulty.maxOperand;

    for (var attempt = 0; attempt < 24; attempt++) {
      final op = _pickOperation(difficulty);
      final a = _random.nextInt(max) + 1;
      var b = _random.nextInt(max) + 1;

      if (op == Operation.subtract) {
        // Swap so the larger value comes first; result stays positive.
        final hi = a > b ? a : b;
        final lo = a > b ? b : a;
        if (lo == hi) continue; // would be zero; avoid a trivial question
        return _finish(hi, lo, op);
      }

      if (op == Operation.divide) {
        // Build an exact division: pick a quotient, then multiply back.
        final quotient = _random.nextInt(6) + 1; // 1..6
        b = _random.nextInt(4) + 1; // small divisor keeps the answer readable
        final dividend = b * quotient;
        if (dividend > max * 2) continue; // too big to read at a glance
        return _finish(dividend, b, op);
      }

      if (op == Operation.multiply && (a * b) > max * 3) {
        continue; // result too large to scan quickly
      }

      return _finish(a, b, op);
    }

    // Fallback: a guaranteed-valid addition. Reached only if every random draw
    // was rejected, which is vanishingly unlikely but must never return nothing.
    final x = _random.nextInt(max) + 1;
    final y = _random.nextInt(max) + 1;
    return _finish(x, y, Operation.add);
  }

  MathQuestion _finish(int a, int b, Operation op) {
    _recentOps.add(op);
    if (_recentOps.length > 2) _recentOps.removeAt(0);
    questionsGenerated++;
    return MathQuestion(a, b, op, _lastAnswer(op, a, b));
  }

  Operation _pickOperation(Difficulty difficulty) {
    final pool = switch (difficulty) {
      // Division is introduced only at medium; it is the slowest operation to
      // verify mentally, and early questions should build confidence fast.
      Difficulty.easy => const [Operation.add, Operation.subtract],
      Difficulty.medium =>
        const [Operation.add, Operation.subtract, Operation.multiply, Operation.divide],
      Difficulty.hard =>
        const [Operation.add, Operation.subtract, Operation.multiply, Operation.divide],
    };

    final fresh = pool.where((o) => !_recentOps.contains(o)).toList();
    final choices = fresh.isEmpty ? pool : fresh;
    return choices[_random.nextInt(choices.length)];
  }
}

/// Immutable snapshot of a finished round, used by the results screen and by
/// stats persistence.
class RoundResult {
  const RoundResult({
    required this.score,
    required this.correct,
    required this.wrong,
    required this.bestStreak,
    required this.longestQuestion,
  });

  final int score;
  final int correct;
  final int wrong;
  final int bestStreak;

  /// Slowest single question, in seconds. Recorded because a fast round with a
  /// huge gap is a different skill from a uniformly fast round.
  final double longestQuestion;

  int get accuracy =>
      (correct + wrong) == 0 ? 0 : (correct * 100 ~/ (correct + wrong));

  @override
  String toString() => 'RoundResult(score=$score, correct=$correct, '
      'wrong=$wrong, bestStreak=$bestStreak, accuracy=$accuracy%)';
}

/// Live round state. Kept separate from [MathSprintGame] so the generator stays
/// pure and testable while this tracks the session.
class RoundState {
  RoundState({required this.durationSeconds}) : remaining = durationSeconds.toDouble();

  final int durationSeconds;
  double remaining;
  int score = 0;
  int correct = 0;
  int wrong = 0;
  int streak = 0;
  int bestStreak = 0;
  MathQuestion? current;
  bool finished = false;

  double get elapsed => durationSeconds - remaining;

  bool get isLastFiveSeconds => remaining <= 5 && remaining > 0;

  /// Registers a correct answer and returns the points awarded, so the UI can
  /// animate exactly the number that was credited.
  int answerCorrect() {
    correct++;
    streak++;
    if (streak > bestStreak) bestStreak = streak;
    final points = MathSprintGame.pointsFor(
      streak: streak,
      difficultyLevel: Difficulty.forScore(score).level,
    );
    score += points;
    return points;
  }

  /// Registers a wrong answer. The streak resets — that is the whole point of a
  /// streak bonus, otherwise there is no cost to guessing.
  void answerWrong() {
    wrong++;
    streak = 0;
  }

  void tick(double dt) {
    if (finished) return;
    remaining -= dt;
    if (remaining <= 0) {
      remaining = 0;
      finished = true;
    }
  }

  RoundResult toResult() => RoundResult(
        score: score,
        correct: correct,
        wrong: wrong,
        bestStreak: bestStreak,
        longestQuestion: 0, // filled in by the UI layer which owns timings
      );
}
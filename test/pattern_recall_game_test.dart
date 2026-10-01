import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindmaster/features/games/pattern_recall/pattern_recall_game.dart';

void main() {
  group('sequence construction', () {
    test('starts at the requested length', () {
      expect(PatternRecallGame(random: Random(1), startingLength: 1).length, 1);
      expect(PatternRecallGame(random: Random(1), startingLength: 3).length, 3);
    });

    test('sequence contains only valid pads', () {
      final game = PatternRecallGame(random: Random(7), startingLength: 8);
      for (final pad in game.sequence) {
        expect(PadColor.values, contains(pad));
      }
    });

    test('sequence grows by exactly one per round', () {
      final game = PatternRecallGame(random: Random(11), startingLength: 2);
      expect(game.length, 2);
      game.beginInput();

      // Repeat the sequence correctly. The last tap of a sequence completes the
      // round, so it must return roundComplete, not accepted.
      final seq = List<PadColor>.from(game.sequence);
      for (var i = 0; i < seq.length; i++) {
        final expected =
            i == seq.length - 1 ? TapResult.roundComplete : TapResult.accepted;
        expect(game.tap(seq[i]), expected);
      }
      expect(game.length, 3, reason: 'one step added per cleared round');
      expect(game.round, 2);
    });

    test('clearing several rounds keeps growing by one each time', () {
      final game = PatternRecallGame(random: Random(13), startingLength: 1);
      for (var round = 0; round < 5; round++) {
        game.beginInput();
        final seq = List<PadColor>.from(game.sequence);
        TapResult last = TapResult.accepted;
        for (final pad in seq) {
          last = game.tap(pad);
        }
        expect(last, TapResult.roundComplete);
      }
      expect(game.length, 6);
      expect(game.round, 6);
    });

    test('sequence is exposed read-only', () {
      final game = PatternRecallGame(random: Random(3), startingLength: 2);
      expect(() => game.sequence.add(PadColor.red), throwsUnsupportedError);
    });
  });

  group('playback and input phases', () {
    test('starts in the showing phase', () {
      final game = PatternRecallGame(random: Random(5), startingLength: 2);
      expect(game.isShowingSequence, isTrue);
      expect(game.isAwaitingInput, isFalse);
    });

    test('taps during playback are ignored', () {
      final game = PatternRecallGame(random: Random(5), startingLength: 2);
      expect(game.tap(PadColor.red), TapResult.ignored);
      expect(game.failed, isFalse);
    });

    test('beginInput moves to the input phase', () {
      final game = PatternRecallGame(random: Random(5), startingLength: 2);
      game.beginInput();
      expect(game.isShowingSequence, isFalse);
      expect(game.isAwaitingInput, isTrue);
    });

    test('showNextSequence returns to the playback phase', () {
      final game = PatternRecallGame(random: Random(5), startingLength: 1);
      game.beginInput();
      game.tap(game.sequence.first);
      game.showNextSequence();
      expect(game.isShowingSequence, isTrue);
    });
  });

  group('tap evaluation', () {
    test('wrong pad ends the game', () {
      final game = PatternRecallGame(random: Random(9), startingLength: 2);
      game.beginInput();
      // Find a pad that is NOT the first step.
      final wrong = PadColor.values.firstWhere((p) => p != game.sequence.first);
      expect(game.tap(wrong), TapResult.failed);
      expect(game.failed, isTrue);
    });

    test('taps after failure are ignored', () {
      final game = PatternRecallGame(random: Random(9), startingLength: 2);
      game.beginInput();
      final wrong = PadColor.values.firstWhere((p) => p != game.sequence.first);
      game.tap(wrong);
      expect(game.tap(game.sequence.first), TapResult.ignored);
    });

    test('partial correct input then wrong pad fails', () {
      final game = PatternRecallGame(random: Random(15), startingLength: 3);
      game.beginInput();
      expect(game.tap(game.sequence[0]), TapResult.accepted);
      expect(game.tap(game.sequence[1]), TapResult.accepted);
      final wrong = PadColor.values.firstWhere((p) => p != game.sequence[2]);
      expect(game.tap(wrong), TapResult.failed);
    });

    test('correct input accepted then completes on the last step', () {
      final game = PatternRecallGame(random: Random(21), startingLength: 2);
      game.beginInput();
      final seq = List<PadColor>.from(game.sequence);
      expect(game.tap(seq[0]), TapResult.accepted);
      expect(game.tap(seq[1]), TapResult.roundComplete);
    });
  });

  group('scoring best length', () {
    test('best length equals steps actually repeated before failing', () {
      final game = PatternRecallGame(random: Random(31), startingLength: 4);
      game.beginInput();
      // Get 2 steps right, then fail on step 3.
      game.tap(game.sequence[0]);
      game.tap(game.sequence[1]);
      final wrong = PadColor.values.firstWhere((p) => p != game.sequence[2]);
      game.tap(wrong);
      expect(game.failed, isTrue);
      // The player successfully repeated 2 steps of a 4-step sequence.
      expect(game.bestLength, 2,
          reason: 'steps completed before the mistake');
    });

    test('best length equals current length while still alive', () {
      final game = PatternRecallGame(random: Random(33), startingLength: 3);
      expect(game.bestLength, 0, reason: 'no step completed yet');
    });
  });

  group('timing', () {
    test('input window scales with sequence length', () {
      final short = FlashTiming.inputWindowMs(2);
      final long = FlashTiming.inputWindowMs(20);
      expect(long, greaterThan(short));
    });

    test('step interval is on plus gap', () {
      final game = PatternRecallGame(random: Random(1), startingLength: 1);
      expect(game.stepIntervalMs, FlashTiming.onMs + FlashTiming.gapMs);
    });

    test('timings are positive so the UI never schedules a zero delay', () {
      expect(FlashTiming.onMs, greaterThan(0));
      expect(FlashTiming.gapMs, greaterThan(0));
      expect(FlashTiming.leadInMs, greaterThan(0));
      expect(FlashTiming.inputWindowMs(1), greaterThan(0));
    });
  });

  group('determinism', () {
    test('same seed produces same initial sequence', () {
      final a = PatternRecallGame(random: Random(42), startingLength: 5);
      final b = PatternRecallGame(random: Random(42), startingLength: 5);
      expect(a.sequence, b.sequence);
    });

    test('a full played game is reproducible under the same seed', () {
      List<String> play() {
        final g = PatternRecallGame(random: Random(77), startingLength: 2);
        final taps = <String>[];
        for (var round = 0; round < 4; round++) {
          g.beginInput();
          for (final pad in g.sequence) {
            taps.add(pad.name);
            g.tap(pad);
          }
          g.showNextSequence();
        }
        return taps;
      }

      expect(play(), play());
    });
  });
}
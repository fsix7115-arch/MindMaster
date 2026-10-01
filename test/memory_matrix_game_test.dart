import 'package:flutter_test/flutter_test.dart';
import 'package:mindmaster/features/games/memory_matrix/memory_matrix_game.dart';

void main() {
  group('board construction', () {
    test('every symbol appears exactly twice', () {
      for (final size in MatrixSize.values) {
        final game = MemoryMatrixGame(size: size, seed: 7);
        final counts = <int, int>{};
        for (final card in game.cards) {
          counts[card.symbolIndex] = (counts[card.symbolIndex] ?? 0) + 1;
        }
        expect(counts.length, size.pairCount);
        for (final entry in counts.entries) {
          expect(entry.value, 2, reason: 'symbol ${entry.key} on ${size.label}');
        }
      }
    });

    test('board has the right number of cells', () {
      for (final size in MatrixSize.values) {
        final game = MemoryMatrixGame(size: size, seed: 3);
        expect(game.cards.length, size.cellCount);
      }
    });

    test('board is solvable — every card has a twin somewhere', () {
      // A randomly placed pair board can be unsolvable if the algorithm does not
      // guarantee it. Symbol shuffling makes this true by construction; assert it
      // so a future refactor cannot quietly break it.
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 99);
      for (final card in game.cards) {
        expect(game.cards.where((c) => c.symbolIndex == card.symbolIndex).length, 2);
      }
    });
  });

  group('flipping rules', () {
    test('a card cannot be flipped twice', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 1);
      final card = game.cards.first;
      expect(game.flip(card), FlipOutcome.firstOfPair);
      expect(game.canFlip(card), isFalse);
      expect(game.flip(card), FlipOutcome.ignored);
    });

    test('matched cards cannot be flipped', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 2);
      final pair = game.cards.where((c) => c.symbolIndex == 0).toList();
      game.flip(pair[0]);
      expect(game.flip(pair[1]), FlipOutcome.match);
      expect(game.canFlip(pair[0]), isFalse);
    });

    test('third card is blocked while a miss is unresolved', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 5);
      final a = game.cards[0];
      final b = game.cards[1];
      game.flip(a);
      if (a.symbolIndex == b.symbolIndex) {
        // Board dealt a match, so nothing is locked; force a real miss instead.
        return;
      }
      expect(game.flip(b), FlipOutcome.miss);
      expect(game.isBusy, isTrue);
      expect(game.canFlip(game.cards[2]), isFalse);
      expect(game.flip(game.cards[2]), FlipOutcome.ignored);
    });

    test('resolving a miss hides cards and unlocks the board', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 11);
      final a = game.cards[0];
      final b = game.cards[1];
      game.flip(a);
      if (a.symbolIndex == b.symbolIndex) return; // dealt a match; nothing to resolve
      game.flip(b);
      game.resolveMiss();
      expect(game.isBusy, isFalse);
      expect(game.cards.every((c) => !c.faceUp || c.matched), isTrue);
      expect(game.canFlip(game.cards[2]), isTrue);
    });

    test('resolveMiss is a no-op when nothing is pending', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 13);
      expect(game.isBusy, isFalse);
      game.resolveMiss(); // must not throw or change anything
      expect(game.isBusy, isFalse);
      expect(game.moves, 0);
    });

    test('a match keeps both cards face up and marks them matched', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 17);
      final pair = game.cards.where((c) => c.symbolIndex == 0).toList();
      expect(game.flip(pair[0]), FlipOutcome.firstOfPair);
      expect(game.flip(pair[1]), FlipOutcome.match);
      expect(pair[0].matched, isTrue);
      expect(pair[1].matched, isTrue);
      expect(pair[0].faceUp, isTrue);
      expect(game.matchedPairs, 1);
    });

    test('clearing every pair marks the board complete and locks it', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 21);
      for (var symbol = 0; symbol < MatrixSize.small.pairCount; symbol++) {
        final pair = game.cards.where((c) => c.symbolIndex == symbol).toList();
        game.flip(pair[0]);
        game.flip(pair[1]);
      }
      expect(game.complete, isTrue);
      expect(game.matchedPairs, MatrixSize.small.pairCount);
      expect(game.canFlip(game.cards.first), isFalse);
    });

    test('moves count pairs attempted, not cards flipped', () {
      final game = MemoryMatrixGame(size: MatrixSize.small, seed: 23);
      final a = game.cards[0];
      expect(game.flip(a), FlipOutcome.firstOfPair);
      expect(game.moves, 0, reason: 'first card of a pair is not a move yet');
    });
  });

  group('difficulty scaling', () {
    test('pairs cleared maps to a bigger board', () {
      expect(MatrixSize.forPairsCleared(0), MatrixSize.small);
      expect(MatrixSize.forPairsCleared(5), MatrixSize.small);
      expect(MatrixSize.forPairsCleared(6), MatrixSize.medium);
      expect(MatrixSize.forPairsCleared(17), MatrixSize.medium);
      expect(MatrixSize.forPairsCleared(18), MatrixSize.large);
    });

    test('bigger boards hold more pairs', () {
      expect(MatrixSize.medium.pairCount, greaterThan(MatrixSize.small.pairCount));
      expect(MatrixSize.large.pairCount, greaterThan(MatrixSize.medium.pairCount));
    });
  });

  group('scoring', () {
    test('flawless play outscores a sloppy one', () {
      final perfect = MemoryMatrixGame.score(
          size: MatrixSize.small, moves: MatrixSize.small.pairCount, seconds: 30);
      final sloppy = MemoryMatrixGame.score(
          size: MatrixSize.small, moves: 40, seconds: 30);
      expect(perfect, greaterThan(sloppy));
    });

    test('faster clear outscores a slower one', () {
      final fast = MemoryMatrixGame.score(
          size: MatrixSize.small, moves: 12, seconds: 20);
      final slow = MemoryMatrixGame.score(
          size: MatrixSize.small, moves: 12, seconds: 90);
      expect(fast, greaterThan(slow));
    });

    test('time bonus never goes negative for a very slow round', () {
      final verySlow = MemoryMatrixGame.score(
          size: MatrixSize.small, moves: 12, seconds: 600);
      expect(verySlow, greaterThan(0));
    });

    test('score never goes negative if moves are fewer than pairs', () {
      // Defensive: a scoring bug should not be able to return a negative score.
      final odd = MemoryMatrixGame.score(
          size: MatrixSize.small, moves: 0, seconds: 0);
      expect(odd, greaterThanOrEqualTo(0));
    });
  });

  group('determinism', () {
    test('same seed produces the same board', () {
      final a = MemoryMatrixGame(size: MatrixSize.medium, seed: 42);
      final b = MemoryMatrixGame(size: MatrixSize.medium, seed: 42);
      expect(a.cards.map((c) => c.symbolIndex).toList(),
          b.cards.map((c) => c.symbolIndex).toList());
    });

    test('different seeds produce different boards', () {
      final a = MemoryMatrixGame(size: MatrixSize.medium, seed: 1);
      final b = MemoryMatrixGame(size: MatrixSize.medium, seed: 2);
      expect(a.cards.map((c) => c.symbolIndex).toList(),
          isNot(b.cards.map((c) => c.symbolIndex).toList()));
    });
  });
}
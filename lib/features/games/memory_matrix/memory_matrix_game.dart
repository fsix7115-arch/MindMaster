/// Pure Dart rules for Memory Matrix — a card-matching round.
///
/// Same split as Math Sprint: all rules live here, away from widgets, so they
/// can be unit-tested without a display and reviewed independently of the UI.
library;

import 'dart:math';

/// Grid size and the difficulty tiers that select it.
enum MatrixSize {
  small(4, '4 × 4'),
  medium(6, '6 × 6'),
  large(8, '8 × 8');

  const MatrixSize(this.side, this.label);

  final int side;
  final String label;

  int get cellCount => side * side;

  /// Pairs needed to clear the board.
  int get pairCount => cellCount ~/ 2;

  /// Size for a score. Memory Matrix gets harder as the player gets better, so
  /// the thresholds are tied to how many pairs they cleared.
  static MatrixSize forPairsCleared(int cleared) {
    if (cleared < 6) return small;
    if (cleared < 18) return medium;
    return large;
  }
}

/// One board position: the symbol it shows and whether it is currently face up.
class MemoryCard {
  MemoryCard(this.symbolIndex);

  /// Which of the symbol palette this card displays. Cards share a symbol iff
  /// they are a pair.
  final int symbolIndex;

  bool faceUp = false;
  bool matched = false;

  @override
  String toString() => 'MemoryCard($symbolIndex, up=$faceUp, matched=$matched)';
}

/// Live board state.
class MemoryMatrixGame {
  MemoryMatrixGame({
    this.size = MatrixSize.small,
    int? seed,
    int flipDelayMs = 700,
  })  : _random = Random(seed),
        _flipDelayMs = flipDelayMs {
    _build();
  }

  final MatrixSize size;
  final Random _random;

  /// How long a mismatched pair stays visible before turning back over.
  final int _flipDelayMs;

  late final List<MemoryCard> _cards;
  final List<int> _firstSelected = [];
  int _firstSymbol = -1;
  bool _busy = false;

  int moves = 0;
  int matchedPairs = 0;
  bool complete = false;

  List<MemoryCard> get cards => List.unmodifiable(_cards);

  bool get isBusy => _busy;

  /// Builds a board where every symbol appears exactly twice.
  ///
  /// Shuffles symbols rather than positions, which guarantees a solvable board
  /// by construction — a random placement of pairs can produce an unsolvable
  /// layout, and this game must never deal one.
  void _build() {
    final pool = <int>[];
    for (var i = 0; i < size.pairCount; i++) {
      pool
        ..add(i)
        ..add(i);
    }
    pool.shuffle(_random);
    _cards = [for (final symbol in pool) MemoryCard(symbol)];
  }

  /// Whether a card may be flipped right now.
  bool canFlip(MemoryCard card) =>
      !complete && !_busy && !card.matched && !card.faceUp && _firstSelected.length < 2;

  /// Flips a card. Returns the resulting state so the UI knows whether to keep
  /// the card up or schedule the hide.
  FlipOutcome flip(MemoryCard card) {
    if (!canFlip(card)) return FlipOutcome.ignored;

    card.faceUp = true;
    _firstSelected.add(card.symbolIndex);

    if (_firstSelected.length == 1) {
      _firstSymbol = _firstSelected.first;
      return FlipOutcome.firstOfPair;
    }

    // Second card: a match.
    moves++;
    final matched = _firstSelected.last == _firstSymbol;
    if (matched) {
      matchedPairs++;
      for (final c in _cards) {
        if (c.faceUp && c.symbolIndex == _firstSymbol) c.matched = true;
      }
      if (matchedPairs == size.pairCount) complete = true;
      _resetSelection();
      return FlipOutcome.match;
    }

    // A miss: the board is locked for the flip delay so the player can read
    // both symbols before they disappear.
    _busy = true;
    return FlipOutcome.miss;
  }

  /// Hides the two cards from a miss. Called by the UI after [flipDelayMs].
  void resolveMiss() {
    if (!_busy) return;
    for (final c in _cards) {
      if (!c.matched) c.faceUp = false;
    }
    _resetSelection();
    _busy = false;
  }

  void _resetSelection() {
    _firstSelected.clear();
    _firstSymbol = -1;
  }

  int get flipDelayMs => _flipDelayMs;

  /// Final score. Fewer moves for the same board scores higher, and a fast
  /// clear is rewarded separately so the player has two things to improve.
  static int score({required MatrixSize size, required int moves, required int seconds}) {
    // Perfect play needs exactly one move per pair.
    final perfect = size.pairCount;

    // Guard the divisor. moves == 0 (or negative) makes efficiency infinite,
    // which crashes on .round(). Clamping to at least 1 also stops a scoring
    // bug from ever producing Infinity or NaN that reaches the UI.
    final safeMoves = moves < 1 ? 1 : moves;
    final efficiency = perfect / safeMoves;         // 1.0 == flawless
    final timeBonus = max(0, 60 - seconds) / 60;   // 1.0 == under a minute
    final raw = efficiency * 1000 + timeBonus * 500;

    // Belt and braces: a scoring path that can emit Infinity/NaN will crash the
    // app mid-round, which is far worse than a slightly wrong number.
    if (raw.isNaN || raw.isInfinite) return 0;
    return raw.round();
  }
}

/// What [MemoryMatrixGame.flip] did, so the caller knows which animation to run.
enum FlipOutcome {
  /// Card is now the first of a possible pair; nothing else to do.
  firstOfPair,

  /// Second card matched the first; both stay face up and become inert.
  match,

  /// Second card did not match; schedule [MemoryMatrixGame.resolveMiss].
  miss,

  /// The card was not flippable (already up, matched, or board busy).
  ignored,
}
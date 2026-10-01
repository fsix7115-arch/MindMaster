/// Pure Dart rules for Pattern Recall — a Simon-style sequence game.
///
/// Same split as the other games: rules live here, away from widgets, so they
/// can be unit-tested without a display.
///
/// Design decisions worth knowing:
///   - The sequence grows by exactly one step per round. Difficulty comes from
///     length, not from shrinking the input window.
///   - Flash timing is expressed in milliseconds and lives here so the UI never
///     invents its own timings — a mismatch between flash and validation is the
///     classic way this game feels broken.
///   - The sequence is regenerated every game rather than persisted, so a player
///     cannot memorise one fixed pattern across sessions.
library;

import 'dart:math';

/// Which quadrant of the pad a step belongs to.
enum PadColor { red, green, blue, yellow }

/// Timings in milliseconds. Kept as constants because the UI and the game
/// logic must agree exactly, or the game feels unresponsive.
class FlashTiming {
  const FlashTiming._();

  /// How long a pad stays lit during playback.
  static const int onMs = 380;

  /// Gap between two pads lighting up.
  static const int gapMs = 190;

  /// Delay before playback starts, so the player is ready.
  static const int leadInMs = 700;

  /// How long the player has to tap the whole sequence back before it is
  /// considered failed. Scales with sequence length.
  static int inputWindowMs(int sequenceLength) =>
      900 + (sequenceLength * 850);
}

/// Live state of one Pattern Recall round.
class PatternRecallGame {
  PatternRecallGame({Random? random, int startingLength = 1})
      : _random = random ?? Random() {
    // Start with a sequence of [startingLength] steps so the first round is not
    // a single tap, which teaches nothing.
    for (var i = 0; i < startingLength; i++) {
      _sequence.add(_randomPad());
    }
    _inputIndex = 0;
    _bestLength = 0;
  }

  final Random _random;

  late final List<PadColor> _sequence = [];
  late int _inputIndex = 0;

  /// Longest run of steps the player ever repeated correctly in one round.
  int _bestLength = 0;

  bool _playing = true; // true = showing the sequence, false = waiting for input
  bool _failed = false;
  int _round = 1;

  /// The sequence the player must repeat. Exposed read-only.
  List<PadColor> get sequence => List.unmodifiable(_sequence);

  /// Length of the sequence this round.
  int get length => _sequence.length;

  int get round => _round;

  bool get isShowingSequence => _playing;

  bool get isAwaitingInput => !_playing && !_failed;

  bool get failed => _failed;

  /// Best round reached this session, for the HUD.
  int get currentLength => _sequence.length;

  PadColor _randomPad() => PadColor.values[_random.nextInt(PadColor.values.length)];

  /// Called when playback finishes; the game now waits for the player.
  void beginInput() {
    _playing = false;
    _inputIndex = 0;
  }

  /// Registers a tap.
  ///
  /// Returns what the UI should do:
  ///   [TapResult.accepted] — correct so far, keep going
  ///   [TapResult.roundComplete] — the whole sequence was correct
  ///   [TapResult.failed] — wrong pad, game over
  ///   [TapResult.ignored] — tapped while not awaiting input
  TapResult tap(PadColor pad) {
    if (_failed || _playing) return TapResult.ignored;

    if (_inputIndex >= _sequence.length) return TapResult.ignored;

    if (_sequence[_inputIndex] != pad) {
      _failed = true;
      return TapResult.failed;
    }

    _inputIndex++;
    if (_inputIndex > _bestLength) _bestLength = _inputIndex;
    if (_inputIndex == _sequence.length) {
      // Round cleared. Extend the sequence and go back to playback.
      _round++;
      _sequence.add(_randomPad());
      return TapResult.roundComplete;
    }
    return TapResult.accepted;
  }

  /// Begins showing the extended sequence for the next round.
  void showNextSequence() {
    _playing = true;
    _inputIndex = 0;
  }

  /// Milliseconds to wait before the next step of playback.
  int get stepIntervalMs => FlashTiming.onMs + FlashTiming.gapMs;

  /// Longest sequence the player fully repeated this session.
  int get bestLength => _bestLength;
}

/// What a tap did.
enum TapResult {
  /// Correct, and the sequence is not finished.
  accepted,

  /// Correct, and the whole sequence was repeated. Next round starts.
  roundComplete,

  /// Wrong pad. Game over.
  failed,

  /// Tapped at the wrong time (during playback, or after the game ended).
  ignored,
}
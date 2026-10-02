// Pattern Recall — Simon-style sequence memory.
//
// Pads light up in a sequence; watch, then repeat it.
// The sequence grows by one each round. Wrong pad ends
// the run (hard) or costs a life (easy/medium).
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine.dart';

class PatternRecallGame extends Game {
  @override
  final String id = 'pattern_recall';
  @override
  final String title = 'Pattern Recall';
  @override
  final String icon = '💫';
  @override
  final String description = 'Simon Says style game on a 3D pad';

  Difficulty difficulty = Difficulty.medium;

  static const int padCount = 4;

  late List<int> _sequence;
  int _playerIndex = 0;
  int _round = 0;
  int _score = 0;
  int _correct = 0;
  int _errors = 0;
  int _lives = 3;
  bool _finished = false;
  bool _active = false;
  bool _showingSequence = false;
  int _currentlyLit = -1;
  final _rng = Random();
  Timer? _playbackTimer;

  List<int> get sequence => [..._sequence];
  int get round => _round;
  int get lives => _lives;
  int get currentlyLit => _currentlyLit;
  bool get showingSequence => _showingSequence;

  /// Whether the player may tap a pad right now (not during playback).
  bool get isTapAllowed => _active && !_finished && !_showingSequence;

  @override
  void init() {
    _setup();
  }

  void _setup() {
    _sequence = [];
    _playerIndex = 0;
    _round = 0;
    _score = 0;
    _correct = 0;
    _errors = 0;
    _lives = switch (difficulty) {
      Difficulty.easy => 3,
      Difficulty.medium => 2,
      Difficulty.hard => 1,
    };
    _finished = false;
    _active = false;
    _showingSequence = false;
    _currentlyLit = -1;
  }

  @override
  void start() {
    _active = true;
    _nextRound();
  }

  void _nextRound() {
    _round++;
    _sequence.add(_rng.nextInt(padCount));
    _playbackSequence();
  }

  /// Play the sequence to the user, then hand control over.
  void _playbackSequence() {
    _showingSequence = true;
    _playerIndex = 0;
    final playbackSpeed = _playbackDelay;
    var i = 0;
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(playbackSpeed, (timer) {
      if (i >= _sequence.length) {
        timer.cancel();
        _showingSequence = false;
        _currentlyLit = -1;
        return;
      }
      _currentlyLit = _sequence[i];
      i++;
    });
  }

  Duration get _playbackDelay {
    // Faster on higher rounds and difficulties.
    final base = switch (difficulty) {
      Difficulty.easy => 600,
      Difficulty.medium => 500,
      Difficulty.hard => 400,
    };
    final roundPenalty = _round * 15;
    return Duration(milliseconds: (base - roundPenalty).clamp(220, 600));
  }

  /// Player taps pad [pad]. Returns true if it continues
  /// the sequence correctly.
  bool tap(int pad) {
    if (!_active || _finished || _showingSequence) return false;
    if (pad == _sequence[_playerIndex]) {
      _playerIndex++;
      if (_playerIndex >= _sequence.length) {
        // Round complete.
        _correct++;
        _score += 10 * _round;
        _nextRound();
      }
      return true;
    } else {
      _errors++;
      _lives--;
      if (_lives <= 0) {
        endGame();
      } else {
        // Replay the same sequence so the player can retry.
        _playbackSequence();
      }
      return false;
    }
  }

  void endGame() {
    if (_finished) return;
    _finished = true;
    _active = false;
    _playbackTimer?.cancel();
    _currentlyLit = -1;
  }

  @override
  int get score => _score;

  @override
  int get totalSteps => _correct + _errors;

  @override
  int get correctSteps => _correct;

  @override
  int get errorCount => _errors;

  @override
  bool get finished => _finished;

  @override
  String get summary =>
      'round $_round · $_lives lives left · sequence length ${_sequence.length}';

  @override
  void reset() {
    _playbackTimer?.cancel();
    _setup();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
  }
}

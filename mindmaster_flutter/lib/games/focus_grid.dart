// Focus Grid — tap the numbers 1..N in order.
//
// A shuffled grid of numbered tiles; the player must
// tap them in ascending order as fast as possible.
// Speed bonus: finishing quickly adds to the score.
import 'dart:async';

import 'package:flutter/material.dart';

import '../engine.dart';

class FocusGridGame extends Game {
  @override
  final String id = 'focus_grid';
  @override
  final String title = 'Focus Grid';
  @override
  final String icon = '🎯';
  @override
  final String description = 'Tap 1-N in order. How fast can you go?';

  Difficulty difficulty = Difficulty.medium;

  late int gridSize;
  late int totalTiles;
  late List<int> _tiles;
  int _nextExpected = 1;
  int _score = 0;
  int _correct = 0;
  int _errors = 0;
  bool _finished = false;
  bool _active = false;
  late Stopwatch _stopwatch;

  List<int> get tiles => [..._tiles];
  int get nextExpected => _nextExpected;
  int get progress => _correct;

  int get secondsElapsed => _stopwatch.elapsed.inSeconds;

  @override
  void init() {
    _setup();
  }

  void _setup() {
    gridSize = switch (difficulty) {
      Difficulty.easy => 4,
      Difficulty.medium => 5,
      Difficulty.hard => 6,
    };
    totalTiles = gridSize * gridSize;
    _tiles = List.generate(totalTiles, (i) => i + 1);
    _tiles.shuffle();
    _nextExpected = 1;
    _score = 0;
    _correct = 0;
    _errors = 0;
    _finished = false;
    _active = false;
    _stopwatch = Stopwatch();
  }

  @override
  void start() {
    _active = true;
    _stopwatch.start();
  }

  /// Tap tile with value `value`. Correct iff it is the
  /// next expected number.
  bool tap(int value) {
    if (!_active || _finished) return false;
    if (value == _nextExpected) {
      _correct++;
      _nextExpected++;
      if (_nextExpected > totalTiles) {
        endGame();
      }
      return true;
    } else {
      _errors++;
      return false;
    }
  }

  void endGame() {
    if (_finished) return;
    _finished = true;
    _active = false;
    _stopwatch.stop();

    // Speed bonus: faster = more points.
    final elapsed = _stopwatch.elapsed.inMilliseconds;
    final base = totalTiles * 10;
    final par = totalTiles * 900; // ~0.9s per tile
    if (elapsed < par) {
      final bonus = ((par - elapsed) / par * base).round();
      _score = base + bonus;
    } else {
      _score = base;
    }
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
      '$_correct/$totalTiles in ${_stopwatch.elapsed.inSeconds}s';

  @override
  void reset() => _setup();
}

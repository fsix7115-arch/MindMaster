// Color Match — Stroop test.
//
// A word is shown in a colored ink. Tap the COLOR of
// the ink, not the word itself. On hard mode the word
// and the ink disagree almost always.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine.dart';

class ColorMatchGame extends Game {
  static const int rounds = 20;

  @override
  final String id = 'color_match';
  @override
  final String title = 'Color Match';
  @override
  final String icon = '🎨';
  @override
  final String description = 'Stroop test. Tap the COLOR, not the word!';

  Difficulty difficulty = Difficulty.medium;

  static const _palette = <String, Color>{
    'RED': Color(0xFFFF2A6D),
    'BLUE': Color(0xFF00F3FF),
    'GREEN': Color(0xFF00FF9D),
    'YELLOW': Color(0xFFFFAA00),
    'PURPLE': Color(0xFFBC13FE),
    'ORANGE': Color(0xFFFF6B35),
    'PINK': Color(0xFFFF7EB6),
    'CYAN': Color(0xFF00E5FF),
  };

  late List<String> _activeColors;
  String? _word;
  Color? _inkColor;
  String? _inkName;
  int _round = 0;
  int _score = 0;
  int _correct = 0;
  int _errors = 0;
  bool _finished = false;
  bool _active = false;
  final _rng = Random();

  List<String> get choices => [..._activeColors];
  String? get word => _word;
  Color? get inkColor => _inkColor;
  int get round => _round;

  @override
  void init() {
    _setup();
  }

  void _setup() {
    _activeColors = switch (difficulty) {
      Difficulty.easy => _palette.keys.take(4).toList(),
      Difficulty.medium => _palette.keys.take(6).toList(),
      Difficulty.hard => _palette.keys.take(8).toList(),
    };
    _round = 0;
    _score = 0;
    _correct = 0;
    _errors = 0;
    _finished = false;
    _active = false;
    _word = null;
    _inkColor = null;
    _inkName = null;
  }

  @override
  void start() {
    _active = true;
    _nextRound();
  }

  void _nextRound() {
    if (_round >= rounds) {
      endGame();
      return;
    }
    _round++;

    // Pick the ink color, then the word.
    _inkName = _activeColors[_rng.nextInt(_activeColors.length)];
    _inkColor = _palette[_inkName];

    final agree = _shouldAgree();
    if (agree) {
      _word = _inkName;
    } else {
      // Word must differ from the ink.
      final others =
          _activeColors.where((c) => c != _inkName).toList();
      _word = others[_rng.nextInt(others.length)];
    }
  }

  bool _shouldAgree() {
    // Probability the word matches the ink:
    // easy mostly agrees, hard mostly disagrees.
    final agreeP = switch (difficulty) {
      Difficulty.easy => 0.7,
      Difficulty.medium => 0.4,
      Difficulty.hard => 0.2,
    };
    return _rng.nextDouble() < agreeP;
  }

  /// Tap a color name. Correct iff it equals the INK color.
  bool answer(String colorName) {
    if (!_active || _finished) return false;
    if (colorName == _inkName) {
      _correct++;
      _score += 10 + (difficulty == Difficulty.hard ? 10 : 0);
    } else {
      _errors++;
    }
    _nextRound();
    return colorName == _inkName;
  }

  void endGame() {
    _finished = true;
    _active = false;
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
  String get summary => '$_correct/$_round correct';

  @override
  void reset() => _setup();
}

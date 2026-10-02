// Math Sprint — 60 seconds of speed math.
//
// Gameplay: 20 questions per round. +, -, ×, ÷ with
// integer-only results (no fractions). Streak bonus:
// every 3 consecutive correct answers adds a multiplier.
//
// Difficulty scales the operand ranges:
//   easy   — 1..20, ÷ results 1..10
//   medium — 1..50, ÷ results 1..20
//   hard   — 1..99, × up to 12×12, ÷ results 1..20
import 'dart:async';

import 'package:flutter/material.dart';

import '../engine.dart';

class MathSprintGame extends Game {
  static const int questionCount = 20;

  @override
  final String id = 'math_sprint';
  @override
  final String title = 'Math Sprint';
  @override
  final String icon = '🔢';
  @override
  final String description = '60 seconds of speed math. +, −, ×, ÷';

  Difficulty difficulty = Difficulty.medium;

  Timer? _timer;
  int _secondsLeft = 60;
  int _secondsUsed = 0;

  _Question? _current;
  final List<_Question> _history = [];

  int _score = 0;
  int _correct = 0;
  int _answered = 0;
  int _errors = 0;
  int _streak = 0;
  bool _finished = false;
  bool _active = false;

  @override
  void init() {
    reset();
  }

  @override
  void start() {
    if (_active) return;
    _active = true;
    _finished = false;
    _secondsLeft = 60;
    _secondsUsed = 0;
    _newQuestion();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _secondsLeft--;
      _secondsUsed++;
      if (_secondsLeft <= 0) {
        endGame();
      }
    });
  }

  @override
  int get score => _score;

  @override
  int get totalSteps => _answered;
  @override
  int get correctSteps => _correct;
  @override
  int get errorCount => _errors;

  @override
  bool get finished => _finished;

  @override
  String get summary =>
      '$_correct/$_answered correct · best streak $_streak';

  _Question? get current => _current;
  int get secondsLeft => _secondsLeft;
  int get streak => _streak;

  void answer(int value) {
    if (!_active || _finished || _current == null) return;
    _answered++;
    if (value == _current!.answer) {
      _correct++;
      _streak++;
      final streakBonus = _streak ~/ 3;
      _score += 10 + streakBonus * 5;
    } else {
      _errors++;
      _streak = 0;
    }
    if (_answered >= questionCount) {
      endGame();
    } else {
      _newQuestion();
    }
  }

  void _newQuestion() {
    _current = _generate();
    _history.add(_current!);
  }

  _Question _generate() {
    // Weighted operation mix; division always yields integers.
    const ops = ['+', '-', '×', '÷'];
    final op = ops[Engine.instance.rand(0, ops.length - 1)];
    int a, b, answer;

    switch (difficulty) {
      case Difficulty.easy:
        switch (op) {
          case '+':
            a = Engine.instance.rand(1, 20);
            b = Engine.instance.rand(1, 20);
            answer = a + b;
          case '-':
            a = Engine.instance.rand(1, 20);
            b = Engine.instance.rand(1, a);
            answer = a - b;
          case '×':
            a = Engine.instance.rand(2, 9);
            b = Engine.instance.rand(2, 9);
            answer = a * b;
          default: // ÷
            b = Engine.instance.rand(2, 9);
            answer = Engine.instance.rand(2, 10);
            a = b * answer;
        }
      case Difficulty.medium:
        switch (op) {
          case '+':
            a = Engine.instance.rand(1, 50);
            b = Engine.instance.rand(1, 50);
            answer = a + b;
          case '-':
            a = Engine.instance.rand(1, 50);
            b = Engine.instance.rand(1, a);
            answer = a - b;
          case '×':
            a = Engine.instance.rand(2, 12);
            b = Engine.instance.rand(2, 12);
            answer = a * b;
          default: // ÷
            b = Engine.instance.rand(2, 12);
            answer = Engine.instance.rand(2, 20);
            a = b * answer;
        }
      case Difficulty.hard:
        switch (op) {
          case '+':
            a = Engine.instance.rand(10, 99);
            b = Engine.instance.rand(10, 99);
            answer = a + b;
          case '-':
            a = Engine.instance.rand(10, 99);
            b = Engine.instance.rand(1, a);
            answer = a - b;
          case '×':
            a = Engine.instance.rand(2, 12);
            b = Engine.instance.rand(2, 12);
            answer = a * b;
          default: // ÷
            b = Engine.instance.rand(3, 12);
            answer = Engine.instance.rand(2, 20);
            a = b * answer;
        }
    }

    // Build 4 options: correct + 3 realistic distractors.
    final options = <int>{answer};
    final deltas = <int>[-1, 1, -2, 2, -10, 10, -5, 5];
    while (options.length < 4) {
      final d = deltas[Engine.instance.rand(0, deltas.length - 1)];
      final cand = answer + d;
      if (cand >= 0 && !options.contains(cand)) options.add(cand);
    }
    return _Question('$a $op $b', answer, Engine.instance.shuffled(options.toList()));
  }

  void endGame() {
    if (_finished) return;
    _finished = true;
    _active = false;
    _timer?.cancel();
  }

  @override
  void reset() {
    _timer?.cancel();
    _current = null;
    _history.clear();
    _score = 0;
    _correct = 0;
    _answered = 0;
    _errors = 0;
    _streak = 0;
    _finished = false;
    _active = false;
    _secondsLeft = 60;
    _secondsUsed = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
  }
}

class _Question {
  final String display;
  final int answer;
  final List<int> options;

  _Question(this.display, this.answer, this.options);
}
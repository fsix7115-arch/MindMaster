// Memory Matrix — pair matching on a grid.
//
// Flip two cards per turn; matched pairs stay face up.
// Score rewards fewer moves and faster completion.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine.dart';

class MemoryMatrixGame extends Game {
  @override
  final String id = 'memory_matrix';
  @override
  final String title = 'Memory Matrix';
  @override
  final String icon = '🧠';
  @override
  final String description = 'Pair matching on 4×4 / 6×6 / 8×8 boards';

  Difficulty difficulty = Difficulty.medium;

  late int gridSize;
  late int pairCount;
  late List<MemoryCard> _cards;
  int? _firstIndex;
  int _moves = 0;
  int _score = 0;
  int _matchedPairs = 0;
  int _correctSteps = 0;
  int _errors = 0;
  bool _finished = false;
  bool _active = false;
  bool _locked = false; // board lock during a mismatch reveal
  final _rng = Random();

  List<MemoryCard> get cards => [..._cards];
  int get moves => _moves;
  int get matchedPairs => _matchedPairs;

  @override
  void init() {
    _setup();
  }

  void _setup() {
    gridSize = switch (difficulty) {
      Difficulty.easy => 4,
      Difficulty.medium => 6,
      Difficulty.hard => 8,
    };
    pairCount = (gridSize * gridSize) ~/ 2;
    _cards = _buildDeck();
    _firstIndex = null;
    _moves = 0;
    _score = 0;
    _matchedPairs = 0;
    _correctSteps = 0;
    _errors = 0;
    _finished = false;
    _active = false;
    _locked = false;
  }

  @override
  void start() {
    _active = true;
  }

  List<MemoryCard> _buildDeck() {
    final symbols = List.generate(pairCount, (i) => _symbols[i % _symbols.length]);
    final deck = <int>[];
    for (final s in symbols) {
      deck.add(s);
      deck.add(s);
    }
    deck.shuffle(_rng);
    return deck.map((s) => MemoryCard(symbol: s)).toList();
  }

  static const _symbols = <int>[
    0x1F600, 0x1F603, 0x1F604, 0x1F601, // 😀 😃 😄 😁
    0x1F606, 0x1F605, 0x1F602, 0x1F923, // 😆 😅 😂 🤣
    0x1F60A, 0x1F607, 0x1F642, 0x1F643, // 😊 😇 🙂 😃
    0x1F609, 0x1F60C, 0x1F60D, 0x1F618, // 😉 😌 😍 😘
    0x1F917, 0x1F913, 0x1F60E, 0x1F921, // 🤗 🤓 😎 🤡
    0x1F973, 0x1F978, 0x1F929, 0x1F92D, // 🥳 🥸 🤩 🤭
    0x1F621, 0x1F624, 0x1F620, 0x1F627, // 😡 😤 😠 😧
    0x1F628, 0x1F630, 0x1F625, 0x1F613, // 😨 😰 😥 😓
    0x1F4A3, 0x1F4A5, 0x1F4AB, 0x1F4A8, // 💣 💥 💫 💨
    0x1F31F, 0x1F308, 0x1F525, 0x1F389, // 🌟 🌈 🔥 🎉
    0x1F4AF, 0x1F3C6, 0x1F31E, 0x1F680, // 💯 🏆 🎞 🚀
    0x1F34E, 0x1F350, 0x1F351, 0x1F352, // 🍎 🍐 👑 🍒
    0x1F353, 0x1F354, 0x1F355, 0x1F356, // 🍓 🍔 🍕 🍖
    0x1F357, 0x1F358, 0x1F359, 0x1F35A, // 🍗 🍘 🍙 🍚
    0x1F35B, 0x1F35C, 0x1F35D, 0x1F35E, // 🍛 🍜 🍝 🍞
    0x1F360, 0x1F361, 0x1F362, 0x1F363, // 🍠 🍡 🍢 🍣
    0x1F364, 0x1F365, 0x1F366, 0x1F367, // 🍤 🍥 🍦 🍧
    0x1F368, 0x1F369, 0x1F36A, 0x1F36B, // 🍨 🍩 🍪 🍫
    0x1F36C, 0x1F36D, 0x1F36E, 0x1F36F, // 🍬 🍭 🍮 🍯
    0x1F370, 0x1F371, 0x1F372, 0x1F373, // 🍰 🍱 🍲 🍳
    0x1F374, 0x1F375, 0x1F376, 0x1F377, // 🍴 🍵 🍶 🍷
    0x1F378, 0x1F379, 0x1F37A, 0x1F37B, // 🍸 🍹 🍺 🍻
    0x1F37C, 0x1F37D, 0x1F37E, 0x1F37F, // 🍼 🍽 🍾 🍿
    0x1F380, 0x1F381, 0x1F382, 0x1F383, // 🎀 🎁 🎂 🎃
    0x1F384, 0x1F385, 0x1F386, 0x1F387, // 🎄 🎅 🎆 🎇
    0x1F388, 0x1F389, 0x1F38A, 0x1F38B, // 🎈 🎉 🎊 🎋
    0x1F38C, 0x1F38D, 0x1F38E, 0x1F38F, // 🎌 🎍 🎎 🎏
    0x1F390, 0x1F391, 0x1F392, 0x1F393, // 🎐 🎑 🎒 🎓
  ];

  /// Flip card at [index]. Returns the result of the move.
  MemoryFlip flip(int index) {
    if (!_active || _finished || _locked) {
      return MemoryFlip.noop();
    }
    final card = _cards[index];
    if (card.matched || card.faceUp) {
      return MemoryFlip.noop();
    }

    card.faceUp = true;

    if (_firstIndex == null) {
      _firstIndex = index;
      return MemoryFlip.first(index);
    }

    // Second card — evaluate the pair.
    _moves++;
    final first = _cards[_firstIndex!];
    if (first.symbol == card.symbol) {
      first.matched = true;
      card.matched = true;
      _matchedPairs++;
      _correctSteps++;
      _score += 20 + (difficulty == Difficulty.hard ? 15 : 0);
      _firstIndex = null;
      if (_matchedPairs >= pairCount) {
        endGame();
      }
      return MemoryFlip.match(_firstIndex ?? index, index);
    } else {
      _errors++;
      _locked = true;
      final a = _firstIndex!;
      final b = index;
      _firstIndex = null;
      // Brief reveal, then flip both back.
      Timer(const Duration(milliseconds: 700), () {
        _cards[a].faceUp = false;
        _cards[b].faceUp = false;
        _locked = false;
      });
      return MemoryFlip.mismatch(a, b);
    }
  }

  void endGame() {
    _finished = true;
    _active = false;
    // Fewer-moves bonus: perfect memory = max score.
    final perfect = pairCount;
    final efficiency = (perfect / _moves).clamp(0.0, 1.0);
    _score += (efficiency * 100).round();
  }

  @override
  int get score => _score;

  @override
  int get totalSteps => _correctSteps + _errors;

  @override
  int get correctSteps => _matchedPairs;

  @override
  int get errorCount => _errors;

  @override
  bool get finished => _finished;

  @override
  String get summary =>
      '$_matchedPairs/$pairCount pairs in $_moves moves';

  @override
  void reset() => _setup();
}

class MemoryCard {
  final int symbol;
  bool faceUp = false;
  bool matched = false;

  MemoryCard({required this.symbol});
}

class MemoryFlip {
  final MemoryFlipType type;
  final int first;
  final int second;

  MemoryFlip._(this.type, this.first, this.second);

  factory MemoryFlip.first(int index) =>
      MemoryFlip._(MemoryFlipType.first, index, -1);

  factory MemoryFlip.match(int a, int b) =>
      MemoryFlip._(MemoryFlipType.match, a, b);

  factory MemoryFlip.mismatch(int a, int b) =>
      MemoryFlip._(MemoryFlipType.mismatch, a, b);

  factory MemoryFlip.noop() =>
      MemoryFlip._(MemoryFlipType.noop, -1, -1);
}

enum MemoryFlipType { first, match, mismatch, noop }

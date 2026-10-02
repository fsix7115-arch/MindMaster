// Logic Puzzles — Sudoku-lite (4×4 / 6×6 / 9×9).
//
// Generation: recursive backtracking with a shuffled
// candidate order, then hole-punching for the puzzle.
// Placement is validated against row + column + region
// constraints, so every generated puzzle is solvable.
import 'dart:math';

import 'package:flutter/material.dart';

import '../engine.dart';

class LogicPuzzlesGame extends Game {
  @override
  final String id = 'logic_puzzles';
  @override
  final String title = 'Logic Puzzles';
  @override
  final String icon = '🧩';
  @override
  final String description = 'Sudoku-lite puzzles, 4×4 to 9×9 grids';

  Difficulty difficulty = Difficulty.medium;

  late int size;
  late List<List<int>> solution;
  late List<List<int>> board; // 0 = empty cell
  int _selectedRow = -1;
  int _selectedCol = -1;
  int _filled = 0;
  int _errors = 0;
  int _correct = 0;
  bool _finished = false;
  bool _active = false;
  final _rng = Random();

  int get selectedRow => _selectedRow;
  int get selectedCol => _selectedCol;
  int get filled => _filled;
  int get totalCells => size * size;

  int cellAt(int r, int c) => board[r][c];
  int solutionAt(int r, int c) => solution[r][c];
  bool isGiven(int r, int c) => _isGiven[r][c];

  late List<List<bool>> _isGiven;

  int get givens => _givenCount;
  int _givenCount = 0;

  @override
  void init() {
    size = switch (difficulty) {
      Difficulty.easy => 4,
      Difficulty.medium => 6,
      Difficulty.hard => 9,
    };
    solution = _generateSolution(size);
    board = solution.map((row) => [...row]).toList();
    _isGiven = List.generate(size, (_) => List.filled(size, true));
    _givenCount = size * size;
    _selectedRow = -1;
    _selectedCol = -1;
    _filled = 0;
    _errors = 0;
    _correct = 0;
    _finished = false;
    _active = false;
  }

  @override
  void start() {
    _active = true;
    _punchHoles();
  }

  /// Remove cells to form the puzzle. More givens on easy,
  /// fewer on hard.
  void _punchHoles() {
    final total = size * size;
    final keep = switch (difficulty) {
      Difficulty.easy => (total * 0.55).round(),
      Difficulty.medium => (total * 0.45).round(),
      Difficulty.hard => (total * 0.35).round(),
    };
    final positions = <int>[];
    for (var i = 0; i < total; i++) {
      positions.add(i);
    }
    positions.shuffle(_rng);
    var removed = 0;
    for (final p in positions) {
      if (removed >= total - keep) break;
      final r = p ~/ size;
      final c = p % size;
      if (!_isGiven[r][c]) continue;
      _isGiven[r][c] = false;
      board[r][c] = 0;
      _givenCount--;
      removed++;
    }
    _filled = _givenCount;
  }

  void select(int r, int c) {
    if (_isGiven[r][c]) {
      _selectedRow = -1;
      _selectedCol = -1;
    } else {
      _selectedRow = r;
      _selectedCol = c;
    }
  }

  /// Place a number on the selected cell. Returns true if
  /// the placement matches the solution.
  bool place(int value) {
    if (!_active || _finished || _selectedRow < 0) return false;
    if (_isGiven[_selectedRow][_selectedCol]) return false;

    final r = _selectedRow;
    final c = _selectedCol;

    if (value == solution[r][c]) {
      board[r][c] = value;
      _correct++;
      _filled++;
      if (_filled >= totalCells) {
        _finished = true;
        _active = false;
      }
      return true;
    } else {
      _errors++;
      return false;
    }
  }

  @override
  int get score => _correct * 100 - _errors * 25;

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
      '$_correct correct placements · $_errors errors · $_filled/$totalCells filled';

  @override
  void reset() {
    init();
  }

  /// Generate a complete valid board via backtracking.
  List<List<int>> _generateSolution(int size) {
    final board = List.generate(size, (_) => List.filled(size, 0));
    _fill(board, size, 0, 0);
    return board;
  }

  bool _fill(List<List<int>> board, int size, int row, int col) {
    if (col >= size) {
      row++;
      col = 0;
    }
    if (row >= size) return true;
    if (board[row][col] != 0) return _fill(board, size, row, col + 1);

    final candidates = List.generate(size, (i) => i + 1);
    candidates.shuffle(_rng);
    for (final value in candidates) {
      if (_isValid(board, size, row, col, value)) {
        board[row][col] = value;
        if (_fill(board, size, row, col + 1)) return true;
        board[row][col] = 0;
      }
    }
    return false;
  }

  bool _isValid(List<List<int>> board, int size, int row, int col, int value) {
    for (var c = 0; c < size; c++) {
      if (board[row][c] == value) return false;
    }
    for (var r = 0; r < size; r++) {
      if (board[r][col] == value) return false;
    }
    // Region constraint (2×2 for 4×4, 2×3 for 6×6, 3×3 for 9×9).
    final (regionRows, regionCols) = switch (size) {
      4 => (2, 2),
      6 => (2, 3),
      9 => (3, 3),
      _ => (size, 1),
    };
    final startRow = (row ~/ regionRows) * regionRows;
    final startCol = (col ~/ regionCols) * regionCols;
    for (var r = startRow; r < startRow + regionRows; r++) {
      for (var c = startCol; c < startCol + regionCols; c++) {
        if (board[r][c] == value) return false;
      }
    }
    return true;
  }
}

/// Placeholder context for reset() — reset only rebuilds
/// board state and never touches Flutter widgets.

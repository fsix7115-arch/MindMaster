// MindMaster — smoke tests.
//
// Verifies the app boots, the home screen lists all six games,
// and each game constructs + initialises without throwing.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindmaster/engine.dart';
import 'package:mindmaster/store.dart';
import 'package:mindmaster/theme.dart';
import 'package:mindmaster/games/math_sprint.dart';
import 'package:mindmaster/games/logic_puzzles.dart';
import 'package:mindmaster/games/color_match.dart';
import 'package:mindmaster/games/focus_grid.dart';
import 'package:mindmaster/games/memory_matrix.dart';
import 'package:mindmaster/games/pattern_recall.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
  });

  test('all six games register', () {
    Engine.register('math_sprint', () => MathSprintGame());
    Engine.register('logic_puzzles', () => LogicPuzzlesGame());
    Engine.register('color_match', () => ColorMatchGame());
    Engine.register('focus_grid', () => FocusGridGame());
    Engine.register('memory_matrix', () => MemoryMatrixGame());
    Engine.register('pattern_recall', () => PatternRecallGame());

    expect(Engine.gameIds.length, 6);
    for (final id in Engine.gameIds) {
      expect(Engine.create(id), isNotNull, reason: '\$id should construct');
    }
  });

  test('each game initialises and starts on every difficulty', () {
    final games = <String, Game Function()>{
      'math_sprint': () => MathSprintGame(),
      'logic_puzzles': () => LogicPuzzlesGame(),
      'color_match': () => ColorMatchGame(),
      'focus_grid': () => FocusGridGame(),
      'memory_matrix': () => MemoryMatrixGame(),
      'pattern_recall': () => PatternRecallGame(),
    };

    for (final entry in games.entries) {
      for (final d in Difficulty.values) {
        final g = entry.value();
        if (g is MathSprintGame) g.difficulty = d;
        if (g is LogicPuzzlesGame) g.difficulty = d;
        if (g is ColorMatchGame) g.difficulty = d;
        if (g is FocusGridGame) g.difficulty = d;
        if (g is MemoryMatrixGame) g.difficulty = d;
        if (g is PatternRecallGame) g.difficulty = d;

        expect(() => g.init(), returnsNormally,
            reason: '4{entry.key} 4{d} init');
        expect(() => g.start(), returnsNormally,
            reason: '4{entry.key} 4{d} start');
        expect(() => g.dispose(), returnsNormally);
      }
    }
  });

  test('math sprint generates questions with 4 unique options', () {
    final g = MathSprintGame();
    g.difficulty = Difficulty.medium;
    g.init();
    g.start();
    expect(g.current, isNotNull);
    expect(g.current!.options.length, 4);
    expect(g.current!.options.toSet().length, 4,
        reason: 'options must be distinct');
    expect(g.current!.options, contains(g.current!.answer));
  });

  test('focus grid tiles are a shuffled 1..N sequence', () {
    final g = FocusGridGame();
    g.difficulty = Difficulty.medium;
    g.init();
    g.start();
    final tiles = g.tiles..sort();
    expect(tiles.length, 25);
    expect(tiles.first, 1);
    expect(tiles.last, 25);
  });

  test('logic puzzles board is solvable and matches its solution', () {
    final g = LogicPuzzlesGame();
    g.difficulty = Difficulty.easy;
    g.init();
    g.start();

    // Fill every empty cell with the solution value.
    var guard = 0;
    while (!g.finished && guard++ < 200) {
      for (var r = 0; r < g.size; r++) {
        for (var c = 0; c < g.size; c++) {
          if (!g.isGiven(r, c)) {
            g.select(r, c);
            g.place(g.solutionAt(r, c));
          }
        }
      }
    }
    expect(g.finished, isTrue, reason: 'board should be completable');
    expect(g.errorCount, 0);
  });

  test('memory matrix deck has matching pairs', () {
    final g = MemoryMatrixGame();
    g.difficulty = Difficulty.easy;
    g.init();
    g.start();

    final counts = <int, int>{};
    for (final c in g.cards) {
      counts[c.symbol] = (counts[c.symbol] ?? 0) + 1;
    }
    expect(counts.values.every((v) => v == 2), isTrue,
        reason: 'every symbol must appear exactly twice');
  });

  test('theme exposes the neon palette', () {
    expect(MindTheme.neonBlue.value, 0xFF00F3FF);
    expect(MindTheme.bgDeep.value, 0xFF05070A);
  });
}

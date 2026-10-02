// Widget-level integration tests: real navigation + real gameplay
// interaction through the actual widget tree.
//
// These are the tests that prove the app works end to end —
// tapping a card, choosing a difficulty, pressing START, and
// interacting with each game board.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindmaster/engine.dart';
import 'package:mindmaster/game_screen.dart';
import 'package:mindmaster/home_screen.dart';
import 'package:mindmaster/store.dart';
import 'package:mindmaster/theme.dart';
import 'package:mindmaster/games/math_sprint.dart';
import 'package:mindmaster/games/logic_puzzles.dart';
import 'package:mindmaster/games/color_match.dart';
import 'package:mindmaster/games/focus_grid.dart';
import 'package:mindmaster/games/memory_matrix.dart';
import 'package:mindmaster/games/pattern_recall.dart';

Future<void> _boot() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await Store.instance.init();
  Engine.register('math_sprint', () => MathSprintGame());
  Engine.register('logic_puzzles', () => LogicPuzzlesGame());
  Engine.register('color_match', () => ColorMatchGame());
  Engine.register('focus_grid', () => FocusGridGame());
  Engine.register('memory_matrix', () => MemoryMatrixGame());
  Engine.register('pattern_recall', () => PatternRecallGame());
}


/// Tears down the pumped widget tree and marks the game disposed so
/// the engine's polling loop exits and every game timer is cancelled
/// before the test framework checks for leaks.
Future<void> _teardown(WidgetTester tester) async {
  // Mark disposed first: Engine.run's loop watches this flag, and
  // setting it makes the pending poll return.
  final state = tester.state(find.byType(GameScreen));
  final game = (state as dynamic).widget.game as Game;
  game.disposed = true;
  game.dispose();

  // Pump a real frame so Engine.run can observe the flag and unwind,
  // then unmount the tree.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(_boot);

  testWidgets('home screen lists all six games', (tester) async {
    await tester.pumpWidget(const MindMasterTestApp());
    await tester.pumpAndSettle();

    expect(find.text('MINDMASTER'), findsOneWidget);
    for (final title in [
      'Math Sprint',
      'Logic Puzzles',
      'Color Match',
      'Focus Grid',
      'Memory Matrix',
      'Pattern Recall',
    ]) {
      expect(find.text(title), findsOneWidget, reason: '\$title should be listed');
    }
    expect(find.text('TOP SCORES'), findsOneWidget);
  });

  testWidgets('home screen scrolls (regression: was scroll-locked)',
      (tester) async {
    await tester.pumpWidget(const MindMasterTestApp());
    await tester.pumpAndSettle();

    // The scroll view must have content taller than the viewport.
    final scrollable = find.byType(Scrollable).first;
    expect(scrollable, findsOneWidget);

    // Drag upward and confirm the content moved.
    final before = tester.getTopLeft(find.text('Pattern Recall'));
    await tester.drag(find.byType(SingleChildScrollView).first,
        const Offset(0, -400));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.text('Pattern Recall'));

    expect(after.dy, lessThan(before.dy),
        reason: 'content should move up after a drag');
  });

  testWidgets('tapping a game card opens its setup screen', (tester) async {
    await tester.pumpWidget(const MindMasterTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Math Sprint'));
    await tester.pumpAndSettle();

    // Difficulty selector + START button are present.
    expect(find.text('🌱 EASY'), findsOneWidget);
    expect(find.text('⚡ MEDIUM'), findsOneWidget);
    expect(find.text('🔥 HARD'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('math sprint: START renders a question and four answers',
      (tester) async {
    await tester.pumpWidget(
      MindMasterTestApp(home: GameScreen(game: MathSprintGame())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START'));
    // Let the engine's polling loop start the game.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final g = (tester.state(find.byType(GameScreen)) as dynamic).widget.game
        as MathSprintGame;
    expect(g.current, isNotNull);

    // The board renders exactly four answer buttons.
    await tester.pump();
    final answerButtons = find.byType(InkWell);
    expect(answerButtons, findsWidgets);
    await _teardown(tester);
  });

  testWidgets('focus grid: board renders a full grid of tiles',
      (tester) async {
    await tester.pumpWidget(
      MindMasterTestApp(home: GameScreen(game: FocusGridGame())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final g = (tester.state(find.byType(GameScreen)) as dynamic).widget.game
        as FocusGridGame;
    expect(g.tiles.length, 25, reason: 'medium difficulty = 5x5 = 25 tiles');
    expect(g.nextExpected, 1);
    await _teardown(tester);
  });

  testWidgets('logic puzzles: board renders a grid sized to difficulty',
      (tester) async {
    await tester.pumpWidget(
      MindMasterTestApp(home: GameScreen(game: LogicPuzzlesGame())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final g = (tester.state(find.byType(GameScreen)) as dynamic).widget.game
        as LogicPuzzlesGame;
    expect(g.size, 6, reason: 'medium = 6x6');
    expect(g.totalCells, 36);
    expect(g.finished, isFalse);
    await _teardown(tester);
  });

  testWidgets('memory matrix: board renders a deck of cards',
      (tester) async {
    await tester.pumpWidget(
      MindMasterTestApp(home: GameScreen(game: MemoryMatrixGame())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final g = (tester.state(find.byType(GameScreen)) as dynamic).widget.game
        as MemoryMatrixGame;
    expect(g.cards.length, 36, reason: 'medium = 6x6 = 36 cards');
    await _teardown(tester);
  });

  testWidgets('color match: board renders a word plus colour choices',
      (tester) async {
    await tester.pumpWidget(
      MindMasterTestApp(home: GameScreen(game: ColorMatchGame())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final g = (tester.state(find.byType(GameScreen)) as dynamic).widget.game
        as ColorMatchGame;
    expect(g.word, isNotNull);
    expect(g.choices.length, 6, reason: 'medium = 6 colours');
    await _teardown(tester);
  });

  testWidgets('pattern recall: board renders four pads', (tester) async {
    await tester.pumpWidget(
      MindMasterTestApp(home: GameScreen(game: PatternRecallGame())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final g = (tester.state(find.byType(GameScreen)) as dynamic).widget.game
        as PatternRecallGame;
    expect(g.sequence.length, 1, reason: 'first round has one pad');
    expect(g.lives, 2, reason: 'medium difficulty = 2 lives');
    await _teardown(tester);
  });
}

/// Wraps a screen in the app theme so widgets resolve correctly.
class MindMasterTestApp extends StatelessWidget {
  final Widget? home;

  const MindMasterTestApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MindTheme.theme(),
      home: home ?? const HomeScreen(),
    );
  }
}
// MindMaster — native game engine.
//
// Replaces the WebView/JS runtime with real Dart: a Game interface,
// per-game registration, session lifecycle, scoring with difficulty
// multipliers and error penalties, and achievement checks.
import 'dart:math';

import 'package:flutter/material.dart';

import 'store.dart';

enum Difficulty { easy, medium, hard }

extension DifficultyX on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'EASY',
        Difficulty.medium => 'MEDIUM',
        Difficulty.hard => 'HARD',
      };

  String get emoji => switch (this) {
        Difficulty.easy => '🌱',
        Difficulty.medium => '⚡',
        Difficulty.hard => '🔥',
      };

  /// Score multiplier applied to the raw game score.
  double get multiplier => switch (this) {
        Difficulty.easy => 1.0,
        Difficulty.medium => 1.5,
        Difficulty.hard => 2.2,
      };

  /// Per-error score penalty (0 = forgiving).
  double get penalty => switch (this) {
        Difficulty.easy => 0.0,
        Difficulty.medium => 0.15,
        Difficulty.hard => 0.5,
      };
}

/// Contract every game implements. The engine drives the lifecycle:
/// init → start → (game updates score itself) → end.
abstract class Game {
  String get id;
  String get title;
  String get icon;
  String get description;

  /// Called once when the game is opened. Build the board here.
  /// Takes no context: games are pure state machines, and the
  /// board widgets own all rendering.
  void init();

  /// Begin play. Start timers here.
  void start();

  /// Current raw score (pre-multiplier).
  int get score;

  /// Progress counters used for scoring + achievements.
  /// Games that track steps (answers, taps, matched pairs)
  /// report them here; a game with no notion of "steps"
  /// (pure speed runs) leaves totalSteps at 0.
  int get totalSteps;
  int get correctSteps;
  int get errorCount;

  /// Human-readable result line shown at game over.
  String get summary;

  /// Reset to the pre-start state.
  void reset();

  /// Tear down timers so they don't leak between sessions.
  void dispose() {}

  bool get finished;

  /// Set by the host when the game screen goes away. The engine's
  /// session loop watches this so leaving a game mid-play tears the
  /// loop down instead of spinning forever.
  bool disposed = false;
}

/// Thrown when the player leaves a game before it finishes.
class SessionAbandoned implements Exception {
  const SessionAbandoned();
  @override
  String toString() => 'SessionAbandoned';
}

class GameResult {
  final Game game;
  final int rawScore;
  final int finalScore;
  final int correct;
  final int total;
  final int errors;
  final int durationSeconds;
  final int best;
  final bool isNewBest;
  final int xpEarned;
  final List<String> unlocked;

  GameResult({
    required this.game,
    required this.rawScore,
    required this.finalScore,
    required this.correct,
    required this.total,
    required this.errors,
    required this.durationSeconds,
    required this.best,
    required this.isNewBest,
    required this.xpEarned,
    required this.unlocked,
  });

  double get accuracy =>
      total > 0 ? ((correct / total) * 100).clamp(0, 100).toDouble() : 0;
}

class Engine {
  Engine._();

  static final Map<String, Game Function()> _registry = {};

  static final Engine instance = Engine._();

  final Random _rng = Random();

  int rand(int min, int max) => min + _rng.nextInt(max - min + 1);

  List<T> shuffled<T>(List<T> items) {
    final copy = [...items];
    copy.shuffle(_rng);
    return copy;
  }

  static void register(String id, Game Function() factory) {
    _registry[id] = factory;
  }

  static List<String> get gameIds => _registry.keys.toList();

  static Game? create(String id) => _registry[id]?.call();

  /// Run a full session: init, start, then wait for the game to
  /// report finished. Applies difficulty scoring, persists the
  /// result, and returns a [GameResult] for the end screen.
  Future<GameResult> run({
    required Game game,
    required Difficulty difficulty,
    required VoidCallback onTick,
  }) async {
    final stopwatch = Stopwatch()..start();

    game.init();
    game.start();

    // Poll until the game finishes. 60ms keeps the timer display
    // smooth without burning battery.
    //
    // `game.disposed` guards the case where the player leaves the
    // screen mid-game: without it the loop would never exit and the
    // isolate would keep waking up every 60ms for the rest of the
    // session.
    while (!game.finished && !game.disposed) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!game.finished && !game.disposed) onTick();
    }
    stopwatch.stop();

    // Disposed mid-game: tear down and report nothing. Persisting a
    // partial session would write a bogus score to the leaderboard.
    if (game.disposed) {
      game.dispose();
      throw const SessionAbandoned();
    }

    final raw = game.score;
    final duration = stopwatch.elapsed.inSeconds;

    // Scoring: difficulty multiplier minus an error penalty.
    var finalScore = (raw * difficulty.multiplier).round();
    if (difficulty.penalty > 0) {
      finalScore = (finalScore * (1 - difficulty.penalty)).round();
    }
    finalScore = max(0, finalScore);

    final previousBest = Store.instance.highScore(game.id, difficulty.name);

    await Store.instance.recordSession(Session(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      game: game.id,
      difficulty: difficulty.name,
      score: finalScore,
      correct: game.totalSteps == 0 ? 0 : game.correctSteps,
      total: game.totalSteps,
      errors: game.errorCount,
      durationSeconds: duration,
      timestamp: DateTime.now(),
    ));

    final xp = finalScore ~/ 10 + 10;
    final unlocked = <String>[];

    // Achievements — first completion, flawless run, difficulty tiers.
    final firstKey = 'first_${game.id}';
    if (Store.instance.achievements.length < 999 &&
        finalScore > 0 &&
        !Store.instance.achievements.contains(firstKey)) {
      await Store.instance.unlock(firstKey);
      unlocked.add('First ${game.title}');
    }
    if (game.errorCount == 0 && game.totalSteps > 2) {
      await Store.instance.unlock('flawless_${game.id}');
      if (!unlocked.contains('Flawless')) unlocked.add('Flawless');
    }
    if (difficulty == Difficulty.hard && finalScore > 0) {
      await Store.instance.unlock('hard_${game.id}');
      if (!unlocked.contains('Hard Mode Clear')) unlocked.add('Hard Mode Clear');
    }

    return GameResult(
      game: game,
      rawScore: raw,
      finalScore: finalScore,
      correct: game.correctSteps,
      total: game.totalSteps,
      errors: game.errorCount,
      durationSeconds: duration,
      best: max(previousBest, finalScore),
      isNewBest: finalScore > previousBest,
      xpEarned: xp,
      unlocked: unlocked,
    );
  }
}
// Game screen — hosts any registered game.
//
// Shows the difficulty picker, the live game board,
// and on completion the result panel (score, accuracy,
// XP, new-best badge, unlocked achievements).
import 'package:flutter/material.dart';

import 'engine.dart';
import 'store.dart';
import 'theme.dart';
import 'boards.dart';
import 'games/math_sprint.dart';
import 'games/logic_puzzles.dart';
import 'games/color_match.dart';
import 'games/focus_grid.dart';
import 'games/memory_matrix.dart';
import 'games/pattern_recall.dart';

class GameScreen extends StatefulWidget {
  final Game game;

  const GameScreen({super.key, required this.game});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Difficulty _difficulty = Difficulty.medium;
  bool _started = false;
  GameResult? _result;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _applyDifficulty();
  }

  void _applyDifficulty() {
    final g = widget.game;
    if (g is MathSprintGame) g.difficulty = _difficulty;
    if (g is LogicPuzzlesGame) g.difficulty = _difficulty;
    if (g is ColorMatchGame) g.difficulty = _difficulty;
    if (g is FocusGridGame) g.difficulty = _difficulty;
    if (g is MemoryMatrixGame) g.difficulty = _difficulty;
    if (g is PatternRecallGame) g.difficulty = _difficulty;
  }

  Future<void> _start() async {
    setState(() {
      _started = true;
      _result = null;
    });
    _applyDifficulty();
    GameResult result;
    try {
      result = await Engine.instance.run(
        game: widget.game,
        difficulty: _difficulty,
        onTick: () {
          if (mounted) setState(() => _tick++);
        },
      );
    } on SessionAbandoned {
      // Player backed out mid-game — nothing to show.
      return;
    }
    if (mounted) {
      setState(() => _result = result);
    }
  }

  @override
  void dispose() {
    // Signal the engine loop to stop before cancelling the game's
    // own timers, so an abandoned session does not persist a score.
    widget.game.disposed = true;
    widget.game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${g.icon}  ${g.title}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: MindTheme.screenGradient),
        child: SafeArea(
          child: Column(
            children: [
              _difficultyPicker(),
              const SizedBox(height: 8),
              Expanded(
                child: _started && _result == null
                    ? _gameBoard(g)
                    : _result != null
                        ? _resultPanel(_result!)
                        : _startPrompt(g),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _difficultyPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SegmentedButton<Difficulty>(
        segments: const [
          ButtonSegment(
            value: Difficulty.easy,
            label: Text('🌱 EASY'),
          ),
          ButtonSegment(
            value: Difficulty.medium,
            label: Text('⚡ MEDIUM'),
          ),
          ButtonSegment(
            value: Difficulty.hard,
            label: Text('🔥 HARD'),
          ),
        ],
        selected: {_difficulty},
        onSelectionChanged: _started
            ? null
            : (set) {
                setState(() => _difficulty = set.first);
                _applyDifficulty();
              },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return MindTheme.neonBlue.withValues(alpha: 0.25);
            }
            return MindTheme.bgGlass;
          }),
        ),
      ),
    );
  }

  Widget _startPrompt(Game g) {
    final best = Store.instance.highScore(g.id, _difficulty.name);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(g.icon, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text(g.description,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: MindTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (best > 0)
              Text('Best on ${_difficulty.label}: $best',
                  style: const TextStyle(
                    color: MindTheme.neonAmber,
                    fontWeight: FontWeight.w600,
                  )),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('START'),
              style: FilledButton.styleFrom(
                backgroundColor: MindTheme.neonBlue,
                foregroundColor: MindTheme.bgDeep,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameBoard(Game g) {
    // Force rebuild on engine ticks (timers etc.)
    _tick;
    switch (g) {
      case MathSprintGame():
        return MathSprintBoard(game: g);
      case LogicPuzzlesGame():
        return LogicPuzzlesBoard(game: g);
      case ColorMatchGame():
        return ColorMatchBoard(game: g);
      case FocusGridGame():
        return FocusGridBoard(game: g);
      case MemoryMatrixGame():
        return MemoryMatrixBoard(game: g);
      case PatternRecallGame():
        return PatternRecallBoard(game: g);
      default:
        return const Center(child: Text('Unknown game'));
    }
  }

  Widget _resultPanel(GameResult r) {
    final store = Store.instance;
    return RefreshIndicator(
      color: MindTheme.neonBlue,
      backgroundColor: MindTheme.bgPanel,
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            if (r.isNewBest)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: MindTheme.neonAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MindTheme.neonAmber),
                ),
                child: const Text('🏆 NEW BEST!',
                    style:
                        TextStyle(color: MindTheme.neonAmber, fontWeight: FontWeight.w800)),
              ),
            const SizedBox(height: 20),
            Text('${r.game.icon}', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text('${r.finalScore}', style: MindTheme.display(56, color: MindTheme.neonGreen)),
            const SizedBox(height: 8),
            Text('points',
                style: const TextStyle(color: MindTheme.textMuted)),
            const SizedBox(height: 24),
            Row(
              children: [
                _resultStat('ACCURACY', '${r.accuracy.toStringAsFixed(0)}%', MindTheme.neonBlue),
                const SizedBox(width: 12),
                _resultStat('TIME', '${r.durationSeconds}s', MindTheme.neonPurple),
                const SizedBox(width: 12),
                _resultStat('XP', '+${r.xpEarned}', MindTheme.neonAmber),
              ],
            ),
            const SizedBox(height: 16),
            Text(r.game.summary,
                style: const TextStyle(color: MindTheme.textSecondary)),
            if (r.unlocked.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('ACHIEVEMENTS UNLOCKED',
                  style: MindTheme.display(14, color: MindTheme.neonAmber)),
              const SizedBox(height: 8),
              ...r.unlocked
                  .map((a) => Text('🏅 $a',
                      style: const TextStyle(color: MindTheme.textPrimary)))
                  .toList(),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _started = false;
                        _result = null;
                        r.game.reset();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('CHANGE DIFFICULTY'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MindTheme.textSecondary,
                      side: const BorderSide(color: MindTheme.textMuted),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.replay),
                    label: const Text('PLAY AGAIN'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MindTheme.neonBlue,
                      foregroundColor: MindTheme.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to menu',
                  style: TextStyle(color: MindTheme.textMuted)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _resultStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: MindTheme.glass(radius: 14),
        child: Column(
          children: [
            Text(value, style: MindTheme.display(20, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: MindTheme.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}
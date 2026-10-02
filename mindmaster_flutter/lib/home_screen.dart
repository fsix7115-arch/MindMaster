// Home screen — game grid + live leaderboard.
//
// Pulls per-game stats from the local store and
// renders a glassmorphism card per game. The
// leaderboard is a top-10 across all games.
import 'package:flutter/material.dart';

import 'engine.dart';
import 'store.dart';
import 'theme.dart';
import 'game_screen.dart';
import 'games/math_sprint.dart';
import 'games/logic_puzzles.dart';
import 'games/color_match.dart';
import 'games/focus_grid.dart';
import 'games/memory_matrix.dart';
import 'games/pattern_recall.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _registerGames();
  }

  void _registerGames() {
    Engine.register('math_sprint', () => MathSprintGame());
    Engine.register('logic_puzzles', () => LogicPuzzlesGame());
    Engine.register('color_match', () => ColorMatchGame());
    Engine.register('focus_grid', () => FocusGridGame());
    Engine.register('memory_matrix', () => MemoryMatrixGame());
    Engine.register('pattern_recall', () => PatternRecallGame());
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final stats = Engine.gameIds.map((id) {
      final game = Engine.create(id)!;
      final s = store.statsFor(id);
      return (game: game, stats: s);
    }).toList();

    final top = store.topScores(limit: 10);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: MindTheme.screenGradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: MindTheme.neonBlue,
            backgroundColor: MindTheme.bgPanel,
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(store),
                  const SizedBox(height: 24),
                  _statsBar(store),
                  const SizedBox(height: 32),
                  Text('GAMES', style: MindTheme.display(18, color: MindTheme.neonBlue)),
                  const SizedBox(height: 16),
                  ...stats.map((s) => _gameCard(context, s.game, s.stats)),
                  const SizedBox(height: 32),
                  _leaderboard(top),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Store store) {
    return Column(
      children: [
        Text(
          'MINDMASTER',
          style: MindTheme.display(36, color: MindTheme.neonBlue),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '6 brain-training games · offline · no ads',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: MindTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _levelChip(store),
      ],
    );
  }

  Widget _levelChip(Store store) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: MindTheme.glass(radius: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: MindTheme.neonAmber, size: 18),
          const SizedBox(width: 8),
          Text(
            'LEVEL ${store.player.level} · ${store.player.xp}/${store.player.xpToNext} XP',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: MindTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsBar(Store store) {
    final total = store.sessions.length;
    final best = store.sessions.isEmpty
        ? 0
        : store.sessions.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    return Row(
      children: [
        _stat('SESSIONS', '$total', MindTheme.neonGreen),
        const SizedBox(width: 12),
        _stat('BEST', '$best', MindTheme.neonPurple),
        const SizedBox(width: 12),
        _stat('GAMES', '6', MindTheme.neonBlue),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: MindTheme.glass(),
        child: Column(
          children: [
            Text(value,
                style: MindTheme.display(22, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: MindTheme.textMuted,
                )),
          ],
        ),
      ),
    );
  }

  Widget _gameCard(BuildContext context, Game game, ({int plays, int best, int total}) stats) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openGame(context, game),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: MindTheme.glass(),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MindTheme.neonBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(game.icon, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.title,
                          style: MindTheme.display(18)),
                      const SizedBox(height: 4),
                      Text(game.description,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: MindTheme.textSecondary)),
                      if (stats.plays > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${stats.plays} plays · best ${stats.best}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MindTheme.neonGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: MindTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leaderboard(List<Session> top) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TOP SCORES', style: MindTheme.display(18, color: MindTheme.neonPurple)),
        const SizedBox(height: 12),
        if (top.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: MindTheme.glass(),
            child: const Center(
              child: Text(
                'No sessions yet — play a game to light up the board.',
                style: TextStyle(color: MindTheme.textMuted),
              ),
            ),
          )
        else
          ...top.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final medal = i < 3
                ? ['🥇', '🥈', '🥉'][i]
                : '#${i + 1}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: MindTheme.glass(radius: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(medal,
                          style: const TextStyle(fontSize: 16)),
                    ),
                    Text(_gameTitle(s.game),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MindTheme.textPrimary,
                        )),
                    const Spacer(),
                    Text(s.difficulty.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: MindTheme.textMuted,
                        )),
                    const SizedBox(width: 12),
                    Text(
                      s.score.toString(),
                      style: MindTheme.display(18, color: MindTheme.neonGreen),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _gameTitle(String id) {
    final game = Engine.create(id);
    return game?.title ?? id;
  }

  Future<void> _openGame(BuildContext context, Game game) async {
    final result = await Navigator.of(context).push<GameResult>(
      MaterialPageRoute(
        builder: (_) => GameScreen(game: game),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) setState(() {});
  }
}
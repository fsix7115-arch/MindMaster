import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'memory_matrix_game.dart';

/// The Memory Matrix play screen.
///
/// All rules live in [MemoryMatrixGame]; this file only turns them into pixels
/// and schedules the flip-away animation after a miss.
class MemoryMatrixScreen extends StatefulWidget {
  const MemoryMatrixScreen({super.key, this.onFinished});

  final void Function(int score, int moves, int matchedPairs)? onFinished;

  @override
  State<MemoryMatrixScreen> createState() => _MemoryMatrixScreenState();
}

class _MemoryMatrixScreenState extends State<MemoryMatrixScreen> {
  late MemoryMatrixGame _game;
  late List<MemoryCard> _cards;

  /// Emojis rather than drawn icons: no assets to ship, and they stay legible
  /// at every grid size without a custom font.
  static const _symbols = [
    '🚀', '🌙', '⚡', '🎯', '🔮', '🍀', '🐝', '🎸',
    '🧊', '🌈', '🍕', '🐢', '💎', '🔥', '🎧', '🦋',
    '🌻', '🍉', '🪐', '⚙️', '📦', '🎨', '🏀', '🧩',
    '🌊', '🗝️', '🪁', '🍩', '🧲', '🎙️', '🐢', '🚀',
  ];

  int _seconds = 0;
  bool _showTimer = true;

  @override
  void initState() {
    super.initState();
    _start(size: MatrixSize.small);
  }

  void _start({required MatrixSize size}) {
    _game = MemoryMatrixGame(size: size);
    _cards = _game.cards;
    _seconds = 0;
    setState(() {});
    _tick();
  }

  void _tick() {
    if (!mounted || _game.complete) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _game.complete) return;
      setState(() => _seconds++);
      _tick();
    });
  }

  void _onCardTap(MemoryCard card) {
    if (!_game.canFlip(card)) return;

    HapticFeedback.selectionClick();
    final outcome = _game.flip(card);
    setState(() {});

    if (outcome == FlipOutcome.miss) {
      Future.delayed(Duration(milliseconds: _game.flipDelayMs), () {
        if (!mounted) return;
        _game.resolveMiss();
        setState(() {});
      });
    } else if (outcome == FlipOutcome.match) {
      HapticFeedback.mediumImpact();
    }

    if (_game.complete) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        widget.onFinished?.call(
          MemoryMatrixGame.score(
            size: _game.size,
            moves: _game.moves,
            seconds: _seconds,
          ),
          _game.moves,
          _game.matchedPairs,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _game.size.side,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          return _MemoryTile(
                            symbol: _symbols[card.symbolIndex % _symbols.length],
                            faceUp: card.faceUp,
                            matched: card.matched,
                            onTap: () => _onCardTap(card),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildControls(),
                ],
              ),
            ),
            if (_game.complete) _buildCompleteOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _HeadStat(label: 'Moves', value: '${_game.moves}'),
        _HeadStat(label: 'Pairs', value: '${_game.matchedPairs}/${_game.size.pairCount}'),
        _HeadStat(label: 'Time', value: '${_seconds}s'),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              for (final size in MatrixSize.values)
                ChoiceChip(
                  label: Text(size.label),
                  selected: _game.size == size,
                  onSelected: (_) => _start(size: size),
                  selectedColor: const Color(0xFF6C4AB6),
                  labelStyle: TextStyle(
                    color: _game.size == size ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _showTimer = !_showTimer),
          icon: Icon(
            _showTimer ? Icons.timer_outlined : Icons.timer_off_outlined,
            color: Colors.white54,
          ),
          tooltip: _showTimer ? 'Hide timer' : 'Show timer',
        ),
      ],
    );
  }

  Widget _buildCompleteOverlay() {
    final score = MemoryMatrixGame.score(
      size: _game.size,
      moves: _game.moves,
      seconds: _seconds,
    );
    final perfect = _game.moves == _game.size.pairCount;

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F0F1A).withValues(alpha: 0.95),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  perfect ? 'Perfect!' : 'Board cleared',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFA8FF48),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FinalStat(label: 'Moves', value: '${_game.moves}'),
                    _FinalStat(label: 'Time', value: '${_seconds}s'),
                    _FinalStat(label: 'Size', value: _game.size.label),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _start(size: _game.size),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text('Play again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6C4AB6),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single card. Shows the symbol when face up, a neutral back when not.
class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.symbol,
    required this.faceUp,
    required this.matched,
    required this.onTap,
  });

  final String symbol;
  final bool faceUp;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final show = faceUp || matched;

    Color bg;
    if (matched) {
      bg = const Color(0xFF22C55E).withValues(alpha: 0.28);
    } else if (show) {
      bg = const Color(0xFF6C4AB6);
    } else {
      bg = const Color(0xFF1E1E33);
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: matched ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          // Scale rather than hide the symbol when matched, so the board stays
          // readable as a record of what was found.
          child: AnimatedScale(
            scale: matched ? 0.8 : 1,
            duration: const Duration(milliseconds: 180),
            child: Text(symbol, style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }
}

class _HeadStat extends StatelessWidget {
  const _HeadStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _FinalStat extends StatelessWidget {
  const _FinalStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}
// Board widgets — one per game.
//
// Each board is pure UI: it reads game state and calls
// back into the game object. All gameplay logic lives
// in lib/games/*.dart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine.dart';
import '../theme.dart';
import '../games/math_sprint.dart';
import '../games/logic_puzzles.dart';
import '../games/color_match.dart';
import '../games/focus_grid.dart';
import '../games/memory_matrix.dart';
import '../games/pattern_recall.dart';

/// Shared header: score + timer line above a board.
class _HudRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final Color leftColor;
  final String? rightLabel;
  final String? rightValue;
  final Color rightColor;

  const _HudRow({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.leftColor,
    this.rightLabel,
    this.rightValue,
    this.rightColor = MindTheme.neonPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _chip(leftLabel, leftValue, leftColor),
          if (rightLabel != null) ...[
            const SizedBox(width: 12),
            _chip(rightLabel!, rightValue ?? '', rightColor),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: MindTheme.glass(radius: 14),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: MindTheme.textMuted,
              )),
          const SizedBox(width: 10),
          Text(value,
              style: MindTheme.display(20, color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Math Sprint

class MathSprintBoard extends StatefulWidget {
  final MathSprintGame game;
  const MathSprintBoard({super.key, required this.game});

  @override
  State<MathSprintBoard> createState() => _MathSprintBoardState();
}

class _MathSprintBoardState extends State<MathSprintBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final q = g.current;
    return Column(
      children: [
        _HudRow(
          leftLabel: 'SCORE',
          leftValue: '${g.score}',
          leftColor: MindTheme.neonGreen,
          rightLabel: 'TIME',
          rightValue: '${g.secondsLeft}s',
          rightColor: g.secondsLeft <= 10
              ? MindTheme.neonRed
              : MindTheme.neonBlue,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                if (q != null)
                  Text(q.display,
                      style: MindTheme.display(48, color: MindTheme.neonBlue),
                      textAlign: TextAlign.center)
                else
                  const SizedBox(height: 60),
                const SizedBox(height: 8),
                if (g.streak >= 3)
                  Text('★ STREAK ×${(g.streak ~/ 3) + 1}',
                      style: MindTheme.display(14, color: MindTheme.neonAmber)),
                const SizedBox(height: 24),
                if (q != null)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: q.options
                        .map((opt) => _answerButton(g, opt))
                        .toList(),
                  ),
                const SizedBox(height: 20),
                Text('QUESTION ${g.correctSteps + g.errorCount + 1}/${MathSprintGame.questionCount}',
                    style: const TextStyle(
                      color: MindTheme.textMuted,
                      letterSpacing: 1,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _answerButton(MathSprintGame g, int value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => g.answer(value));
        },
        child: Container(
          alignment: Alignment.center,
          decoration: MindTheme.glass(radius: 16),
          child: Text('$value',
              style: MindTheme.display(26, color: MindTheme.textPrimary)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Logic Puzzles

class LogicPuzzlesBoard extends StatefulWidget {
  final LogicPuzzlesGame game;
  const LogicPuzzlesBoard({super.key, required this.game});

  @override
  State<LogicPuzzlesBoard> createState() => _LogicPuzzlesBoardState();
}

class _LogicPuzzlesBoardState extends State<LogicPuzzlesBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final size = g.size;
    return Column(
      children: [
        _HudRow(
          leftLabel: 'FILLED',
          leftValue: '${g.filled}/${g.totalCells}',
          leftColor: MindTheme.neonGreen,
          rightLabel: 'ERRORS',
          rightValue: '${g.errorCount}',
          rightColor: MindTheme.neonRed,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: MindTheme.glass(radius: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: size * size,
                    itemBuilder: (context, index) {
                      final r = index ~/ size;
                      final c = index % size;
                      final value = g.cellAt(r, c);
                      final given = g.isGiven(r, c);
                      final selected = g.selectedRow == r && g.selectedCol == c;
                      return _sudokuCell(value, given, selected,
                          () => setState(() => g.select(r, c)));
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: List.generate(size, (i) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => g.place(i + 1));
                        },
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: MindTheme.glass(radius: 12),
                          child: Text('${i + 1}',
                              style: MindTheme.display(20,
                                  color: MindTheme.neonBlue)),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sudokuCell(int value, bool given, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? MindTheme.neonBlue.withValues(alpha: 0.18)
                : (given
                    ? MindTheme.bgPanel.withValues(alpha: 0.7)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? MindTheme.neonBlue : MindTheme.borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: value == 0
              ? null
              : Text('$value',
                  style: MindTheme.display(
                    20,
                    color: given ? MindTheme.textSecondary : MindTheme.neonGreen,
                  )),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Color Match

class ColorMatchBoard extends StatefulWidget {
  final ColorMatchGame game;
  const ColorMatchBoard({super.key, required this.game});

  @override
  State<ColorMatchBoard> createState() => _ColorMatchBoardState();
}

class _ColorMatchBoardState extends State<ColorMatchBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return Column(
      children: [
        _HudRow(
          leftLabel: 'SCORE',
          leftValue: '${g.score}',
          leftColor: MindTheme.neonGreen,
          rightLabel: 'ROUND',
          rightValue: '${g.round}/${ColorMatchGame.rounds}',
          rightColor: MindTheme.neonBlue,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 32),
                if (g.word != null)
                  Text(
                    g.word!,
                    style: MindTheme.display(
                      44,
                      color: g.inkColor ?? MindTheme.textPrimary,
                    ),
                  )
                else
                  const SizedBox(height: 80),
                const SizedBox(height: 8),
                const Text('TAP THE INK COLOR',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: MindTheme.textMuted,
                    )),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: g.choices.map((name) {
                    return _colorChoice(name, g);
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorChoice(String name, ColorMatchGame g) {
    final color = _colorFor(name);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => g.answer(name));
        },
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: MindTheme.glass(radius: 14),
          child: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFor(String name) {
    const map = {
      'RED': Color(0xFFFF2A6D),
      'BLUE': Color(0xFF00F3FF),
      'GREEN': Color(0xFF00FF9D),
      'YELLOW': Color(0xFFFFAA00),
      'PURPLE': Color(0xFFBC13FE),
      'ORANGE': Color(0xFFFF6B35),
      'PINK': Color(0xFFFF7EB6),
      'CYAN': Color(0xFF00E5FF),
    };
    return map[name] ?? MindTheme.textPrimary;
  }
}

// ---------------------------------------------------------------- Focus Grid

class FocusGridBoard extends StatefulWidget {
  final FocusGridGame game;
  const FocusGridBoard({super.key, required this.game});

  @override
  State<FocusGridBoard> createState() => _FocusGridBoardState();
}

class _FocusGridBoardState extends State<FocusGridBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return Column(
      children: [
        _HudRow(
          leftLabel: 'NEXT',
          leftValue: '${g.nextExpected}',
          leftColor: MindTheme.neonAmber,
          rightLabel: 'TIME',
          rightValue: '${g.secondsElapsed}s',
          rightColor: MindTheme.neonBlue,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: g.gridSize,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: g.tiles.length,
                itemBuilder: (context, index) {
                  final value = g.tiles[index];
                  final tapped = value < g.nextExpected;
                  return _gridTile(value, tapped, () {
                    HapticFeedback.selectionClick();
                    setState(() => g.tap(value));
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridTile(int value, bool tapped, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: tapped ? null : onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tapped
                ? MindTheme.neonGreen.withValues(alpha: 0.12)
                : MindTheme.bgGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tapped
                  ? MindTheme.neonGreen.withValues(alpha: 0.4)
                  : MindTheme.borderColor,
            ),
          ),
          child: Text('$value',
              style: MindTheme.display(
                22,
                color: tapped ? MindTheme.textMuted : MindTheme.textPrimary,
              )),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Memory Matrix

class MemoryMatrixBoard extends StatefulWidget {
  final MemoryMatrixGame game;
  const MemoryMatrixBoard({super.key, required this.game});

  @override
  State<MemoryMatrixBoard> createState() => _MemoryMatrixBoardState();
}

class _MemoryMatrixBoardState extends State<MemoryMatrixBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return Column(
      children: [
        _HudRow(
          leftLabel: 'PAIRS',
          leftValue: '${g.matchedPairs}',
          leftColor: MindTheme.neonGreen,
          rightLabel: 'MOVES',
          rightValue: '${g.moves}',
          rightColor: MindTheme.neonAmber,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: g.gridSize,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: g.cards.length,
                itemBuilder: (context, index) {
                  final card = g.cards[index];
                  return _memoryCard(card, () {
                    HapticFeedback.selectionClick();
                    setState(() => g.flip(index));
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _memoryCard(MemoryCard card, VoidCallback onTap) {
    final faceUp = card.faceUp || card.matched;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: faceUp ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: card.matched
                ? MindTheme.neonGreen.withValues(alpha: 0.18)
                : (faceUp
                    ? MindTheme.bgPanel
                    : MindTheme.neonPurple.withValues(alpha: 0.14)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: card.matched
                  ? MindTheme.neonGreen
                  : (faceUp
                      ? MindTheme.neonBlue
                      : MindTheme.borderColor),
            ),
          ),
          child: Text(
            faceUp ? String.fromCharCode(card.symbol) : '?',
            style: MindTheme.display(
              20,
              color: card.matched
                  ? MindTheme.neonGreen
                  : MindTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Pattern Recall

class PatternRecallBoard extends StatefulWidget {
  final PatternRecallGame game;
  const PatternRecallBoard({super.key, required this.game});

  @override
  State<PatternRecallBoard> createState() => _PatternRecallBoardState();
}

class _PatternRecallBoardState extends State<PatternRecallBoard> {
  static const _padColors = [
    MindTheme.neonBlue,
    MindTheme.neonGreen,
    MindTheme.neonAmber,
    MindTheme.neonPurple,
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return Column(
      children: [
        _HudRow(
          leftLabel: 'ROUND',
          leftValue: '${g.round}',
          leftColor: MindTheme.neonGreen,
          rightLabel: 'LIVES',
          rightValue: '❤️' * g.lives,
          rightColor: MindTheme.neonRed,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                if (g.showingSequence)
                  const Text('WATCH…',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 3,
                        color: MindTheme.neonBlue,
                      ))
                else
                  const Text('YOUR TURN',
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 3,
                        color: MindTheme.neonGreen,
                      )),
                const SizedBox(height: 32),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.4,
                  children: List.generate(PatternRecallGame.padCount, (i) {
                    final lit = g.currentlyLit == i;
                    return _pad(g, i, lit);
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pad(PatternRecallGame g, int index, bool lit) {
    final color = _padColors[index % _padColors.length];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: g.isTapAllowed
            ? () {
                HapticFeedback.mediumImpact();
                setState(() => g.tap(index));
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: lit
                ? color.withValues(alpha: 0.55)
                : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: lit ? color : color.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: lit
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 24)]
                : null,
          ),
          child: Center(
            child: Text(
              lit ? '●' : '○',
              style: TextStyle(
                fontSize: 32,
                color: lit ? MindTheme.bgDeep : color.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'math_sprint_game.dart';

/// The Math Sprint play screen.
///
/// Owns the ticker and the widget state; all scoring and generation rules live
/// in [MathSprintGame] / [RoundState] and are unit-tested there. Keeping the
/// split means the rules can be verified without a display.
class MathSprintScreen extends StatefulWidget {
  const MathSprintScreen({super.key, this.onFinished});

  /// Called with the finished round so the app can persist stats.
  final void Function(RoundResult result)? onFinished;

  @override
  State<MathSprintScreen> createState() => _MathSprintScreenState();
}

class _MathSprintScreenState extends State<MathSprintScreen>
    with SingleTickerProviderStateMixin {
  late final MathSprintGame _game = MathSprintGame();
  late final RoundState _round = RoundState(durationSeconds: 60);
  late final AnimationController _pulse;

  /// Four answers drawn around the correct one. Using a fixed-size pad of
  /// choices means the player reads the options, not their position.
  late final List<int> _options = [];

  String _feedback = '';
  bool _correctFlash = false;
  bool _wrongFlash = false;
  int _lastPoints = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _nextQuestion();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _nextQuestion() {
    final difficulty = Difficulty.forScore(_round.score);
    final question = _game.next(difficulty);
    _round.current = question;
    _options
      ..clear()
      ..addAll(_buildOptions(question.answer));
    setState(() {
      _feedback = '';
      _correctFlash = false;
      _wrongFlash = false;
    });
  }

  /// Builds four distinct choices: the true answer plus three plausible
  /// distractors. Distractors are offset rather than random so the spread is
  /// even and the correct answer is not always the largest or smallest.
  List<int> _buildOptions(int answer) {
    final set = <int>{answer};
    final offsets = [1, 2, 3, 4, 5, 6, 8, 10];

    // Try positive offsets first, then negative, so we never produce a negative
    // option on a number pad.
    for (final sign in [1, -1]) {
      for (final offset in offsets) {
        if (set.length >= 4) break;
        final candidate = answer + (offset * sign);
        if (candidate >= 0) set.add(candidate);
      }
    }
    // Very small answers may not have 3 positive neighbours; pad with upward
    // values from the top of the answer space as a last resort.
    var filler = answer + 10;
    while (set.length < 4) {
      set.add(filler);
      filler++;
    }

    final list = set.toList()..shuffle(Random(answer + 1));
    return list;
  }

  void _answer(int value) {
    if (_round.finished) return;
    final question = _round.current;
    if (question == null) return;

    if (value == question.answer) {
      _lastPoints = _round.answerCorrect();
      _pulse.forward(from: 0.97);
      setState(() {
        _correctFlash = true;
        _wrongFlash = false;
        _feedback = '+$_lastPoints';
      });
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _nextQuestion();
      });
    } else {
      _round.answerWrong();
      setState(() {
        _wrongFlash = true;
        _correctFlash = false;
        _feedback = 'Streak reset';
      });
      // The wrong answer is not replaced immediately: the player needs to see
      // the correct value to learn from the mistake.
      Future.delayed(const Duration(milliseconds: 520), () {
        if (mounted) _nextQuestion();
      });
    }
  }

  String get _secondsLeft => _round.remaining.ceil().toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Ticker: drives the countdown. Kept at the top level so it keeps
            // running regardless of rebuilds of the inner widgets.
            _Ticker(onTick: _tick),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  Expanded(child: _buildQuestion()),
                  const SizedBox(height: 24),
                  _buildPad(),
                ],
              ),
            ),
            if (_round.finished) _buildFinishedOverlay(),
          ],
        ),
      ),
    );
  }

  void _tick(double dt) {
    if (_round.finished) return;
    _round.tick(dt);
    if (_round.finished) {
      widget.onFinished?.call(_round.toResult());
    }
    // Rebuild only what changes each frame: the clock and the bar. Rebuilding
    // the whole subtree 60x a second would be wasteful.
    setState(() {});
  }

  Widget _buildHeader() {
    final ratio = _round.remaining / _round.durationSeconds;
    final urgent = _round.isLastFiveSeconds;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Stat(label: 'Score', value: '${_round.score}', accent: true),
            _Stat(
              label: 'Streak',
              value: '${_round.streak}',
              badge: _round.streak >= 3
                  ? '${MathSprintGame.multiplierFor(_round.streak)}x'
                  : null,
            ),
            _Stat(
              label: 'Time',
              value: _secondsLeft,
              accent: urgent,
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(
              urgent ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion() {
    final question = _round.current;
    if (question == null) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question.expression,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 18),
          // Colour plus a symbol, never colour alone: a red/green-only flash is
          // unreadable for a colour-blind player.
          AnimatedOpacity(
            opacity: _feedback.isEmpty ? 0 : 1,
            duration: const Duration(milliseconds: 120),
            child: Text(
              _correctFlash ? '✓  $_feedback' : '✗  $_feedback',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _correctFlash
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPad() {
    return ScaleTransition(
      scale: _pulse,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 2.1,
        children: [
          for (final option in _options)
            _AnswerKey(
              value: option,
              isCorrect: _round.current?.answer == option,
              revealed: _correctFlash || _wrongFlash,
              onTap: () => _answer(option),
            ),
        ],
      ),
    );
  }

  Widget _buildFinishedOverlay() {
    final result = _round.toResult();
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F0F1A).withValues(alpha: 0.94),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Time's up",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${result.score}',
                  style: const TextStyle(
                    fontSize: 62,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFA8FF48),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'points',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FinalStat(label: 'Correct', value: '${result.correct}'),
                    _FinalStat(label: 'Accuracy', value: '${result.accuracy}%'),
                    _FinalStat(
                        label: 'Best streak', value: '${result.bestStreak}'),
                  ],
                ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C4AB6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 34, vertical: 16),
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small header cell: label above value.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent = false, this.badge});

  final String label;
  final String value;
  final bool accent;
  final String? badge;

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
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: accent ? const Color(0xFFA8FF48) : Colors.white,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AnswerKey extends StatelessWidget {
  const _AnswerKey({
    required this.value,
    required this.isCorrect,
    required this.revealed,
    required this.onTap,
  });

  final int value;
  final bool isCorrect;

  /// Once a round is answered, the correct key lights up so the player learns
  /// the answer rather than just seeing the key turn red.
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFF6C4AB6);
    if (revealed && isCorrect) bg = const Color(0xFF22C55E);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: revealed ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: Text(
            '$value',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

/// Drives per-frame ticks without leaking a Ticker. Isolated so the countdown
/// survives rebuilds of the content above it.
class _Ticker extends StatefulWidget {
  const _Ticker({required this.onTick});

  final void Function(double dt) onTick;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMilliseconds / 1000.0;
    // Clamp the first frame and any long stall (e.g. app backgrounded) so the
    // clock does not jump and instantly end the round.
    final safe = dt.clamp(0.0, 0.25);
    _last = elapsed;
    if (safe > 0) widget.onTick(safe);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pattern_recall_game.dart';

/// Pattern Recall — a Simon-style game on a 3D pad.
///
/// The four pads sit in a tilted plane rendered with a real perspective
/// [Matrix4] transform rather than a flat grid. That gives depth, parallax on
/// drag, and press depth without needing a WebGL dependency — which matters
/// because the app must stay fully offline with no runtime downloads.
///
/// All game rules live in [PatternRecallGame]; this file is presentation only.
class PatternRecallScreen extends StatefulWidget {
  const PatternRecallScreen({super.key, this.onFinished});

  final void Function(int bestLength, int rounds)? onFinished;

  @override
  State<PatternRecallScreen> createState() => _PatternRecallScreenState();
}

class _PatternRecallScreenState extends State<PatternRecallScreen>
    with SingleTickerProviderStateMixin {
  late final PatternRecallGame _game = PatternRecallGame(startingLength: 1);

  /// Drives pad glow, scale and lift. One controller for all four pads keeps
  /// them visually in sync, which is what makes the flash read as one object.
  late final AnimationController _pulse;

  /// Tilt of the whole pad plane, in radians.
  double _tiltX = 0.42;
  double _tiltZ = 0.0;

  PadColor? _litPad;
  bool _wrongFlash = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _playSequence());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Plays the sequence back one pad at a time.
  Future<void> _playSequence() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: FlashTiming.leadInMs));

    for (final pad in _game.sequence) {
      if (!mounted) return;
      setState(() => _litPad = pad);
      await Future.delayed(const Duration(milliseconds: FlashTiming.onMs));
      if (!mounted) return;
      setState(() => _litPad = null);
      await Future.delayed(const Duration(milliseconds: FlashTiming.gapMs));
    }

    if (!mounted) return;
    _game.beginInput();
  }

  void _onPadTap(PadColor pad) {
    if (!_game.isAwaitingInput) return;

    HapticFeedback.selectionClick();
    setState(() => _litPad = pad);
    _pulse.forward(from: 0).then((_) => _pulse.reverse());

    final result = _game.tap(pad);

    // Short delay so the player's own press is visible before the next state.
    Future.delayed(const Duration(milliseconds: 130), () {
      if (!mounted) return;
      setState(() => _litPad = null);

      switch (result) {
        case TapResult.roundComplete:
          _game.showNextSequence();
          _playSequence();

        case TapResult.failed:
          HapticFeedback.heavyImpact();
          setState(() => _wrongFlash = true);
          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            setState(() => _wrongFlash = false);
            widget.onFinished?.call(_game.bestLength, _game.round);
          });

        case TapResult.accepted:
        case TapResult.ignored:
          break;
      }
    });
  }

  static const _padColors = {
    PadColor.red: Color(0xFFEF4444),
    PadColor.green: Color(0xFF22C55E),
    PadColor.blue: Color(0xFF3B82F6),
    PadColor.yellow: Color(0xFFEAB308),
  };

  @override
  Widget build(BuildContext context) {
    final failed = _game.failed;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  Expanded(child: _build3DPad()),
                  const SizedBox(height: 16),
                  _buildStatusLine(),
                ],
              ),
            ),
            if (failed) _buildFailedOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PATTERN RECALL',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.6,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${_game.length}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        ),
        _legend(),
      ],
    );
  }

  /// Small colour key. Doubles as an accessible label, since the pads are
  /// identified by colour and position during playback.
  Widget _legend() {
    return Wrap(
      spacing: 10,
      children: [
        for (final entry in _padColors.entries)
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: entry.value,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  /// The tilted pad plane.
  Widget _build3DPad() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          // Dragging tilts the plane, so the pads read as a physical object
          // rather than a flat grid.
          onPanUpdate: (d) {
            setState(() {
              _tiltZ = (_tiltZ - d.delta.dx * 0.006).clamp(-0.35, 0.35);
              _tiltX = (_tiltX + d.delta.dy * 0.004).clamp(0.15, 0.95);
            });
          },
          onPanEnd: (_) => setState(() => _tiltZ = 0),
          child: Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final matrix = Matrix4.identity()
                  // Order matters: translate the plane into place, then tilt it
                  // about X, then spin it about Z.
                  ..setEntry(3, 2, 0.0012) // perspective
                  ..rotateX(_tiltX)
                  ..rotateZ(_tiltZ);

                return Transform(
                  transform: matrix,
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: SizedBox(
                width: side,
                height: side,
                child: _padGrid(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _padGrid() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final row in [
              [PadColor.red, PadColor.green],
              [PadColor.blue, PadColor.yellow],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final pad in row)
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.18,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: _Pad(
                            color: _padColors[pad]!,
                            lit: _litPad == pad,
                            // The press animation scales the pad slightly and
                            // lifts it toward the viewer.
                            press: _pulse.value,
                            onTap: () => _onPadTap(pad),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusLine() {
    final (label, colour) = _game.failed
        ? ('Wrong pad — game over', const Color(0xFFEF4444))
        : _game.isShowingSequence
            ? ('Watch closely…', AppColorsSignals.neonGreen)
            : ('Your turn', Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
      decoration: BoxDecoration(
        // Flash the whole strip red on a wrong tap so the failure is not only
        // in the pad colours.
        color: (_wrongFlash ? const Color(0xFFEF4444) : colour)
            .withValues(alpha: _wrongFlash ? 0.26 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shape carries the meaning too, not colour alone.
          Icon(
            _game.failed
                ? Icons.close_rounded
                : _game.isShowingSequence
                    ? Icons.visibility_rounded
                    : Icons.touch_app_rounded,
            size: 17,
            color: colour,
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedOverlay() {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Opacity(
          opacity: t,
          child: Container(
            color: const Color(0xFF0F0F1A).withValues(alpha: 0.92),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Game over',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_game.bestLength}',
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFA8FF48),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'longest sequence repeated',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('Done'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6C4AB6),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('Play again'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single 3D pad.
class _Pad extends StatelessWidget {
  const _Pad({
    required this.color,
    required this.lit,
    required this.press,
    required this.onTap,
  });

  final Color color;

  /// True while this pad is flashing during playback, or pressed by the player.
  final bool lit;

  /// 0..1 press animation value.
  final double press;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Lift out of the plane when lit. Combined with the parent's perspective
    // this is what sells the depth.
    final lift = (lit ? 1.0 : 0.0) * press + (lit ? 1.0 : 0.0);
    final scale = 1 + (lift * 0.045);

    final brightness = lit ? 1.0 : 0.42;

    return Transform.translate(
      offset: Offset(0, -lift * 10),
      child: Transform.scale(
        scale: scale,
        child: AnimatedBuilder(
          animation: const AlwaysStoppedAnimation(0),
          builder: (context, _) => Material(
            color: Color.lerp(color.withValues(alpha: 0.22), color, brightness),
            borderRadius: BorderRadius.circular(24),
            // A brighter rim while lit reads as an edge highlight.
            elevation: lit ? 14 : 3,
            shadowColor: color.withValues(alpha: 0.6),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: color.withValues(alpha: lit ? 0.95 : 0.35),
                    width: lit ? 2.5 : 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Local copy of the palette so this file does not depend on main.dart.
class AppColorsSignals {
  static const neonGreen = Color(0xFF22C55E);
}
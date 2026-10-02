// MindMaster — native theme (2040 "Neural Core" aesthetic)
import 'package:flutter/material.dart';

class MindTheme {
  // Void black base
  static const bgDeep = Color(0xFF05070A);
  static const bgPanel = Color(0xFF0D121D);
  static const bgGlass = Color(0x1A141A28);

  // Neon accents
  static const neonBlue = Color(0xFF00F3FF);
  static const neonPurple = Color(0xFFBC13FE);
  static const neonGreen = Color(0xFF00FF9D);
  static const neonAmber = Color(0xFFFFAA00);
  static const neonRed = Color(0xFFFF2A6D);

  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF9AA8C7);
  static const textMuted = Color(0xFF5A6A8C);

  /// Subtle border used on glass panels and cells.
  static const borderColor = Color(0x1F6F82B4);

  /// Glassmorphism panel used across the app.
  static BoxDecoration glass({
    double radius = 20,
    Color? border,
    double opacity = 1,
  }) {
    return BoxDecoration(
      color: bgGlass.withValues(alpha: bgGlass.a * opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: border ?? Colors.white.withValues(alpha: 0.10),
        width: 1,
      ),
    );
  }

  /// Screen background: deep void with soft neon radial glows.
  static const screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF05070A), Color(0xFF0B0F16), Color(0xFF06090F)],
  );

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bgDeep,
      colorScheme: base.colorScheme.copyWith(
        primary: neonBlue,
        secondary: neonPurple,
        surface: bgPanel,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// Headline style — wide, techy, uppercase.
  static TextStyle display(double size, {Color color = textPrimary}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: color,
      height: 1.1,
    );
  }
}
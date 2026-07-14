import 'package:flutter/material.dart';

class Appcolors {
  // Background gradients
  static const Color bgDark = Color(0xFF0A0015);
  static const Color bgMid = Color(0xFF1A0533);
  static const Color bgLight = Color(0xFF2D1B69);

  // Accent colors
  static const Color accent = Color(0xFF8B5CF6); // violet
  static const Color accentPink = Color(0xFFEC4899); // pink
  static const Color accentBlue = Color(0xFF06B6D4); // cyan

  // Legacy aliases (keep so existing code compiles)
  static const Color primary = Color(0xFF8B5CF6);
  static Color secondary = const Color(0xFF1A0533);
  static const Color vhite = Colors.white;
  static const Color blurColor = Color(0x60000000);
  static Color black = Colors.white70;
  static const Color grey = Colors.white38;

  // Glass
  static Color glassWhite = Colors.white.withValues(alpha: 0.08);
  static Color glassBorder = Colors.white.withValues(alpha: 0.15);
  static Color glassStrong = Colors.white.withValues(alpha: 0.12);
}
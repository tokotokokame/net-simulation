// lib/app/theme.dart
import 'package:flutter/material.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1565C0),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF1A1A2E),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF16213E),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
);

class AppTheme {
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  static bool isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.width > 600;

  static double iconSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 36;
    if (w < 480) return 44;
    return 52;
  }

  static double fontSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 10;
    if (w < 480) return 12;
    return 14;
  }

  static double palettePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 4;
    if (w < 480) return 8;
    return 12;
  }
}

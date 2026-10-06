import 'package:flutter/material.dart';

import 'models/feeding.dart';

/// Anica palette: 413C58 · A3C4BC · BFD7B5 · E7EFC5 · F2DDA4.
class AppColors {
  static const indigo = Color(0xFF413C58);
  static const sage = Color(0xFFA3C4BC);
  static const mint = Color(0xFFBFD7B5);
  static const cream = Color(0xFFE7EFC5);
  static const sand = Color(0xFFF2DDA4);

  static const primary = indigo;
  static const ink = indigo;
  static const muted = Color(0xFF6F6A85);
  static const background = Color(0xFFF6F8EC);
  static const field = Color(0xFFF3F5EA);
  static const soft = cream;
  static const softBorder = mint;
  static const banner = cream;

  // Feeding types: fills use the palette as is.
  static const breast = indigo;
  static const bottle = sand;
  static const breastMilk = sage;

  static Color forType(FeedingType type) => switch (type) {
        FeedingType.breast => breast,
        FeedingType.bottle => bottle,
        FeedingType.breastMilk => breastMilk,
      };

  /// Text and icons placed on a [forType] fill.
  static Color onType(FeedingType type) =>
      type == FeedingType.breast ? Colors.white : ink;

  /// Deeper steps of the same hues for thin lines, which the pale fills are
  /// too light for on white.
  static Color lineForType(FeedingType type) => switch (type) {
        FeedingType.breast => indigo,
        FeedingType.bottle => const Color(0xFFA87A28),
        FeedingType.breastMilk => const Color(0xFF4F8A7D),
      };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyLarge: TextStyle(color: AppColors.ink),
      bodyMedium: TextStyle(color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

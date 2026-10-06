import 'package:flutter/material.dart';

import 'models/feeding.dart';

class AppColors {
  static const primary = Color(0xFF7F57D1);
  static const ink = Color(0xFF2B2A5A);
  static const muted = Color(0xFF6E6C8A);
  static const background = Color(0xFFF0F0F5);
  static const field = Color(0xFFF1F1F3);
  static const soft = Color(0xFFF0ECFA);
  static const softBorder = Color(0xFFDCD2F3);
  static const banner = Color(0xFFE2DAF5);

  static const breast = Color(0xFF3F2C6E);
  static const bottle = Color(0xFF7F57D1);
  static const breastMilk = Color(0xFF1F9E8F);

  static Color forType(FeedingType type) => switch (type) {
        FeedingType.breast => breast,
        FeedingType.bottle => bottle,
        FeedingType.breastMilk => breastMilk,
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

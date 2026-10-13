import 'package:flutter/material.dart';

import 'models/entry.dart';

/// App palette: 413C58 · A3C4BC · BFD7B5 · E7EFC5 · F2DDA4.
class AppColors {
  static const indigo = Color(0xFF413C58);
  static const sage = Color(0xFFA3C4BC);
  static const mint = Color(0xFFBFD7B5);
  static const cream = Color(0xFFE7EFC5);
  static const sand = Color(0xFFF2DDA4);

  /// A light tint of indigo, for routines.
  static const lavender = Color(0xFFD8D4EA);

  static const primary = indigo;
  static const ink = indigo;
  static const muted = Color(0xFF6F6A85);
  static const background = Color(0xFFF6F8EC);
  static const field = Color(0xFFF1F3E6);
  static const soft = cream;
  static const softBorder = mint;
  static const banner = cream;
  static const divider = Color(0xFFE4E6D8);
  static const danger = Color(0xFFA33A2E);

  /// Fill for each kind of entry: the icon tile, count badge and drawer header.
  static Color forType(EntryType type) => switch (type) {
        EntryType.breast => indigo,
        EntryType.bottle => sand,
        EntryType.breastMilk => sage,
        EntryType.pump => mint,
        EntryType.diaper => cream,
        EntryType.routine => lavender,
        EntryType.other => Colors.white,
      };

  /// Text and icons placed on a [forType] fill.
  static Color onType(EntryType type) => type == EntryType.breast ? Colors.white : ink;

  /// Deeper steps of the same hues for thin lines, which the pale fills are
  /// too light for on white.
  static Color lineForType(EntryType type) => switch (type) {
        EntryType.breast => indigo,
        EntryType.bottle => const Color(0xFFA87A28),
        EntryType.breastMilk => const Color(0xFF4F8A7D),
        EntryType.pump => const Color(0xFF5E8A55),
        EntryType.diaper => const Color(0xFF7D8A3A),
        EntryType.routine || EntryType.other => muted,
      };
}

ThemeData buildTheme() {
  // Every role the Material widgets read is set from the palette, so no
  // generated colour (such as the default lilac) shows anywhere.
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.indigo).copyWith(
    primary: AppColors.indigo,
    onPrimary: Colors.white,
    primaryContainer: AppColors.cream,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.sage,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.mint,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.sand,
    onTertiary: AppColors.ink,
    tertiaryContainer: AppColors.sand,
    onTertiaryContainer: AppColors.ink,
    surface: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: AppColors.field,
    surfaceContainerHigh: Colors.white,
    surfaceContainerHighest: AppColors.field,
    surfaceTint: Colors.transparent,
    outline: AppColors.muted,
    outlineVariant: AppColors.divider,
    inverseSurface: AppColors.indigo,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.sand,
    error: AppColors.danger,
    onError: Colors.white,
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
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.mint,
        selectedForegroundColor: AppColors.ink,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.mint, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.indigo : AppColors.field,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.indigo,
      actionTextColor: AppColors.sand,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white),
  );
}

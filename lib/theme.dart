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

  /// Selected and running states (segments, pills, a timed side). Kept apart
  /// from [primary], which is only for the main action on a screen.
  static const selected = sage;
  static const onSelected = ink;

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

/// The type scale. Every text size in the app comes from here, so the
/// levels stay distinct: headline > title > subtitle > body > label > caption.
class AppText {
  /// The live timer's clock.
  static const display = 56.0;

  /// Timers inside a drawer.
  static const timer = 36.0;

  /// Page, day and drawer titles.
  static const headline = 24.0;

  /// Key figures, such as a trend's value.
  static const title = 20.0;

  /// Section headings, buttons and big choices.
  static const subtitle = 17.0;

  /// Regular text and entry names.
  static const body = 15.0;

  /// Secondary details, hints and times.
  static const label = 13.0;

  /// Tags and chart axes.
  static const caption = 11.0;
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
    fontFamily: 'Heros',
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      titleLarge:
          TextStyle(fontSize: AppText.headline, fontWeight: FontWeight.w800, color: AppColors.ink),
      titleMedium:
          TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyLarge: TextStyle(fontSize: AppText.body, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: AppText.body, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Heros', fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.selected,
        selectedForegroundColor: AppColors.onSelected,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.mint, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Heros', fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.selected : AppColors.field,
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

import 'package:flutter/material.dart';

import 'models/entry.dart';

/// App palette. Main colours: taupe EDDCD2 · mint DBE7E4 · mist D6E2E9, on a
/// linen F0EFEB page, plus a few added steps (lilac, charcoal, steel) where
/// the three are not enough.
///
/// Colour is kept to a few jobs so screens are quick to read:
/// - a calm neutral base: [background] with white cards and charcoal [ink];
/// - one action colour, [primary], for the main button on a screen;
/// - one selection colour, [selected], for anything chosen or running;
/// - one soft colour per group of entries: feeds, pumping, diapers, routines.
class AppColors {
  static const taupe = Color(0xFFEDDCD2);
  static const mint = Color(0xFFDBE7E4);
  static const mist = Color(0xFFD6E2E9);
  static const linen = Color(0xFFF0EFEB);

  /// Added to the main three so routines have their own soft fill.
  static const lilac = Color(0xFFE6E1EE);

  /// Deeper steps of the palette, which is too light for text or for white
  /// text on it.
  static const slate = Color(0xFF263241);
  static const steel = Color(0xFF4F6A7E);

  static const primary = steel;
  static const ink = slate;
  static const muted = Color(0xFF6B7480);
  static const background = linen;

  /// The top of each tab: the page itself, so nothing heavy sits behind the
  /// title.
  static const header = background;

  /// Inset fills inside white cards (chips, idle tiles, steppers).
  static const field = Color(0xFFF5F4F1);
  static const softBorder = mist;
  static const tag = mint;
  static const divider = Color(0xFFE6E4DE);
  static const danger = Color(0xFFA33A2E);

  /// Selected and running states (segments, pills, a timed side). Kept apart
  /// from [primary], which is only for the main action on a screen.
  static const selected = mist;
  static const onSelected = ink;

  /// Fill for each kind of entry: the icon tile and the drawer header. Feeds
  /// share one colour (their icons tell them apart), so the timeline reads
  /// as feeds, pumping, diapers and routines at a glance; Other is white with
  /// an outline.
  static Color forType(EntryType type) => switch (type) {
        EntryType.breast || EntryType.bottle || EntryType.breastMilk => taupe,
        EntryType.pump => mist,
        EntryType.diaper => mint,
        EntryType.routine => lilac,
        EntryType.other => Colors.white,
      };

  /// Kinds drawn as a white tile with an outline.
  static bool outlined(EntryType type) => type == EntryType.other;

  /// Text and icons placed on a [forType] fill.
  static Color onType(EntryType type) => ink;

  /// Deeper steps of the same hues for thin lines, which the pale fills are
  /// too light for on white.
  static Color lineForType(EntryType type) => switch (type) {
        EntryType.breast || EntryType.bottle || EntryType.breastMilk => const Color(0xFFA27B66),
        EntryType.pump => const Color(0xFF5B7C93),
        EntryType.diaper => const Color(0xFF5E8A7C),
        EntryType.routine => const Color(0xFF7A6E94),
        EntryType.other => muted,
      };
}

/// Corner radii: cards, then tiles inside or beside them. Chips and buttons
/// are full pills and entry icons are circles.
class AppRadius {
  static const card = 20.0;
  static const tile = 16.0;
}

/// Soft shadow for the one card on a screen that should stand out (the live
/// timer); everything else sits flat.
const raisedShadow = [
  BoxShadow(color: Color(0x1F263241), blurRadius: 24, offset: Offset(0, 8)),
];

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
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.mist,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.mist,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.mist,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.taupe,
    onTertiary: AppColors.ink,
    tertiaryContainer: AppColors.taupe,
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
    inverseSurface: AppColors.ink,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.mist,
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
        color: AppColors.ink,
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
      backgroundColor: AppColors.ink,
      actionTextColor: AppColors.taupe,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white),
  );
}

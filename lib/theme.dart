import 'package:flutter/material.dart';

import 'models/entry.dart';

/// App palette. Main colours: taupe EDDCD2 · mint DBE7E4 · mist D6E2E9, on a
/// linen F0EFEB page, plus a few added steps (lilac, charcoal, steel) where
/// the three are not enough.
///
/// Colour is kept to a few jobs so screens are quick to read:
/// - a calm neutral base: [background] with [surface] cards and [ink] text;
/// - one action colour, [primary], for the main button on a screen;
/// - one selection colour, [selected], for anything chosen or running;
/// - one soft colour per group of entries: feeds, pumping, diapers, routines.
///
/// Every role has a light and a dark value; [dark] picks between them. The
/// app sets it before building the theme and rebuilds everything when it
/// changes, so widgets simply read the roles.
class AppColors {
  /// Whether the dark palette is in use.
  static bool dark = false;

  static Color _pick(Color light, Color darkValue) => dark ? darkValue : light;

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

  static Color get primary => _pick(steel, const Color(0xFFA9C3D6));
  static Color get onPrimary => _pick(Colors.white, const Color(0xFF14191F));
  static Color get ink => _pick(slate, const Color(0xFFE8ECEF));
  static Color get muted => _pick(const Color(0xFF6B7480), const Color(0xFF9AA4AE));
  static Color get background => _pick(linen, const Color(0xFF15191E));

  /// Cards and sheets.
  static Color get surface => _pick(Colors.white, const Color(0xFF1F252C));

  /// The top of each tab: the page itself, so nothing heavy sits behind the
  /// title.
  static Color get header => background;

  /// Inset fills inside cards (chips, idle tiles, steppers).
  static Color get field => _pick(const Color(0xFFF5F4F1), const Color(0xFF2A3139));
  static Color get softBorder => _pick(mist, const Color(0xFF3A4D5C));
  static Color get tag => _pick(mint, const Color(0xFF33443E));
  static Color get divider => _pick(const Color(0xFFE6E4DE), const Color(0xFF2F363E));
  static Color get danger => _pick(const Color(0xFFA33A2E), const Color(0xFFE58B7F));

  /// Selected and running states (segments, pills, a timed side). Kept apart
  /// from [primary], which is only for the main action on a screen.
  static Color get selected => _pick(mist, const Color(0xFF3A4D5C));
  static Color get onSelected => ink;

  /// Fill for each kind of entry: the icon circle and the drawer header.
  /// Feeds share one colour (their icons tell them apart), so the timeline
  /// reads as feeds, pumping, diapers and routines at a glance; Other is the
  /// card colour with an outline. The pastels stay the same in dark mode.
  static Color forType(EntryType type) => switch (type) {
        EntryType.breast || EntryType.bottle || EntryType.breastMilk => taupe,
        EntryType.pump => mist,
        EntryType.diaper => mint,
        EntryType.routine => lilac,
        EntryType.other => surface,
      };

  /// The band at the top of a drawer or chart sheet. In dark mode a soft tint
  /// of the group colour, so a sheet opened at night doesn't glare.
  static Color headerForType(EntryType type) {
    if (outlined(type)) return field;
    return dark ? Color.lerp(surface, forType(type), 0.22)! : forType(type);
  }

  /// Text and icons on [headerForType].
  static Color onHeaderForType(EntryType type) => dark ? ink : onType(type);

  /// Kinds drawn as a plain tile with an outline.
  static bool outlined(EntryType type) => type == EntryType.other;

  /// Text and icons placed on a [forType] fill: dark on the pastels in both
  /// modes.
  static Color onType(EntryType type) => outlined(type) ? ink : slate;

  /// Deeper (light mode) or brighter (dark mode) steps of the same hues for
  /// thin lines and small icons, which the pastel fills are too soft for.
  static Color lineForType(EntryType type) => switch (type) {
        EntryType.breast ||
        EntryType.bottle ||
        EntryType.breastMilk =>
          _pick(const Color(0xFFA27B66), const Color(0xFFD9B8A6)),
        EntryType.pump => _pick(const Color(0xFF5B7C93), const Color(0xFFA9C3D6)),
        EntryType.diaper => _pick(const Color(0xFF5E8A7C), const Color(0xFFA8CFC2)),
        EntryType.routine => _pick(const Color(0xFF7A6E94), const Color(0xFFB8ADD2)),
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
List<BoxShadow> get raisedShadow => [
      BoxShadow(
        color: AppColors.dark ? const Color(0x66000000) : const Color(0x1F263241),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
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
  final brightness = AppColors.dark ? Brightness.dark : Brightness.light;
  // Every role the Material widgets read is set from the palette, so no
  // generated colour (such as the default lilac) shows anywhere.
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.steel, brightness: brightness).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.selected,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.selected,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.selected,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.taupe,
    onTertiary: AppColors.ink,
    tertiaryContainer: AppColors.taupe,
    onTertiaryContainer: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.field,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.field,
    surfaceTint: Colors.transparent,
    outline: AppColors.muted,
    outlineVariant: AppColors.divider,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.background,
    inversePrimary: AppColors.selected,
    error: AppColors.danger,
    onError: AppColors.onPrimary,
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Heros',
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    textTheme: TextTheme(
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
        foregroundColor: AppColors.onPrimary,
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
        side: BorderSide(color: AppColors.selected, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Heros', fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.surface : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.selected : AppColors.field,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      actionTextColor: AppColors.taupe,
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.surface),
  );
}

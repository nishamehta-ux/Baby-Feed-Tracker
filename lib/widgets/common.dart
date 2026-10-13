import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../theme.dart';
import 'app_logo.dart';

/// White rounded card on the page, lifted slightly in light mode; the live
/// timer is the one raised further.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: cardShadow,
      ),
      child: child,
    );
  }
}

/// Light blue header background with a gently curved bottom edge.
class HeaderBackground extends StatelessWidget {
  const HeaderBackground({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurveClipper(),
      child: Container(height: height, color: AppColors.header),
    );
  }
}

/// The header as a panel that grows with its [child], with the same
/// curved bottom edge as [HeaderBackground].
class HeaderPanel extends StatelessWidget {
  const HeaderPanel({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurveClipper(),
      child: Container(
        width: double.infinity,
        color: AppColors.header,
        padding: padding,
        child: child,
      ),
    );
  }
}

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 10)
    ..quadraticBezierTo(size.width / 2, size.height + 18, size.width, size.height - 10)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Icon for each kind of entry.
IconData iconForType(EntryType type) => switch (type) {
      EntryType.breast => Icons.favorite_rounded,
      EntryType.bottle => Icons.local_drink_rounded,
      EntryType.breastMilk => Icons.water_drop_rounded,
      EntryType.pump => Icons.opacity_rounded,
      EntryType.diaper => Icons.baby_changing_station_rounded,
      EntryType.routine => Icons.wb_sunny_rounded,
      EntryType.other => Icons.edit_note_rounded,
    };

/// A circle in the entry's colour with its icon. [icon] overrides the
/// type's own icon, e.g. a bath tub for a Bath routine.
class EntryIcon extends StatelessWidget {
  const EntryIcon({super.key, required this.type, this.size = medium, this.icon});

  /// The three sizes in use: inline with text (chips, card headers), in
  /// tiles and the timeline, and leading a list row.
  static const small = 28.0;
  static const medium = 36.0;
  static const large = 44.0;

  final EntryType type;
  final double size;
  final IconData? icon;

  /// Solid glyphs that fill their whole box (the heart) look bigger than the
  /// rest at the same size, so they are drawn a little smaller.
  static double opticalScale(IconData glyph) => glyph == Icons.favorite_rounded ? 0.84 : 1;

  @override
  Widget build(BuildContext context) {
    final glyph = icon ?? iconForType(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forType(type),
        shape: BoxShape.circle,
        border: AppColors.outlined(type) ? Border.all(color: AppColors.ink, width: 1.25) : null,
      ),
      child: Icon(glyph, color: AppColors.onType(type), size: size * 0.5 * opticalScale(glyph)),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.field,
        disabledBackgroundColor: AppColors.field.withValues(alpha: 0.5),
        foregroundColor: AppColors.ink,
        disabledForegroundColor: AppColors.muted.withValues(alpha: 0.5),
      ),
    );
  }
}

/// A small heading for a section on the page, e.g. "Quick add".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: AppText.label,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.muted,
      ),
    );
  }
}

/// The baby's photo in a circle, or the app's mark when there is none.
class BabyAvatar extends StatelessWidget {
  const BabyAvatar({super.key, required this.photo, this.size = 40});

  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Behind the mark when there's no photo: a colour the taupe face shows on.
        color: AppColors.dark ? AppColors.forType(EntryType.breast) : AppColors.mist,
        border: Border.all(color: AppColors.surface, width: size > 60 ? 4 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: AppMark(size: size * 0.64),
            )
          : Image.memory(photo!, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

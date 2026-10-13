import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../theme.dart';

/// White rounded card that sits on top of the indigo header.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// Indigo background with a gently curved bottom edge, as in the design.
class HeaderBackground extends StatelessWidget {
  const HeaderBackground({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurveClipper(),
      child: Container(height: height, color: AppColors.primary),
    );
  }
}

/// The indigo header as a panel that grows with its [child], with the same
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
        color: AppColors.primary,
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

/// A rounded tile in the entry's colour with its icon. [icon] overrides the
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forType(type),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: type == EntryType.other ? Border.all(color: AppColors.ink, width: 1.25) : null,
      ),
      child: Icon(icon ?? iconForType(type), color: AppColors.onType(type), size: size * 0.5),
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

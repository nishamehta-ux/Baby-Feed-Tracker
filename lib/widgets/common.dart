import 'package:flutter/material.dart';

import '../models/feeding.dart';
import '../models/summary.dart';
import '../theme.dart';

/// White rounded card that sits on top of the purple header.
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

class TotalChip extends StatelessWidget {
  const TotalChip({super.key, required this.type, required this.label});

  final FeedingType type;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.forType(type),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.onType(type),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TotalsRow extends StatelessWidget {
  const TotalsRow({super.key, required this.totals});

  final FeedingTotals totals;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TotalChip(
          type: FeedingType.breast,
          label: 'Breastfeeding: ${formatDuration(totals.breast)}',
        ),
        TotalChip(
          type: FeedingType.bottle,
          label: 'Formula: ${totals.bottleMl} ml',
        ),
        TotalChip(
          type: FeedingType.breastMilk,
          label: 'Breast milk: ${totals.breastMilkMl} ml',
        ),
      ],
    );
  }
}

class FeedingTypeIcon extends StatelessWidget {
  const FeedingTypeIcon({super.key, required this.type, this.size = 40});

  final FeedingType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      FeedingType.breast => Icons.favorite_rounded,
      FeedingType.bottle => Icons.local_drink_rounded,
      FeedingType.breastMilk => Icons.water_drop_rounded,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forType(type),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.onType(type), size: size * 0.5),
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
        backgroundColor: const Color(0xFFEDEDF2),
        disabledBackgroundColor: const Color(0xFFF4F4F7),
        foregroundColor: AppColors.ink,
        disabledForegroundColor: const Color(0xFFB0AFC3),
      ),
    );
  }
}

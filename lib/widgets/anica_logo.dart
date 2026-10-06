import 'package:flutter/material.dart';

import '../theme.dart';

/// The Anica mark: a drop of milk with a heart in it.
/// Matches assets/branding/anica_mark.svg.
class AnicaMark extends StatelessWidget {
  const AnicaMark({super.key, this.size = 32, this.heartColor = AppColors.indigo});

  final double size;

  /// The heart reads as a cut-out, so it takes the colour behind the mark.
  final Color heartColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(heartColor)),
    );
  }
}

/// Mark plus the "anica" wordmark, for use on the indigo header.
class AnicaLogo extends StatelessWidget {
  const AnicaLogo({super.key, this.height = 28, this.color = Colors.white});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Anica',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnicaMark(size: height),
            SizedBox(width: height * 0.25),
            Text(
              'anica',
              style: TextStyle(
                color: color,
                fontSize: height * 0.9,
                fontWeight: FontWeight.w800,
                fontVariations: const [FontVariation('wght', 800)],
                letterSpacing: 0.2,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.heartColor);

  final Color heartColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 100 x 100 grid, same as the SVG.
    canvas.scale(size.width / 100, size.height / 100);

    final drop = Path()
      ..moveTo(50, 6)
      ..cubicTo(50, 6, 18, 42, 18, 64)
      ..arcToPoint(const Offset(82, 64), radius: const Radius.circular(32), clockwise: false)
      ..cubicTo(82, 42, 50, 6, 50, 6)
      ..close();
    canvas.drawPath(drop, Paint()..color = AppColors.sand);

    final heart = Path()
      ..moveTo(50, 82)
      ..cubicTo(35, 72, 36, 58, 44, 58)
      ..cubicTo(47, 58, 49, 60, 50, 62.5)
      ..cubicTo(51, 60, 53, 58, 56, 58)
      ..cubicTo(64, 58, 65, 72, 50, 82)
      ..close();
    canvas.drawPath(heart, Paint()..color = heartColor);

    // Soft highlight on the drop.
    canvas.drawCircle(const Offset(35, 47), 4.5, Paint()..color = AppColors.cream);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.heartColor != heartColor;
}

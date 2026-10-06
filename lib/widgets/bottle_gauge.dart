import 'package:flutter/material.dart';

import '../theme.dart';

/// Baby bottle illustration with graduations. The fill follows [amountMl];
/// dragging vertically on the bottle changes the amount.
class BottleGauge extends StatelessWidget {
  const BottleGauge({
    super.key,
    required this.amountMl,
    required this.onChanged,
    this.fillColor = AppColors.cream,
    this.maxMl = 250,
  });

  final Color fillColor;
  final int amountMl;
  final int maxMl;
  final ValueChanged<int> onChanged;

  static const _height = 300.0;

  void _update(double dy) {
    final geometry = _BottleGeometry(const Size(200, _height));
    final ratio = (geometry.bottom - dy) / (geometry.bottom - geometry.top);
    final ml = (ratio * maxMl / 5).round() * 5;
    onChanged(ml.clamp(0, maxMl));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onVerticalDragUpdate: (d) => _update(d.localPosition.dy),
        onTapDown: (d) => _update(d.localPosition.dy),
        child: SizedBox(
          width: 200,
          height: _height,
          child: CustomPaint(
            painter: _BottlePainter(amountMl: amountMl, maxMl: maxMl, fillColor: fillColor),
          ),
        ),
      ),
    );
  }
}

class _BottleGeometry {
  _BottleGeometry(this.size);

  final Size size;

  /// y-coordinate for 0 ml and for maxMl.
  double get bottom => size.height - 34;
  double get top => 24;
}

class _BottlePainter extends CustomPainter {
  _BottlePainter({required this.amountMl, required this.maxMl, required this.fillColor});

  final Color fillColor;
  final int amountMl;
  final int maxMl;

  Path _outline(Size s) {
    final w = s.width;
    final h = s.height;
    return Path()
      ..moveTo(w * 0.17, 0)
      ..lineTo(w * 0.16, h * 0.30)
      ..cubicTo(w * 0.15, h * 0.45, w * 0.02, h * 0.60, w * 0.02, h * 0.80)
      ..quadraticBezierTo(w * 0.02, h, w * 0.22, h)
      ..lineTo(w * 0.78, h)
      ..quadraticBezierTo(w * 0.98, h, w * 0.98, h * 0.80)
      ..cubicTo(w * 0.98, h * 0.60, w * 0.85, h * 0.45, w * 0.84, h * 0.30)
      ..lineTo(w * 0.83, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = _BottleGeometry(size);
    final outline = _outline(size);
    final closed = Path.from(outline)..close();

    double yFor(num ml) => g.bottom - (g.bottom - g.top) * (ml / maxMl);

    // Milk.
    final level = yFor(amountMl.clamp(0, maxMl));
    canvas.save();
    canvas.clipPath(closed);
    canvas.drawRect(
      Rect.fromLTRB(0, level, size.width, size.height),
      Paint()..color = fillColor,
    );
    canvas.drawLine(
      Offset(0, level),
      Offset(size.width, level),
      Paint()
        ..color = AppColors.breast
        ..strokeWidth = 2,
    );
    canvas.restore();

    // Outline.
    canvas.drawPath(
      outline,
      Paint()
        ..color = AppColors.breast
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Graduations every 12.5 ml, labels every 25 ml.
    final tick = Paint()
      ..color = AppColors.breast
      ..strokeWidth = 2.5;
    final tickX = size.width * 0.58;
    for (var ml = 12.5; ml <= maxMl; ml += 12.5) {
      final y = yFor(ml);
      final major = ml % 25 == 0;
      canvas.drawLine(
        Offset(tickX - (major ? 6 : 0), y),
        Offset(tickX + 12, y),
        tick,
      );
      if (major) {
        final tp = TextPainter(
          text: TextSpan(
            text: ml.toInt().toString(),
            style: const TextStyle(color: AppColors.ink, fontSize: 13),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(tickX - 14 - tp.width, y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_BottlePainter old) =>
      old.amountMl != amountMl || old.maxMl != maxMl || old.fillColor != fillColor;
}

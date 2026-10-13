import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tiny trend line without axes; the last point is marked with a dot.
///
/// [values] are evenly spaced, oldest first; null leaves a gap at the start
/// (before anything was logged) and counts as zero after that.
/// [zeroBased] scales from zero, right for amounts and counts, so small
/// wobbles stay small; readings such as weight scale between their lowest and
/// highest value instead.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.zeroBased = true,
    this.width = 88,
  });

  final List<double?> values;
  final Color color;
  final bool zeroBased;
  final double width;

  @override
  Widget build(BuildContext context) {
    final first = values.indexWhere((v) => v != null);
    final points = first < 0 ? <double>[] : [for (final v in values.skip(first)) v ?? 0];
    return SizedBox(
      width: width,
      height: 36,
      child: points.length < 2
          ? const SizedBox.shrink()
          : CustomPaint(painter: _SparklinePainter(points, color, values.length, zeroBased)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points, this.color, this.slots, this.zeroBased);

  final List<double> points;
  final Color color;
  final int slots;
  final bool zeroBased;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final maxV = points.fold<double>(points.first, math.max);
    final minV = zeroBased ? 0.0 : points.fold<double>(points.first, math.min);
    final span = maxV - minV;
    final step = (size.width - 2 * pad) / (slots - 1);
    final offset = slots - points.length; // right-align to the latest point

    Offset at(int i) {
      final x = pad + step * (i + offset);
      final t = span == 0 ? (zeroBased && maxV == 0 ? 0.0 : 0.5) : (points[i] - minV) / span;
      return Offset(x, size.height - pad - t * (size.height - 2 * pad));
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final end = at(points.length - 1);
    canvas.drawCircle(end, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(end, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color || old.zeroBased != zeroBased;
}

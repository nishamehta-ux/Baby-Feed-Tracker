import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/trends.dart';
import '../theme.dart';

/// A line chart of one series over time, placed by date. Tap or drag across
/// it to read a point; the latest point is labelled until then.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.color,
    required this.format,
    this.zeroBased = true,
    this.height = 220,
  });

  /// Oldest first.
  final List<TrendPoint> points;
  final Color color;

  /// Formats a value for the axis and labels ("290 ml", "3.9 kg").
  final String Function(double) format;

  /// Scale from zero (amounts, counts) or between the lowest and highest
  /// value (readings such as weight).
  final bool zeroBased;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return SizedBox(height: widget.height);
    final sel = _selected != null && _selected! < points.length ? _selected : null;
    final shown = points[sel ?? points.length - 1];

    return Semantics(
      label: 'Chart. ${[
        for (final p in points) '${DateFormat('d MMM').format(p.at)}: ${widget.format(p.value)}',
      ].join(', ')}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, widget.height);
          final painter = _ChartPainter(
            points: points,
            color: widget.color,
            format: widget.format,
            zeroBased: widget.zeroBased,
            selected: sel,
          );
          void pick(Offset p) => setState(() => _selected = painter.nearest(p, size));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The readout sits above the plot, so it never covers the line.
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: widget.format(shown.value),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text: '  ${DateFormat('EEE d MMM yyyy').format(shown.at)}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
                style: const TextStyle(color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => pick(d.localPosition),
                onHorizontalDragUpdate: (d) => pick(d.localPosition),
                child: CustomPaint(size: size, painter: painter),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.color,
    required this.format,
    required this.zeroBased,
    required this.selected,
  });

  final List<TrendPoint> points;
  final Color color;
  final String Function(double) format;
  final bool zeroBased;
  final int? selected;

  static const _axisWidth = 64.0;
  static const _labelBand = 24.0;
  static const _topPad = 12.0;
  static const _sidePad = 10.0;

  /// Clean axis ticks covering every value.
  List<double> get _ticks {
    var lo = points.map((p) => p.value).reduce(math.min);
    var hi = points.map((p) => p.value).reduce(math.max);
    if (zeroBased) lo = math.min(0, lo);
    if (hi == lo) {
      final pad = hi == 0 ? 1.0 : hi.abs() * 0.05;
      lo -= zeroBased ? 0 : pad;
      hi += pad;
    }
    final rough = (hi - lo) / 3;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final step = [1, 2, 2.5, 5, 10].map((m) => m * mag).firstWhere((s) => s >= rough);
    final start = (lo / step).floor() * step;
    final end = (hi / step).ceil() * step;
    return [for (var t = start; t <= end + step / 2; t += step) t];
  }

  double _x(DateTime at, Size size) {
    final first = points.first.at.millisecondsSinceEpoch;
    final last = points.last.at.millisecondsSinceEpoch;
    final left = _axisWidth + _sidePad, width = size.width - left - _sidePad;
    if (first == last) return left + width / 2;
    return left + width * (at.millisecondsSinceEpoch - first) / (last - first);
  }

  int? nearest(Offset p, Size size) {
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      if ((p.dx - _x(points[i].at, size)).abs() < (p.dx - _x(points[best].at, size)).abs()) {
        best = i;
      }
    }
    return best;
  }

  TextPainter _text(String s, {Color c = AppColors.muted, FontWeight? w}) => TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontSize: 11, color: c, fontWeight: w)),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final ticks = _ticks;
    final lo = ticks.first, hi = ticks.last;
    final base = size.height - _labelBand;
    double y(double v) => base - (base - _topPad) * (v - lo) / (hi - lo);

    // Recessive hairline grid with value labels.
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (final t in ticks) {
      canvas.drawLine(Offset(_axisWidth, y(t)), Offset(size.width, y(t)), grid);
      final tp = _text(t == 0 && zeroBased ? '0' : format(t));
      tp.paint(canvas, Offset(_axisWidth - 8 - tp.width, y(t) - tp.height / 2));
    }

    // Date labels: first, last, and the middle when there is room.
    final dateFmt = DateFormat('d MMM');
    final labelled = {0, points.length - 1, if (points.length > 4) points.length ~/ 2};
    for (final i in labelled) {
      final tp = _text(dateFmt.format(points[i].at));
      final x = (_x(points[i].at, size) - tp.width / 2).clamp(_axisWidth, size.width - tp.width);
      tp.paint(canvas, Offset(x, base + 6));
    }

    final sel = selected;
    if (sel != null) {
      final x = _x(points[sel].at, size);
      canvas.drawLine(
        Offset(x, _topPad),
        Offset(x, base),
        Paint()
          ..color = AppColors.muted.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    final pts = [for (final p in points) Offset(_x(p.at, size), y(p.value))];
    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
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
    }

    // Dots with a white ring; every point when there are few, else only the
    // latest and the selected one.
    final dotAll = pts.length <= 16;
    for (var i = 0; i < pts.length; i++) {
      final isKey = i == pts.length - 1 || i == sel;
      if (!dotAll && !isKey) continue;
      canvas.drawCircle(pts[i], isKey ? 7 : 6, Paint()..color = Colors.white);
      canvas.drawCircle(pts[i], isKey ? 5 : 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points || old.selected != selected || old.color != color;
}

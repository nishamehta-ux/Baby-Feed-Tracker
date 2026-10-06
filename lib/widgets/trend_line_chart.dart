import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// One line on a [TrendLineChart].
class TrendSeries {
  const TrendSeries({
    required this.name,
    required this.color,
    required this.values,
    required this.average,
    required this.previousAverage,
  });

  final String name;
  final Color color;

  /// One value per point, oldest first. May be shorter than the chart's labels:
  /// the remaining points haven't happened yet.
  final List<double> values;

  /// This week's daily average and last week's (null when it had no data).
  final double average;
  final double? previousAverage;
}

/// Line chart sharing one unit across its series. The legend doubles as the
/// readout: it shows this week's average and the change on last week, or the
/// values for a tapped point.
class TrendLineChart extends StatefulWidget {
  const TrendLineChart({
    super.key,
    required this.title,
    required this.series,
    required this.labels,
    required this.format,
    required this.describePoint,
    this.lastPointPartial = false,
  });

  final String title;
  final List<TrendSeries> series;

  /// X-axis labels; may contain a line break.
  final List<String> labels;
  final String Function(double value) format;

  /// Heading shown above the values when point [i] is tapped.
  final String Function(int i) describePoint;

  /// The last point is still in progress (today), so it's drawn hollow with a
  /// dashed segment leading to it.
  final bool lastPointPartial;

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  int? _selected;

  @override
  void didUpdateWidget(TrendLineChart old) {
    super.didUpdateWidget(old);
    if (old.labels.length != widget.labels.length) _selected = null;
  }

  String _change(TrendSeries s) {
    final prev = s.previousAverage;
    if (prev == null || prev <= 0) return 'no data last week';
    final change = (s.average - prev) / prev * 100;
    if (change.abs() < 1) return 'same as last week';
    final pct = change.abs().round();
    return change > 0 ? 'up $pct% on last week' : 'down $pct% on last week';
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final sel = _selected;
    final points = w.series.fold<int>(0, (n, s) => math.max(n, s.values.length));
    final hasData = w.series.any((s) => s.values.any((v) => v > 0));

    final semantics = [
      for (final s in w.series)
        '${s.name}: ${[
          for (var i = 0; i < s.values.length; i++)
            '${w.labels[i].replaceAll('\n', ' ')} ${w.format(s.values[i])}',
        ].join(', ')}',
    ].join('. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          w.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          sel == null
              ? 'This week, average per day'
              : w.describePoint(sel) +
                  (w.lastPointPartial && sel == points - 1 ? ' (so far)' : ''),
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        for (final s in w.series)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(width: 14, height: 3, color: s.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${s.name}  '),
                        TextSpan(
                          text: w.format(
                            sel == null
                                ? s.average
                                : (sel < s.values.length ? s.values[sel] : 0),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (sel == null)
                          TextSpan(
                            text: '  ·  ${_change(s)}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Semantics(
          label: '${w.title}. $semantics',
          child: SizedBox(
            height: 150,
            child: hasData
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final painter = _LinePainter(
                        series: w.series,
                        labels: w.labels,
                        format: w.format,
                        selected: sel,
                        lastPointPartial: w.lastPointPartial,
                      );
                      void pick(Offset p, {bool toggle = false}) {
                        final i = painter.indexAt(p, constraints.biggest, points);
                        setState(() {
                          _selected = (i == null || (toggle && i == _selected)) ? null : i;
                        });
                      }

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => pick(d.localPosition, toggle: true),
                        onHorizontalDragUpdate: (d) => pick(d.localPosition),
                        child: CustomPaint(size: constraints.biggest, painter: painter),
                      );
                    },
                  )
                : const Center(
                    child: Text(
                      'Nothing logged in this period',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.series,
    required this.labels,
    required this.format,
    required this.selected,
    required this.lastPointPartial,
  });

  final List<TrendSeries> series;
  final List<String> labels;
  final String Function(double) format;
  final int? selected;
  final bool lastPointPartial;

  static const _axisWidth = 46.0;
  static const _labelBand = 30.0; // x labels below the baseline (up to 2 lines)
  static const _topPad = 8.0;
  static const _sidePad = 10.0; // keeps end points' dots inside the canvas

  /// Rounds up to a clean axis maximum with two intervals.
  double get _niceMax {
    var max = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        max = math.max(max, v);
      }
    }
    if (max <= 0) return 1;
    final rough = max / 2;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final step = [1, 2, 2.5, 5, 10].map((m) => m * mag).firstWhere((s) => s >= rough);
    return step * 2;
  }

  double _xFor(int i, Size size) {
    final left = _axisWidth + _sidePad;
    final width = size.width - left - _sidePad;
    return labels.length == 1 ? left + width / 2 : left + width * i / (labels.length - 1);
  }

  int? indexAt(Offset p, Size size, int points) {
    if (points == 0) return null;
    var best = 0;
    for (var i = 1; i < points; i++) {
      if ((p.dx - _xFor(i, size)).abs() < (p.dx - _xFor(best, size)).abs()) best = i;
    }
    return best;
  }

  TextPainter _text(String s, {double size = 10.5, Color c = AppColors.muted, FontWeight? w}) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: c, fontWeight: w, height: 1.15),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height - _labelBand;
    final plotH = base - _topPad;
    final top = _niceMax;
    double yFor(double v) => base - plotH * (v / top);

    // Recessive hairline grid with clean tick labels.
    final grid = Paint()
      ..color = const Color(0xFFE6E4EE)
      ..strokeWidth = 1;
    for (final t in [0.0, top / 2, top]) {
      final y = yFor(t);
      canvas.drawLine(Offset(_axisWidth, y), Offset(size.width, y), grid);
      final tp = _text(t == 0 ? '0' : format(t), size: 10);
      tp.paint(canvas, Offset(_axisWidth - 6 - tp.width, y - tp.height / 2));
    }

    final sel = selected;
    for (var i = 0; i < labels.length; i++) {
      final isSel = sel == i;
      final tp = _text(
        labels[i],
        c: isSel ? AppColors.ink : AppColors.muted,
        w: isSel ? FontWeight.w700 : null,
      );
      tp.paint(canvas, Offset(_xFor(i, size) - tp.width / 2, base + 4));
    }

    if (sel != null) {
      final x = _xFor(sel, size);
      canvas.drawLine(
        Offset(x, _topPad),
        Offset(x, base),
        Paint()
          ..color = AppColors.muted.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    for (final s in series) {
      final n = s.values.length;
      if (n == 0) continue;
      final pts = [for (var i = 0; i < n; i++) Offset(_xFor(i, size), yFor(s.values[i]))];
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final solidCount = lastPointPartial && n > 1 ? n - 1 : n;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < solidCount; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, line);
      if (solidCount < n) _dashed(canvas, pts[n - 2], pts[n - 1], line);

      // Every point gets a dot with a surface ring (there are at most 8).
      for (var i = 0; i < n; i++) {
        final partial = lastPointPartial && i == n - 1;
        canvas.drawCircle(pts[i], sel == i ? 7 : 6, Paint()..color = Colors.white);
        canvas.drawCircle(
          pts[i],
          sel == i ? 5 : 4,
          partial
              ? (Paint()
                ..color = s.color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2)
              : (Paint()..color = s.color),
        );
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, total), paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.series != series ||
      old.labels != labels ||
      old.selected != selected ||
      old.lastPointPartial != lastPointPartial;
}

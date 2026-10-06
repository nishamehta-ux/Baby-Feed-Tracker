import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Column chart of one measure over time (days of a week, or weeks), with a
/// headline comparing this week's daily average to last week's.
/// Tap a column to see its value.
class WeeklyTrendChart extends StatefulWidget {
  const WeeklyTrendChart({
    super.key,
    required this.title,
    required this.color,
    required this.values,
    required this.labels,
    required this.average,
    required this.previousAverage,
    required this.format,
  });

  final String title;
  final Color color;

  /// One value per column. May be shorter than [labels]: later columns are
  /// days that haven't happened yet and stay empty.
  final List<double> values;
  final List<String> labels;

  /// This week's daily average and last week's (null when it had no data).
  final double average;
  final double? previousAverage;
  final String Function(double value) format;

  @override
  State<WeeklyTrendChart> createState() => _WeeklyTrendChartState();
}

class _WeeklyTrendChartState extends State<WeeklyTrendChart> {
  int? _selected;

  @override
  void didUpdateWidget(WeeklyTrendChart old) {
    super.didUpdateWidget(old);
    if (old.labels.length != widget.labels.length) _selected = null;
  }

  String _comparison() {
    final prev = widget.previousAverage;
    if (prev == null || prev <= 0) return 'No data last week to compare';
    final change = (widget.average - prev) / prev * 100;
    if (change.abs() < 1) return 'Same as last week';
    final pct = change.abs().round();
    return change > 0 ? 'Up $pct% on last week' : 'Down $pct% on last week';
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final hasData = w.values.any((v) => v > 0);

    final semantics = [
      for (var i = 0; i < w.values.length; i++)
        '${w.labels[i].replaceAll('\n', ' ')}: ${w.format(w.values[i])}',
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: w.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                w.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'This week: ${w.format(w.average)} a day',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
              TextSpan(
                text: '  ·  ${_comparison()}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: '${w.title}. $semantics',
          child: SizedBox(
            height: 144,
            child: hasData
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final painter = _ColumnsPainter(
                        values: w.values,
                        labels: w.labels,
                        color: w.color,
                        format: w.format,
                        selected: _selected,
                      );
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) {
                          final i = painter.indexAt(d.localPosition, constraints.biggest);
                          setState(() => _selected = (i == null || i == _selected) ? null : i);
                        },
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

class _ColumnsPainter extends CustomPainter {
  _ColumnsPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.format,
    required this.selected,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final String Function(double) format;
  final int? selected;

  static const _axisWidth = 44.0;
  static const _labelBand = 30.0; // x labels below the baseline (up to 2 lines)
  static const _topPad = 18.0; // room for a value label above the tallest column
  static const _maxBar = 24.0;

  /// Rounds up to a clean axis maximum with two intervals.
  double get _niceMax {
    final max = values.fold<double>(0, math.max);
    if (max <= 0) return 1;
    final rough = max / 2;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final step = [1, 2, 2.5, 5, 10].map((m) => m * mag).firstWhere((s) => s >= rough);
    return step * 2;
  }

  double _slot(Size size) => (size.width - _axisWidth) / labels.length;

  int? indexAt(Offset p, Size size) {
    if (p.dx < _axisWidth) return null;
    final i = ((p.dx - _axisWidth) / _slot(size)).floor();
    return i >= 0 && i < values.length && values[i] > 0 ? i : null;
  }

  TextPainter _text(String s, {double size = 11, Color c = AppColors.muted, FontWeight? w}) =>
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

    final slot = _slot(size);
    final barW = math.min(_maxBar, slot - 8);

    // Label only the peak, the latest column and the tapped column.
    var peak = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[peak]) peak = i;
    }
    final sel = selected;
    final labelled = {peak, values.length - 1, if (sel != null) sel};

    for (var i = 0; i < labels.length; i++) {
      final cx = _axisWidth + slot * i + slot / 2;
      final isSel = sel == i;
      final label = _text(
        labels[i],
        size: 10.5,
        c: isSel ? AppColors.ink : AppColors.muted,
        w: isSel ? FontWeight.w700 : null,
      );
      label.paint(canvas, Offset(cx - label.width / 2, base + 4));

      if (i >= values.length || values[i] <= 0) continue;
      final y = yFor(values[i]);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - barW / 2, y, cx + barW / 2, base),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      final dim = sel != null && !isSel;
      canvas.drawRRect(rect, Paint()..color = dim ? color.withValues(alpha: 0.45) : color);

      if (labelled.contains(i)) {
        final tp = _text(format(values[i]), c: AppColors.ink, w: FontWeight.w600);
        final x = (cx - tp.width / 2).clamp(_axisWidth, size.width - tp.width);
        tp.paint(canvas, Offset(x, y - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(_ColumnsPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.selected != selected ||
      old.color != color;
}

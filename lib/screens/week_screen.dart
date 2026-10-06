import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/feeding_store.dart';
import '../models/feeding.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';

/// Weekly summary: the average per day for each feeding type, how it compares
/// with last week, a small 8-week trend line, and a list of the days.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.store, required this.onOpenDay});

  final FeedingStore store;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  DateTime _weekStart = startOfWeek(DateTime.now());

  DateTime get _today => dateOnly(DateTime.now());

  void _shift(int weeks) {
    setState(() {
      _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7 * weeks);
    });
  }

  /// Totals for the week starting [ws], divided by the days it covers. In the
  /// current week only finished days count, so today's partial total doesn't
  /// drag the average down (on a Monday, today is all there is).
  _WeekAverage _averageFor(DateTime ws) {
    final feedings = feedingsInWeek(widget.store.feedings, ws);
    if (ws != startOfWeek(_today)) return _WeekAverage(FeedingTotals.of(feedings), 7);
    final elapsed = _today.difference(ws).inDays + 1;
    if (elapsed == 1) return _WeekAverage(FeedingTotals.of(feedings), 1);
    return _WeekAverage(
      FeedingTotals.of(feedings.where((f) => !isSameDay(f.start, _today))),
      elapsed - 1,
    );
  }

  String _rangeLabel(DateTime start) {
    final end = DateTime(start.year, start.month, start.day + 6);
    final startFmt = start.month == end.month ? DateFormat('d') : DateFormat('d MMM');
    return '${startFmt.format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => SingleChildScrollView(
        child: Stack(
          children: [
            const HeaderBackground(height: 340),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(),
                    const SizedBox(height: 20),
                    Text(
                      'Weekly summary',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    _buildCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final ws = _weekStart;
    final isCurrentWeek = ws == startOfWeek(_today);
    final elapsed = isCurrentWeek ? _today.difference(ws).inDays + 1 : 7;

    // The last 8 weeks, oldest first; the final entry is the week on screen.
    final history = [
      for (var k = 7; k >= 0; k--) _averageFor(DateTime(ws.year, ws.month, ws.day - 7 * k)),
    ];
    final thisWeek = history.last;
    final lastWeek = history[history.length - 2];

    Widget row(FeedingType type, String name, double Function(FeedingTotals) measure,
            String Function(double) format) =>
        _AverageRow(
          type: type,
          name: name,
          value: format(thisWeek.of(measure)),
          change: lastWeek.isEmpty ? null : _change(thisWeek.of(measure), lastWeek.of(measure)),
          trend: [for (final w in history) w.isEmpty ? null : w.of(measure)],
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrentWeek ? 'This week' : 'Week of ${DateFormat('d MMM').format(ws)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _rangeLabel(ws),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous week',
                onPressed: () => _shift(-1),
              ),
              const SizedBox(width: 4),
              RoundIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Next week',
                onPressed: isCurrentWeek ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Average per day', style: Theme.of(context).textTheme.titleMedium),
          if (isCurrentWeek && elapsed > 1)
            const Text(
              "Today is added once it's over.",
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          const SizedBox(height: 8),
          row(FeedingType.breast, 'Breastfeeding', (t) => t.breast.inSeconds / 60,
              (v) => formatDuration(Duration(minutes: v.round()))),
          row(FeedingType.bottle, 'Formula', (t) => t.bottleMl.toDouble(),
              (v) => '${v.round()} ml'),
          row(FeedingType.breastMilk, 'Breast milk by bottle', (t) => t.breastMilkMl.toDouble(),
              (v) => '${v.round()} ml'),
          const SizedBox(height: 4),
          const Text(
            'The small lines show the last 8 weeks.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Text('Each day', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (var i = elapsed - 1; i >= 0; i--)
            _DayRow(
              day: DateTime(ws.year, ws.month, ws.day + i),
              totals: FeedingTotals.of(
                feedingsOnDay(widget.store.feedings, DateTime(ws.year, ws.month, ws.day + i)),
              ),
              onTap: () => widget.onOpenDay(DateTime(ws.year, ws.month, ws.day + i)),
            ),
        ],
      ),
    );
  }

  String _change(double now, double before) {
    if (before <= 0) return now > 0 ? 'New this week' : 'Same as last week';
    final pct = ((now - before) / before * 100).round();
    if (pct == 0) return 'Same as last week';
    return pct > 0 ? 'Up $pct% on last week' : 'Down ${-pct}% on last week';
  }
}

/// Totals for one week and the number of days they cover.
class _WeekAverage {
  const _WeekAverage(this.totals, this.days);

  final FeedingTotals totals;
  final int days;

  bool get isEmpty => totals.count == 0;

  double of(double Function(FeedingTotals t) measure) => measure(totals) / days;
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({
    required this.type,
    required this.name,
    required this.value,
    required this.change,
    required this.trend,
  });

  final FeedingType type;
  final String name;
  final String value;
  final String? change;

  /// Weekly averages, oldest first; null for weeks with nothing logged.
  final List<double?> trend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          FeedingTypeIcon(type: type, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  change ?? 'Nothing logged last week',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Sparkline(values: trend, color: AppColors.lineForType(type)),
        ],
      ),
    );
  }
}

/// Tiny trend line without axes; the last point is marked with a dot.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double?> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Start the line at the first week with data.
    final first = values.indexWhere((v) => v != null);
    final points = first < 0 ? <double>[] : [for (final v in values.skip(first)) v ?? 0];
    return SizedBox(
      width: 88,
      height: 36,
      child: points.length < 2
          ? const SizedBox.shrink()
          : CustomPaint(painter: _SparklinePainter(points, color, values.length)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points, this.color, this.slots);

  final List<double> points;
  final Color color;
  final int slots;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    // Scaled from zero, so small week-to-week wobbles stay small.
    final maxV = points.fold<double>(0, math.max);
    final step = (size.width - 2 * pad) / (slots - 1);
    final offset = slots - points.length; // right-align to "this week"

    Offset at(int i) {
      final x = pad + step * (i + offset);
      final t = maxV == 0 ? 0.0 : points[i] / maxV;
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
  bool shouldRepaint(_SparklinePainter old) => old.points != points || old.color != color;
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.totals, required this.onTap});

  final DateTime day;
  final FeedingTotals totals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (totals.breast > Duration.zero) formatDuration(totals.breast),
      if (totals.bottleMl > 0) '${totals.bottleMl} ml formula',
      if (totals.breastMilkMl > 0) '${totals.breastMilkMl} ml breast milk',
    ];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                DateFormat('EEE d MMM').format(day),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                totals.count == 0 ? 'Nothing logged' : details.join(' · '),
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

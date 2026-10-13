import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/entry_store.dart';
import '../models/entry.dart';
import '../models/summary.dart';
import '../models/trends.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import '../widgets/presets.dart';
import '../widgets/sparkline.dart';
import 'trend_sheet.dart';

/// Trends: for the week on screen, the average per day of feeds, pumping and
/// diapers and how often each routine happened, compared with last week, with an 8-week line;
/// every numeric measurement (weight, temperature…) with its readings; and a
/// list of the days. Tapping a trend opens its full chart.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, required this.store, required this.onOpenDay});

  final EntryStore store;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
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
    final feedings = entriesInWeek(widget.store.entries, ws);
    if (ws != startOfWeek(_today)) return _WeekAverage(Totals.of(feedings), 7);
    final elapsed = _today.difference(ws).inDays + 1;
    if (elapsed == 1) return _WeekAverage(Totals.of(feedings), 1);
    return _WeekAverage(
      Totals.of(feedings.where((f) => !isSameDay(f.start, _today))),
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
                      'Trends',
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

    final weeks = [for (var k = 7; k >= 0; k--) DateTime(ws.year, ws.month, ws.day - 7 * k)];
    final weekEnd = DateTime(ws.year, ws.month, ws.day + 7);
    final routines = routineNames(widget.store.entries, until: weekEnd);
    // Standard measurements first, in preset order; then the rest, latest first.
    int rank(Measurement m) {
      final i = otherPresets.indexWhere((p) => p.name == m.title);
      return i < 0 ? otherPresets.length : i;
    }

    final measurements = measurementsFrom(widget.store.entries, until: weekEnd)
      ..sort((a, b) => rank(a).compareTo(rank(b)));

    Widget row(
      EntryType type,
      String name,
      double Function(Totals) measure,
      String Function(double) format, {
      IconData? icon,
    }) {
      final points = [
        for (var i = 0; i < history.length; i++)
          if (!history[i].isEmpty) TrendPoint(weeks[i], history[i].of(measure)),
      ];
      return _TrendRow(
        type: type,
        icon: icon,
        name: name,
        value: format(thisWeek.of(measure)),
        detail: lastWeek.isEmpty
            ? 'Nothing logged last week'
            : _change(thisWeek.of(measure), lastWeek.of(measure)),
        trend: [for (final w in history) w.isEmpty ? null : w.of(measure)],
        onTap: points.isEmpty
            ? null
            : () => showTrendSheet(
                  context,
                  title: name,
                  subtitle: 'Average per day for each of the last 8 weeks',
                  type: type,
                  icon: icon,
                  points: points,
                  format: format,
                  rowLabel: (p) => 'Week of ${DateFormat('d MMM').format(p.at)}',
                ),
      );
    }

    // Routines are counted per week: they are too sparse for daily averages.
    Widget routineRow(String name) {
      final icon = routinePresets.where((r) => r.$1 == name).map((r) => r.$2).firstOrNull;
      int countIn(DateTime start) => entriesInWeek(widget.store.entries, start)
          .where((e) => e.type == EntryType.routine && e.title == name)
          .length;
      String times(double v) => '${v.round()} time${v.round() == 1 ? '' : 's'}';
      final counts = [for (final w in weeks) countIn(w)];
      final first = counts.indexWhere((c) => c > 0);
      final now = counts.last, before = counts[counts.length - 2];
      // The week in progress would dip the line, so it shows finished weeks.
      final lineWeeks = isCurrentWeek ? counts.length - 1 : counts.length;
      return _TrendRow(
        type: EntryType.routine,
        icon: icon,
        name: name,
        value: '${times(now.toDouble())}${isCurrentWeek ? ' so far' : ''}',
        detail: isCurrentWeek
            ? '${times(before.toDouble())} last week'
            : _change(now.toDouble(), before.toDouble()),
        trend: [
          for (var i = 0; i < lineWeeks; i++) first < 0 || i < first ? null : counts[i].toDouble(),
        ],
        onTap: first < 0
            ? null
            : () => showTrendSheet(
                  context,
                  title: name,
                  subtitle: 'Times per week for each of the last 8 weeks',
                  type: EntryType.routine,
                  icon: icon,
                  points: [
                    for (var i = first; i < weeks.length; i++)
                      TrendPoint(weeks[i], counts[i].toDouble()),
                  ],
                  format: times,
                  rowLabel: (p) => 'Week of ${DateFormat('d MMM').format(p.at)}'
                      '${isCurrentWeek && p.at == ws ? ' (so far)' : ''}',
                ),
      );
    }

    Widget measurementRow(Measurement m) {
      final preset = otherPresetFor(m.title);
      String format(double v) => [formatNumber(v), m.unit].where((s) => s.isNotEmpty).join(' ');
      final prev = m.previous;
      final change = prev == null
          ? null
          : '${m.latest.value >= prev.value ? '+' : '−'}${format((m.latest.value - prev.value).abs())}'
              ' since ${DateFormat('d MMM').format(prev.at)}';
      return _TrendRow(
        type: EntryType.other,
        icon: preset?.icon,
        name: m.title,
        value: format(m.latest.value),
        detail: [
          change ?? 'First reading',
          '${m.points.length} reading${m.points.length == 1 ? '' : 's'}',
        ].join(' · '),
        trend: [
          for (final p in m.points.skip(m.points.length > 12 ? m.points.length - 12 : 0)) p.value
        ],
        zeroBased: false,
        onTap: () => showTrendSheet(
          context,
          title: m.title,
          subtitle: 'Every reading, latest ${DateFormat('d MMM yyyy').format(m.latest.at)}',
          type: EntryType.other,
          icon: preset?.icon,
          points: m.points,
          format: format,
          zeroBased: false,
          rowLabel: (p) => DateFormat('EEE d MMM yyyy, HH:mm').format(p.at),
        ),
      );
    }

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
          row(EntryType.breast, 'Breastfeeding', (t) => t.breast.inSeconds / 60,
              (v) => formatDuration(Duration(minutes: v.round()))),
          row(EntryType.bottle, 'Formula', (t) => t.bottleMl.toDouble(), (v) => '${v.round()} ml'),
          row(EntryType.breastMilk, 'Breast milk by bottle', (t) => t.breastMilkMl.toDouble(),
              (v) => '${v.round()} ml'),
          row(EntryType.pump, 'Pumped', (t) => t.pumpMl.toDouble(), (v) => '${v.round()} ml'),
          row(EntryType.diaper, 'Diapers', (t) => t.diaperCount.toDouble(), _perDay),
          const SizedBox(height: 4),
          const Text(
            'The small lines show the last 8 weeks. Tap a row for its chart.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (routines.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Routines', style: Theme.of(context).textTheme.titleMedium),
            Text(
              isCurrentWeek ? 'Times this week so far, against last week.' : 'Times that week.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final name in routines) routineRow(name),
          ],
          if (measurements.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Measurements', style: Theme.of(context).textTheme.titleMedium),
            const Text(
              'Numbers logged under Other, such as weight. The small lines show the latest readings.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final m in measurements) measurementRow(m),
          ],
          const SizedBox(height: 24),
          Text('Each day', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (var i = elapsed - 1; i >= 0; i--)
            _DayRow(
              day: DateTime(ws.year, ws.month, ws.day + i),
              totals: Totals.of(
                entriesOnDay(widget.store.entries, DateTime(ws.year, ws.month, ws.day + i)),
              ),
              onTap: () => widget.onOpenDay(DateTime(ws.year, ws.month, ws.day + i)),
            ),
        ],
      ),
    );
  }

  /// "6 a day" or "6.4 a day".
  static String _perDay(double v) {
    final n = v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    return '$n a day';
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

  final Totals totals;
  final int days;

  bool get isEmpty => totals.count + totals.pumpCount + totals.diaperCount == 0;

  double of(double Function(Totals t) measure) => measure(totals) / days;
}

/// One trend: icon, name, the current value, how it changed, a small line.
class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.type,
    required this.name,
    required this.value,
    required this.detail,
    required this.trend,
    required this.onTap,
    this.icon,
    this.zeroBased = true,
  });

  final EntryType type;
  final IconData? icon;
  final String name;
  final String value;
  final String detail;

  /// Evenly spaced values, oldest first; null for weeks with nothing logged.
  final List<double?> trend;
  final bool zeroBased;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            EntryIcon(type: type, icon: icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Sparkline(
                values: trend, color: AppColors.lineForType(type), zeroBased: zeroBased, width: 76),
            if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.totals, required this.onTap});

  final DateTime day;
  final Totals totals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (totals.breast > Duration.zero) formatDuration(totals.breast),
      if (totals.bottleMl > 0) '${totals.bottleMl} ml formula',
      if (totals.breastMilkMl > 0) '${totals.breastMilkMl} ml breast milk',
      if (totals.pumpMl > 0) '${totals.pumpMl} ml pumped',
      if (totals.diaperCount > 0)
        '${totals.diaperCount} diaper${totals.diaperCount == 1 ? '' : 's'}',
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
                details.isEmpty ? 'Nothing logged' : details.join(' · '),
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

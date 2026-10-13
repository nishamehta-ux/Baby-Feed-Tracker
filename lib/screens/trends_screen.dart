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

enum Period { week, month }

/// Trends for a week or a month (any number of them back): the average per
/// day of feeds, pumping and diapers, how often each routine happened, and
/// every numeric measurement (weight, temperature…), each with a small line
/// of recent periods and a full chart on tap; then a list of the days.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, required this.store, required this.onOpenDay});

  final EntryStore store;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  Period _period = Period.week;

  /// First day of the period on screen.
  late DateTime _start = _startOf(DateTime.now());

  DateTime get _today => dateOnly(DateTime.now());
  bool get _isWeek => _period == Period.week;

  /// How many periods the small lines and charts cover.
  int get _span => _isWeek ? 8 : 6;
  String get _unit => _isWeek ? 'week' : 'month';

  DateTime _startOf(DateTime d) =>
      _period == Period.week ? startOfWeek(d) : DateTime(d.year, d.month);

  /// The start of the period [n] periods after the one starting at [start].
  DateTime _plus(DateTime start, int n) => _isWeek
      ? DateTime(start.year, start.month, start.day + 7 * n)
      : DateTime(start.year, start.month + n);

  int _daysIn(DateTime start) => _plus(start, 1).difference(start).inDays;

  void _setPeriod(Period p) => setState(() {
        _period = p;
        // Keep the same moment in view: the period that holds the old start,
        // or today when that is the current one.
        final anchor = _start == _startOf(_today) ? _today : _start;
        _start = _startOf(anchor);
      });

  void _shift(int n) => setState(() => _start = _plus(_start, n));

  /// Opens a calendar to jump to the week or month holding any day.
  Future<void> _pickPeriod() async {
    final first = widget.store.entries.fold<DateTime>(
      DateTime.now().subtract(const Duration(days: 365)),
      (d, e) => e.start.isBefore(d) ? dateOnly(e.start) : d,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _start.isAfter(_today) ? _today : _start,
      firstDate: first,
      lastDate: _today,
      helpText: _isWeek ? 'Go to the week of' : 'Go to the month of',
    );
    if (picked != null) setState(() => _start = _startOf(picked));
  }

  /// Totals for the period starting at [start], divided by the days it
  /// covers. In the current period only finished days count, so today's
  /// partial total doesn't drag the average down (on its first day, today is
  /// all there is).
  ///
  /// Days before the first entry ever logged don't count either, so the
  /// period tracking began in isn't averaged over days with nothing logged.
  _PeriodAverage _averageFor(DateTime start, DateTime? firstDay) {
    final entries = entriesBetween(widget.store.entries, start, _plus(start, 1));
    final from = firstDay != null && firstDay.isAfter(start) ? firstDay : start;
    if (start != _startOf(_today)) {
      final days = _plus(start, 1).difference(from).inDays;
      return _PeriodAverage(Totals.of(entries), days < 1 ? 1 : days);
    }
    final elapsed = _today.difference(from).inDays + 1;
    if (elapsed == 1) return _PeriodAverage(Totals.of(entries), 1);
    return _PeriodAverage(
      Totals.of(entries.where((e) => !isSameDay(e.start, _today))),
      elapsed - 1,
    );
  }

  String get _title {
    final current = _start == _startOf(_today);
    if (_isWeek) return current ? 'This week' : 'Week of ${DateFormat('d MMM').format(_start)}';
    return current ? 'This month' : DateFormat('MMMM yyyy').format(_start);
  }

  String get _rangeLabel {
    final end = _plus(_start, 1).subtract(const Duration(days: 1));
    final startFmt = _start.month == end.month ? DateFormat('d') : DateFormat('d MMM');
    return '${startFmt.format(_start)} – ${DateFormat('d MMM yyyy').format(end)}';
  }

  /// "Week of 5 Oct" or "October 2026", for chart lists.
  String _periodLabel(DateTime start) => _isWeek
      ? 'Week of ${DateFormat('d MMM').format(start)}'
      : DateFormat('MMMM yyyy').format(start);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => SingleChildScrollView(
        child: Stack(
          children: [
            const HeaderBackground(height: 400),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(),
                    const SizedBox(height: 20),
                    Text('Trends', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    SegmentedButton<Period>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        foregroundColor: Colors.white,
                        selectedBackgroundColor: Colors.white,
                        selectedForegroundColor: AppColors.ink,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      segments: const [
                        ButtonSegment(value: Period.week, label: Text('Week')),
                        ButtonSegment(value: Period.month, label: Text('Month')),
                      ],
                      selected: {_period},
                      onSelectionChanged: (v) => _setPeriod(v.first),
                    ),
                    const SizedBox(height: 20),
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
    final start = _start;
    final isCurrent = start == _startOf(_today);
    final elapsed = isCurrent ? _today.difference(start).inDays + 1 : _daysIn(start);
    final end = _plus(start, 1);

    // The last [_span] periods, oldest first; the final one is on screen.
    final starts = [for (var k = _span - 1; k >= 0; k--) _plus(start, -k)];
    final firstDay = widget.store.entries.isEmpty
        ? null
        : dateOnly(
            widget.store.entries.map((e) => e.start).reduce((a, b) => a.isBefore(b) ? a : b));
    final history = [for (final s in starts) _averageFor(s, firstDay)];
    final current = history.last;
    final previous = history[history.length - 2];

    final routines = routineNames(widget.store.entries, until: end);
    // Standard measurements first, in preset order; then the rest, latest first.
    int rank(Measurement m) {
      final i = otherPresets.indexWhere((p) => p.name == m.title);
      return i < 0 ? otherPresets.length : i;
    }

    final measurements = measurementsFrom(widget.store.entries, until: end)
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
          if (!history[i].isEmpty) TrendPoint(starts[i], history[i].of(measure)),
      ];
      return _TrendRow(
        type: type,
        icon: icon,
        name: name,
        value: format(current.of(measure)),
        detail: previous.isEmpty
            ? 'Nothing logged last $_unit'
            : _change(current.of(measure), previous.of(measure)),
        trend: [for (final w in history) w.isEmpty ? null : w.of(measure)],
        onTap: points.isEmpty
            ? null
            : () => showTrendSheet(
                  context,
                  title: name,
                  subtitle: 'Average per day for each of the last $_span ${_unit}s',
                  type: type,
                  icon: icon,
                  points: points,
                  format: format,
                  rowLabel: (p) => _periodLabel(p.at),
                ),
      );
    }

    // Routines are counted per period: they are too sparse for daily averages.
    Widget routineRow(String name) {
      final icon = routinePresets.where((r) => r.$1 == name).map((r) => r.$2).firstOrNull;
      int countIn(DateTime s) => entriesBetween(widget.store.entries, s, _plus(s, 1))
          .where((e) => e.type == EntryType.routine && e.title == name)
          .length;
      String times(double v) => '${v.round()} time${v.round() == 1 ? '' : 's'}';
      final counts = [for (final s in starts) countIn(s)];
      final first = counts.indexWhere((c) => c > 0);
      final now = counts.last, before = counts[counts.length - 2];
      // The period in progress would dip the line, so it shows finished ones.
      final lineCount = isCurrent ? counts.length - 1 : counts.length;
      return _TrendRow(
        type: EntryType.routine,
        icon: icon,
        name: name,
        value: '${times(now.toDouble())}${isCurrent ? ' so far' : ''}',
        detail: isCurrent
            ? '${times(before.toDouble())} last $_unit'
            : _change(now.toDouble(), before.toDouble()),
        trend: [
          for (var i = 0; i < lineCount; i++) first < 0 || i < first ? null : counts[i].toDouble(),
        ],
        onTap: first < 0
            ? null
            : () => showTrendSheet(
                  context,
                  title: name,
                  subtitle: 'Times per $_unit for each of the last $_span ${_unit}s',
                  type: EntryType.routine,
                  icon: icon,
                  points: [
                    for (var i = first; i < starts.length; i++)
                      TrendPoint(starts[i], counts[i].toDouble()),
                  ],
                  format: times,
                  rowLabel: (p) =>
                      '${_periodLabel(p.at)}${isCurrent && p.at == start ? ' (so far)' : ''}',
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
                child: InkWell(
                  onTap: _pickPeriod,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _rangeLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.calendar_month_outlined,
                              size: 18, color: AppColors.muted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              RoundIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous $_unit',
                onPressed: () => _shift(-1),
              ),
              const SizedBox(width: 4),
              RoundIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Next $_unit',
                onPressed: isCurrent ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Average per day', style: Theme.of(context).textTheme.titleMedium),
          if (isCurrent && elapsed > 1)
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
          Text(
            'The small lines show the last $_span ${_unit}s. Tap a row for its chart.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (routines.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Routines', style: Theme.of(context).textTheme.titleMedium),
            Text(
              isCurrent ? 'Times this $_unit so far, against last $_unit.' : 'Times that $_unit.',
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
              day: DateTime(start.year, start.month, start.day + i),
              totals: Totals.of(
                entriesOnDay(
                    widget.store.entries, DateTime(start.year, start.month, start.day + i)),
              ),
              onTap: () => widget.onOpenDay(DateTime(start.year, start.month, start.day + i)),
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
    if (before <= 0) return now > 0 ? 'New this $_unit' : 'Same as last $_unit';
    final pct = ((now - before) / before * 100).round();
    if (pct == 0) return 'Same as last $_unit';
    return pct > 0 ? 'Up $pct% on last $_unit' : 'Down ${-pct}% on last $_unit';
  }
}

/// Totals for one week or month and the number of days they cover.
class _PeriodAverage {
  const _PeriodAverage(this.totals, this.days);

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

  /// Evenly spaced values, oldest first; null for periods with nothing logged.
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

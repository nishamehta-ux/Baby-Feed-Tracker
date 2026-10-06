import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/feeding_store.dart';
import '../models/feeding.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/week_grid.dart';
import '../widgets/weekly_trend_chart.dart';
import 'add_feeding_screen.dart';

enum OverviewMode { week, day }

enum TrendRange { byDay, byWeek }

/// Totals for one week and the number of days they cover.
class _WeekAverage {
  const _WeekAverage(this.totals, this.days);

  final FeedingTotals totals;
  final int days;

  bool get isEmpty => totals.count == 0;

  double of(double Function(FeedingTotals t) measure) =>
      days == 0 ? 0 : measure(totals) / days;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final FeedingStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  OverviewMode _mode = OverviewMode.week;
  TrendRange _trendRange = TrendRange.byDay;
  DateTime _anchor = dateOnly(DateTime.now());

  FeedingStore get store => widget.store;

  DateTime get _today => dateOnly(DateTime.now());

  bool get _canGoForward => _mode == OverviewMode.week
      ? startOfWeek(_anchor).isBefore(startOfWeek(_today))
      : _anchor.isBefore(_today);

  void _shift(int direction) {
    final days = _mode == OverviewMode.week ? 7 : 1;
    setState(() {
      _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + days * direction);
      if (_anchor.isAfter(_today)) _anchor = _today;
    });
  }

  Future<void> _openEditor({Feeding? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddFeedingScreen(store: store, existing: existing),
      ),
    );
  }

  Future<void> _editBabyName() async {
    final controller = TextEditingController(text: store.babyName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Baby's name"),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) await store.setBabyName(name);
  }

  Future<void> _delete(Feeding feeding) async {
    await store.delete(feeding.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Feeding deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.upsert(feeding),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => SingleChildScrollView(
          child: Stack(
            children: [
              const PurpleHeaderBackground(height: 440),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 28),
                      _AddFeedingButton(onTap: () => _openEditor()),
                      const SizedBox(height: 18),
                      _buildOverview(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: _editBabyName,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              store.babyName,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final isWeek = _mode == OverviewMode.week;
    final weekStart = startOfWeek(_anchor);
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    final fmt = DateFormat('dd MMM yyyy');

    final feedings = isWeek
        ? feedingsInWeek(store.feedings, weekStart)
        : feedingsOnDay(store.feedings, _anchor);
    final totals = FeedingTotals.of(feedings);

    final String range;
    final String totalLabel;
    if (isWeek) {
      range = '${fmt.format(weekStart)} - ${fmt.format(weekEnd)}';
      totalLabel = weekStart == startOfWeek(_today) ? 'Total this week' : 'Total for the week';
    } else {
      range = DateFormat('EEEE, dd MMM yyyy').format(_anchor);
      totalLabel = _anchor == _today ? 'Total today' : 'Total this day';
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
                    Text('Overview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24)),
                    const SizedBox(height: 2),
                    Text(
                      range,
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
                tooltip: 'Previous',
                onPressed: () => _shift(-1),
              ),
              const SizedBox(width: 4),
              RoundIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Next',
                onPressed: _canGoForward ? () => _shift(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<OverviewMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: OverviewMode.week, label: Text('Week')),
                ButtonSegment(value: OverviewMode.day, label: Text('Day')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          const SizedBox(height: 16),
          _LastFeedingBanner(feeding: store.lastFeeding),
          const SizedBox(height: 20),
          Text(totalLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TotalsRow(totals: totals),
          const SizedBox(height: 8),
          Text(
            '${totals.count} feeding${totals.count == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (isWeek)
            ..._buildWeek(weekStart, feedings)
          else
            ..._buildDay(feedings),
        ],
      ),
    );
  }

  List<Widget> _buildWeek(DateTime weekStart, List<Feeding> feedings) {
    final isCurrentWeek = weekStart == startOfWeek(_today);
    final elapsedDays = isCurrentWeek ? _today.difference(weekStart).inDays + 1 : 7;

    // Averages count only finished days: today's partial total would drag them
    // down. On a Monday there is no finished day yet, so today is used.
    final skipToday = isCurrentWeek && elapsedDays > 1;
    List<Feeding> finished(List<Feeding> list) =>
        skipToday ? list.where((f) => !isSameDay(f.start, _today)).toList() : list;
    final avgDays = skipToday ? elapsedDays - 1 : elapsedDays;
    final avg = FeedingTotals.of(finished(feedings)).dividedBy(avgDays);
    final daily = List.generate(
      7,
      (i) => FeedingTotals.of(feedingsOnDay(
        feedings,
        DateTime(weekStart.year, weekStart.month, weekStart.day + i),
      )),
    );

    // Daily average per week for the 8 weeks ending with this one; the last
    // entry is this week, the one before it is last week.
    final weeks = [
      for (var k = 7; k >= 0; k--)
        DateTime(weekStart.year, weekStart.month, weekStart.day - 7 * k),
    ];
    final weekly = [
      for (final ws in weeks)
        ws == weekStart
            ? _WeekAverage(FeedingTotals.of(finished(feedings)), avgDays)
            : _WeekAverage(FeedingTotals.of(feedingsInWeek(store.feedings, ws)), 7),
    ];
    final thisWeek = weekly.last;
    final lastWeek = weekly[weekly.length - 2];
    final byDay = _trendRange == TrendRange.byDay;
    final labels = byDay
        ? WeekGrid.dayLabels
        : [for (final ws in weeks) DateFormat('d\nMMM').format(ws)];

    String ml(double v) => '${v.round()} ml';
    String minutes(double v) => formatDuration(Duration(minutes: v.round()));

    Widget chart(
      String title,
      Color color,
      double Function(FeedingTotals t) measure,
      String Function(double) format,
    ) =>
        WeeklyTrendChart(
          title: title,
          color: color,
          labels: labels,
          values: byDay
              ? [for (var i = 0; i < elapsedDays; i++) measure(daily[i])]
              : [for (final w in weekly) w.of(measure)],
          average: thisWeek.of(measure),
          previousAverage: lastWeek.isEmpty ? null : lastWeek.of(measure),
          format: format,
        );

    return [
      Text('Daily average', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TotalsRow(totals: avg),
      const SizedBox(height: 8),
      Text(
        '~${avg.count} feedings per day'
        '${skipToday ? ' · today is counted once it ends' : ''}',
        style: const TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      Text('Trends', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<TrendRange>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: TrendRange.byDay, label: Text('This week by day')),
            ButtonSegment(value: TrendRange.byWeek, label: Text('Last 8 weeks')),
          ],
          selected: {_trendRange},
          onSelectionChanged: (s) => setState(() => _trendRange = s.first),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        byDay
            ? 'Total for each day of this week. Tap a column to see its value.'
            : 'Average per day for each week, labelled with the Monday it starts. '
                'Tap a column to see its value.',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 16),
      chart('Breastfeeding time per day', AppColors.breast,
          (t) => t.breast.inSeconds / 60, minutes),
      const SizedBox(height: 20),
      chart('Formula by bottle per day', AppColors.bottle,
          (t) => t.bottleMl.toDouble(), ml),
      const SizedBox(height: 20),
      chart('Breast milk by bottle per day', AppColors.breastMilk,
          (t) => t.breastMilkMl.toDouble(), ml),
      const SizedBox(height: 28),
      Text('Feeding times', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      WeekGrid(
        weekStart: weekStart,
        feedings: feedings,
        onDayTap: (day) => setState(() {
          _anchor = day.isAfter(_today) ? _today : day;
          _mode = OverviewMode.day;
        }),
      ),
      const SizedBox(height: 12),
      const _Legend(),
      const SizedBox(height: 20),
      Text('By day', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      for (var i = 0; i < 7; i++)
        _DaySummaryRow(
          day: DateTime(weekStart.year, weekStart.month, weekStart.day + i),
          totals: daily[i],
          onTap: () => setState(() {
            final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
            _anchor = day.isAfter(_today) ? _today : day;
            _mode = OverviewMode.day;
          }),
        ),
    ];
  }

  List<Widget> _buildDay(List<Feeding> feedings) {
    if (feedings.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No feedings logged on this day yet.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      ];
    }
    return [
      Text('Feedings', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      for (final f in feedings.reversed)
        Dismissible(
          key: ValueKey(f.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red.shade400,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _delete(f),
          child: _FeedingTile(feeding: f, onTap: () => _openEditor(existing: f)),
        ),
      const SizedBox(height: 8),
      const Text(
        'Tap to edit · swipe left to delete',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ];
  }
}

class _AddFeedingButton extends StatelessWidget {
  const _AddFeedingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Add a feeding',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.add, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastFeedingBanner extends StatelessWidget {
  const _LastFeedingBanner({required this.feeding});

  final Feeding? feeding;

  @override
  Widget build(BuildContext context) {
    final f = feeding;
    final String text;
    if (f == null) {
      text = 'No feedings yet. Tap "Add a feeding" to start.';
    } else {
      final today = dateOnly(DateTime.now());
      final day = dateOnly(f.start);
      final when = day == today
          ? 'today'
          : day == today.subtract(const Duration(days: 1))
              ? 'yesterday'
              : 'on ${DateFormat('d MMM').format(day)}';
      final hm = DateFormat.Hm();
      text = 'The last feeding was $when from ${hm.format(f.start)} to ${hm.format(f.end)}';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.banner,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final type in FeedingType.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.forType(type),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(type.shortLabel, style: const TextStyle(fontSize: 13)),
            ],
          ),
      ],
    );
  }
}

class _DaySummaryRow extends StatelessWidget {
  const _DaySummaryRow({
    required this.day,
    required this.totals,
    required this.onTap,
  });

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
                totals.count == 0
                    ? '—'
                    : '${totals.count}× · ${details.join(' · ')}',
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

class _FeedingTile extends StatelessWidget {
  const _FeedingTile({required this.feeding, required this.onTap});

  final Feeding feeding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = feeding;
    final hm = DateFormat.Hm();
    final String detail;
    if (f.type == FeedingType.breast) {
      final parts = <String>[formatDuration(f.breastDuration)];
      if (f.leftDuration > Duration.zero) parts.add('L ${formatClock(f.leftDuration)}');
      if (f.rightDuration > Duration.zero) parts.add('R ${formatClock(f.rightDuration)}');
      if (f.endSide != null) {
        parts.add('ended ${f.endSide == BreastSide.left ? 'left' : 'right'}');
      }
      detail = parts.join(' · ');
    } else {
      detail = '${f.amountMl} ml';
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FeedingTypeIcon(type: f.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.type.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(detail, style: const TextStyle(color: AppColors.muted)),
                  if (f.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        f.notes,
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${hm.format(f.start)}–${hm.format(f.end)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

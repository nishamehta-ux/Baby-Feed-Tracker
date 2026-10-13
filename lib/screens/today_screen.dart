import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/entry_store.dart';
import '../models/entry.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import '../widgets/presets.dart';
import 'entry_sheet.dart';

/// Landing page: add a feeding, and the overview of one day (today by default).
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store, required this.day});

  final EntryStore store;
  final ValueNotifier<DateTime> day;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  _Range _range = _Range.today;

  EntryStore get store => widget.store;

  DateTime get _today => dateOnly(DateTime.now());

  void _shift(int days) {
    final d = widget.day.value;
    final next = DateTime(d.year, d.month, d.day + days);
    widget.day.value = next.isAfter(_today) ? _today : next;
  }

  Future<void> _openEditor(Entry existing) =>
      showEntrySheet(context, store, existing: existing, onDeleted: _offerUndo);

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

  Future<void> _delete(Entry feeding) async {
    await store.delete(feeding.id);
    _offerUndo(feeding);
  }

  void _offerUndo(Entry feeding) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.upsert(feeding),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, widget.day]),
      builder: (context, _) => SingleChildScrollView(
        child: Stack(
          children: [
            const HeaderBackground(height: 480),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(),
                    const SizedBox(height: 20),
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    _AddFeedingButton(onTap: () => showAddMenu(context, store)),
                    const SizedBox(height: 18),
                    _buildOverview(context),
                  ],
                ),
              ),
            ),
          ],
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
    final day = widget.day.value;
    final isToday = day == _today;
    final now = DateTime.now();
    final last24 = isToday && _range == _Range.last24Hours;
    final feedings = last24
        ? (store.entries
            .where((f) => f.start.isAfter(now.subtract(const Duration(hours: 24))))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start)))
        : entriesOnDay(store.entries, day);
    final totals = Totals.of(feedings);
    final title = isToday
        ? 'Today'
        : day == DateTime(_today.year, _today.month, _today.day - 1)
            ? 'Yesterday'
            : DateFormat('EEEE').format(day);

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
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMMM yyyy').format(day),
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
                tooltip: 'Previous day',
                onPressed: () => _shift(-1),
              ),
              const SizedBox(width: 4),
              RoundIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Next day',
                onPressed: isToday ? null : () => _shift(1),
              ),
            ],
          ),
          if (store.lastFeeding case final last?) ...[
            const SizedBox(height: 16),
            _LastFeedingCard(feeding: last, now: now, onTap: () => _openEditor(last)),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Summary', style: Theme.of(context).textTheme.titleMedium),
              ),
              if (isToday)
                SegmentedButton<_Range>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: _Range.today, label: Text('Today')),
                    ButtonSegment(value: _Range.last24Hours, label: Text('Last 24 h')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (v) => setState(() => _range = v.first),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (totals.breastCount > 0)
            _SummaryRow(
              type: EntryType.breast,
              title: 'Breastfeeding',
              count: totals.breastCount,
              lines: [
                '${formatDuration(totals.breast)} total',
                if (totals.breastLeft + totals.breastRight > Duration.zero)
                  'Left ${formatDuration(totals.breastLeft)} · Right ${formatDuration(totals.breastRight)}',
              ],
            ),
          if (totals.anyBottleCount > 0)
            _SummaryRow(
              type: EntryType.bottle,
              title: 'Bottle feeding',
              count: totals.anyBottleCount,
              lines: [
                '${totals.totalMl} ml total',
                if (totals.breastMilkMl > 0) '${totals.breastMilkMl} ml breast milk',
                if (totals.bottleMl > 0) '${totals.bottleMl} ml formula',
              ],
            ),
          if (totals.pumpCount > 0)
            _SummaryRow(
              type: EntryType.pump,
              title: 'Pumping',
              count: totals.pumpCount,
              lines: ['${totals.pumpMl} ml total'],
            ),
          if (totals.diaperCount > 0)
            _SummaryRow(
              type: EntryType.diaper,
              title: 'Diapers',
              count: totals.diaperCount,
              lines: [
                [
                  if (totals.wetCount > 0) '${totals.wetCount} wet',
                  if (totals.dirtyCount > 0) '${totals.dirtyCount} dirty',
                  if (totals.diaperCount - _wetOrDirty(totals) > 0)
                    '${totals.diaperCount - _wetOrDirty(totals)} dry',
                ].join(' · '),
              ],
            ),
          if (totals.routines.isNotEmpty)
            _SummaryRow(
              type: EntryType.routine,
              title: 'Routines',
              count: totals.routines.length,
              lines: [_countedNames(totals.routines.map((e) => e.title))],
            ),
          if (totals.others.isNotEmpty)
            _SummaryRow(
              type: EntryType.other,
              title: 'Other',
              count: totals.others.length,
              lines: [
                for (final e in totals.others.take(3))
                  [entryTitle(e), e.valueWithUnit].where((s) => s.isNotEmpty).join(' '),
                if (totals.others.length > 3) 'and ${totals.others.length - 3} more',
              ],
            ),
          if (feedings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  isToday ? 'Nothing logged yet today.' : 'Nothing logged on this day.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 20),
            Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final f in feedings.reversed)
              Dismissible(
                key: ValueKey(f.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: AppColors.danger,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => _delete(f),
                child: _FeedingTile(
                  feeding: f,
                  showDay: last24 && !isSameDay(f.start, now),
                  onTap: () => _openEditor(f),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Tap to edit · swipe left to delete',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Range { today, last24Hours }

/// Diapers that were wet, dirty or both; the rest were dry.
int _wetOrDirty(Totals t) => t.wetCount + t.dirtyCount - t.bothCount;

/// "Bath · Tummy time ×2", in the order first logged.
String _countedNames(Iterable<String> names) {
  final counts = <String, int>{};
  for (final n in names) {
    counts[n] = (counts[n] ?? 0) + 1;
  }
  return counts.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(' · ');
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
                  'Add an entry',
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

/// The most recent feeding: how long ago it was and how much.
class _LastFeedingCard extends StatelessWidget {
  const _LastFeedingCard({required this.feeding, required this.now, required this.onTap});

  final Entry feeding;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = feeding;
    final isBreast = f.type == EntryType.breast;
    final value = isBreast ? '${f.breastDuration.inMinutes}' : '${f.amountMl}';
    final unit = isBreast ? 'min' : 'ml';
    return Material(
      color: AppColors.banner,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Row(
            children: [
              EntryIcon(type: f.type, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last feeding',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Text(
                      '${timeAgo(f.start, now)} · ${f.type.shortLabel}',
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w300, color: AppColors.ink, height: 1),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(unit,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One feeding type in the summary: icon, name with a count badge, then totals.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.type,
    required this.title,
    required this.count,
    required this.lines,
  });

  final EntryType type;
  final String title;
  final int count;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntryIcon(type: type, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    Semantics(
                      label: '$count times',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.forType(type),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style:
                              TextStyle(fontWeight: FontWeight.w800, color: AppColors.onType(type)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final line in lines)
                  Text(line, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedingTile extends StatelessWidget {
  const _FeedingTile({required this.feeding, required this.onTap, this.showDay = false});

  final Entry feeding;
  final VoidCallback onTap;

  /// Prefix the time with the day, for entries from before today.
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final f = feeding;
    final hm = DateFormat.Hm();
    final detail = entryDetail(f);
    final hasRange =
        f.type == EntryType.breast || (f.type == EntryType.pump && f.duration > Duration.zero);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EntryIcon(type: f.type, icon: iconForEntry(f)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entryTitle(f), style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (detail.isNotEmpty)
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
              '${showDay ? 'Yesterday ' : ''}${hm.format(f.start)}'
              '${hasRange ? '–${hm.format(f.end)}' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

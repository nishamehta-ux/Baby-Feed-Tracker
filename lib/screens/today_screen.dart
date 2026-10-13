import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/entry_store.dart';
import '../models/entry.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import '../widgets/quick_actions.dart';
import '../widgets/timeline_tile.dart';
import 'entry_sheet.dart';

/// Landing page: add a feeding, and the overview of one day (today by default).
class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.store,
    required this.day,
    required this.onOpenProfile,
  });

  final EntryStore store;
  final ValueNotifier<DateTime> day;

  /// Shows the Profile tab (from the baby's photo and name).
  final VoidCallback onOpenProfile;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  EntryStore get store => widget.store;

  DateTime get _today => dateOnly(DateTime.now());

  void _shift(int days) {
    final d = widget.day.value;
    final next = DateTime(d.year, d.month, d.day + days);
    widget.day.value = next.isAfter(_today) ? _today : next;
  }

  Future<void> _openEditor(Entry existing) =>
      showEntrySheet(context, store, existing: existing, onDeleted: _offerUndo);

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
        child: Column(
          children: [
            HeaderPanel(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(height: 22),
                  const SizedBox(height: 16),
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  if (store.live != null) ...[
                    LiveTimerCard(store: store, onFinish: _finishLive),
                    const SizedBox(height: 28),
                  ],
                  const SectionLabel('Quick add'),
                  const SizedBox(height: 10),
                  QuickActions(store: store, onLogged: _offerUndoLogged),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildOverview(context),
            ),
            const SizedBox(height: 96), // room for the floating button
          ],
        ),
      ),
    );
  }

  /// Stops the live timer and opens it in the drawer to review and save.
  Future<void> _finishLive() async {
    final live = store.live;
    if (live == null) return;
    final now = DateTime.now();
    await store.setLive(live.paused(now));
    if (!mounted) return;
    final saved = await showEntrySheet(context, store, draft: live.toDraft(now, store.newId()));
    if (saved) await store.setLive(null);
  }

  void _offerUndoLogged(Entry entry) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Logged ${[
            entryTitle(entry),
            entryDetail(entry)
          ].where((s) => s.isNotEmpty).join(' · ').toLowerCase()}'),
          action: SnackBarAction(label: 'Undo', onPressed: () => store.delete(entry.id)),
        ),
      );
  }

  /// Opens a calendar to jump to any day, however long ago.
  Future<void> _pickDay() async {
    final first = store.entries.fold<DateTime>(
      DateTime.now().subtract(const Duration(days: 365)),
      (d, e) => e.start.isBefore(d) ? dateOnly(e.start) : d,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.day.value,
      firstDate: first,
      lastDate: _today,
      helpText: 'Go to a day',
    );
    if (picked != null) widget.day.value = dateOnly(picked);
  }

  Widget _buildHeader(BuildContext context) {
    final birth = store.birthDate;
    return InkWell(
      onTap: widget.onOpenProfile,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          BabyAvatar(photo: store.photo, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.babyName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (birth != null)
                  Text(
                    ageText(birth, DateTime.now()),
                    style: TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final day = widget.day.value;
    final isToday = day == _today;
    final now = DateTime.now();
    final entries = entriesOnDay(store.entries, day);
    final totals = Totals.of(entries);
    final title = isToday
        ? 'Today'
        : day == DateTime(_today.year, _today.month, _today.day - 1)
            ? 'Yesterday'
            : DateFormat('EEEE').format(day);
    final last = store.lastFeeding;

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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: AppText.headline),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: _pickDay,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat('d MMMM yyyy').format(day),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.muted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous day',
                onPressed: () => _shift(-1),
              ),
              const SizedBox(width: 4),
              RoundIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next day',
                onPressed: isToday ? null : () => _shift(1),
              ),
            ],
          ),
          if (isToday && last != null) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Last feeding '),
                  TextSpan(
                    text: timeAgo(last.start, now),
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  TextSpan(text: ' · ${last.type.shortLabel} ${entryDetail(last)}'),
                ],
              ),
              style: TextStyle(color: AppColors.muted),
            ),
          ],
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Two chips per row, so the day's totals take two lines at most.
            LayoutBuilder(
              builder: (context, constraints) {
                final half = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (totals.breastCount > 0)
                      _SummaryChip(
                        width: half,
                        type: EntryType.breast,
                        value: formatDuration(totals.breast),
                        label: 'breastfed',
                      ),
                    if (totals.anyBottleCount > 0)
                      _SummaryChip(
                        width: half,
                        type: EntryType.bottle,
                        value: '${totals.totalMl} ml',
                        label: 'bottle',
                      ),
                    if (totals.pumpCount > 0)
                      _SummaryChip(
                        width: half,
                        type: EntryType.pump,
                        value: '${totals.pumpMl} ml',
                        label: 'pumped',
                      ),
                    if (totals.diaperCount > 0)
                      _SummaryChip(
                        width: half,
                        type: EntryType.diaper,
                        value: '${totals.diaperCount}',
                        label: totals.diaperCount == 1 ? 'diaper' : 'diapers',
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              if (entries.isNotEmpty)
                Text(
                  '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  isToday ? 'Nothing logged yet today.' : 'Nothing logged on this day.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else ...[
            for (final e in entries.reversed)
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: AppColors.danger,
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) => _delete(e),
                child: TimelineTile(entry: e, onTap: () => _openEditor(e)),
              ),
            const SizedBox(height: 8),
            Text(
              'Tap to edit · swipe left to delete',
              style: TextStyle(fontSize: AppText.label, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A day total in the summary row: the kind's icon, a value and a word.
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.width,
    required this.type,
    required this.value,
    required this.label,
  });

  final double width;
  final EntryType type;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconForType(type), size: 18, color: AppColors.lineForType(type)),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: ' $label', style: TextStyle(color: AppColors.muted)),
                  ],
                ),
                style: TextStyle(fontSize: AppText.body, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/entry_store.dart';
import '../models/entry.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import '../widgets/presets.dart';
import '../widgets/quick_actions.dart';
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
        child: Column(
          children: [
            HeaderPanel(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(),
                  const SizedBox(height: 20),
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _AddFeedingButton(onTap: () => showAddMenu(context, store)),
                  const SizedBox(height: 16),
                  if (store.live != null) ...[
                    LiveTimerCard(store: store, onFinish: _finishLive),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Quick add',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  QuickActions(store: store, onLogged: _offerUndoLogged),
                ],
              ),
            ),
            // The day card overlaps the bottom of the header.
            Transform.translate(
              offset: const Offset(0, -48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildOverview(context),
              ),
            ),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.calendar_month_outlined,
                              size: 18, color: AppColors.muted),
                        ],
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
          if (isToday && last != null) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Last feeding '),
                  TextSpan(
                    text: timeAgo(last.start, now),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  TextSpan(text: ' · ${last.type.shortLabel} ${entryDetail(last)}'),
                ],
              ),
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _Stat(
                    type: EntryType.breast,
                    value: formatDuration(totals.breast).replaceAll(RegExp(r' \d+ s$'), ''),
                    label: 'breastfed',
                  ),
                  _Stat(type: EntryType.bottle, value: '${totals.totalMl} ml', label: 'bottle'),
                  _Stat(type: EntryType.pump, value: '${totals.pumpMl} ml', label: 'pumped'),
                  _Stat(
                    type: EntryType.diaper,
                    value: '${totals.diaperCount}',
                    label: totals.diaperCount == 1 ? 'diaper' : 'diapers',
                  ),
                ],
              ),
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
                  style: const TextStyle(color: AppColors.muted),
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
                  style: const TextStyle(color: AppColors.muted),
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
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => _delete(e),
                child: _TimelineTile(entry: e, onTap: () => _openEditor(e)),
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

/// One day total in the summary strip: a small icon, the value, a word.
class _Stat extends StatelessWidget {
  const _Stat({required this.type, required this.value, required this.label});

  final EntryType type;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          EntryIcon(type: type, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ],
      ),
    );
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

/// One entry in the day's timeline: the time on the left, then what it was.
class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.onTap});

  final Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final hm = DateFormat.Hm();
    final detail = entryDetail(e);
    final hasRange =
        e.type == EntryType.breast || (e.type == EntryType.pump && e.duration > Duration.zero);
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hm.format(e.start),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (hasRange)
                      Text(
                        hm.format(e.end),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // The icon sits on a thin line that runs down the day.
            SizedBox(
              width: 36,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned.fill(
                    child: Center(child: Container(width: 2, color: AppColors.divider)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: EntryIcon(type: e.type, icon: iconForEntry(e), size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entryTitle(e), style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (detail.isNotEmpty)
                      Text(detail, style: const TextStyle(color: AppColors.muted)),
                    if (e.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          e.notes,
                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

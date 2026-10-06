import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/feeding_store.dart';
import '../models/feeding.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/anica_logo.dart';
import '../widgets/common.dart';
import 'add_feeding_screen.dart';

/// Landing page: add a feeding, and the overview of one day (today by default).
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store, required this.day});

  final FeedingStore store;
  final ValueNotifier<DateTime> day;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  FeedingStore get store => widget.store;

  DateTime get _today => dateOnly(DateTime.now());

  void _shift(int days) {
    final d = widget.day.value;
    final next = DateTime(d.year, d.month, d.day + days);
    widget.day.value = next.isAfter(_today) ? _today : next;
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
                    const AnicaLogo(),
                    const SizedBox(height: 20),
                    _buildHeader(context),
                    const SizedBox(height: 24),
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
    final feedings = feedingsOnDay(store.feedings, day);
    final totals = FeedingTotals.of(feedings);
    final isToday = day == _today;
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
          const SizedBox(height: 16),
          _LastFeedingBanner(feeding: store.lastFeeding),
          const SizedBox(height: 20),
          Text(
            isToday ? 'Total today' : 'Total for the day',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TotalsRow(totals: totals),
          const SizedBox(height: 8),
          Text(
            '${totals.count} feeding${totals.count == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (feedings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No feedings logged on this day yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else ...[
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
          ],
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

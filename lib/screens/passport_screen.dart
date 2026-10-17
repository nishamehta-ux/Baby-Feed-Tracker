import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/entry_store.dart';
import '../models/entry.dart';
import '../models/passport.dart';
import '../models/summary.dart';
import '../models/trends.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/presets.dart';

/// Opens the health passport: the latest information to show or send to a
/// doctor.
Future<void> showPassport(BuildContext context, EntryStore store) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => PassportScreen(store: store)));

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key, required this.store});

  final EntryStore store;

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  int _window = 7;

  Passport get _passport => Passport.from(
        widget.store.entries,
        babyName: widget.store.babyName,
        birthDate: widget.store.birthDate,
        now: DateTime.now(),
        window: _window,
      );

  Future<void> _share(Passport p, Rect origin) async {
    try {
      await SharePlus.instance.share(ShareParams(
        text: p.toText(),
        subject: 'Health passport: ${p.babyName}',
        title: 'Health passport: ${p.babyName}',
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (!mounted) return;
      // No share sheet here: copying is the next best thing.
      await _copy(p);
    }
  }

  Future<void> _copy(Passport p) async {
    await Clipboard.setData(ClipboardData(text: p.toText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied. Paste it into a message or email.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final p = _passport;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Health passport',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _BabyHeader(store: widget.store, passport: p),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Latest measurements',
                        empty:
                            p.measurements.isEmpty ? 'No weight or temperature logged yet.' : null,
                        children: [for (final m in p.measurements) _MeasurementLine(m)],
                      ),
                      _Section(
                        title: 'Vaccinations',
                        empty: p.vaccines.isEmpty ? 'No vaccines logged yet.' : null,
                        children: [
                          for (final v in p.vaccines)
                            _Line(
                              icon: Icons.vaccines_rounded,
                              title: v.value.trim().isEmpty ? 'Vaccine' : v.value.trim(),
                              trailing: DateFormat('d MMM yyyy').format(v.start),
                            ),
                        ],
                      ),
                      _Section(
                        title: 'Medicines and vitamins',
                        empty: p.medicines.isEmpty ? 'No medicines logged yet.' : null,
                        children: [
                          for (final m in p.medicines)
                            _Line(
                              icon: Icons.medication_liquid_rounded,
                              title: m.name,
                              detail: m.times == 1
                                  ? 'Once'
                                  : '${m.times} times since ${DateFormat('d MMM').format(m.first)}',
                              trailing: 'Last ${DateFormat('d MMM').format(m.last)}',
                            ),
                        ],
                      ),
                      _Section(
                        title: 'Daily averages',
                        action: SegmentedButton<int>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: const [
                            ButtonSegment(value: 7, label: Text('7 days')),
                            ButtonSegment(value: 14, label: Text('14')),
                            ButtonSegment(value: 30, label: Text('30')),
                          ],
                          selected: {_window},
                          onSelectionChanged: (v) => setState(() => _window = v.first),
                        ),
                        empty: p.days == 0 ? 'Averages appear after the first full day.' : null,
                        footnote: p.days == 0
                            ? null
                            : p.days < _window
                                ? 'Over the ${p.days} finished days logged so far.'
                                : 'Over the last $_window finished days.',
                        children: [
                          for (final i in p.summaryItems())
                            _Line(
                              icon: _iconForSummary(i.label),
                              title: i.label,
                              detail: i.detail,
                              trailing: i.value,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Logged by parents in this app. Not a medical record.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: AppText.label, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                // Share and copy, always in reach.
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  padding:
                      EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                  child: Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) => FilledButton.icon(
                            onPressed: () {
                              final box = context.findRenderObject() as RenderBox?;
                              final origin = box == null
                                  ? Rect.zero
                                  : box.localToGlobal(Offset.zero) & box.size;
                              _share(p, origin);
                            },
                            icon: const Icon(Icons.ios_share_rounded),
                            label: const Text('Share with doctor'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _copy(p),
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: const StadiumBorder(),
                          foregroundColor: AppColors.ink,
                          side: BorderSide(color: AppColors.divider, width: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _iconForSummary(String line) {
    if (line.startsWith('Breastfeeding')) return iconForType(EntryType.breast);
    if (line.startsWith('Formula')) return iconForType(EntryType.bottle);
    if (line.startsWith('Breast milk')) return iconForType(EntryType.breastMilk);
    if (line.startsWith('Pumped')) return iconForType(EntryType.pump);
    if (line.startsWith('Diapers')) return iconForType(EntryType.diaper);
    if (line.startsWith('Sleep')) return Icons.bedtime_rounded;
    return Icons.restaurant_rounded;
  }
}

class _BabyHeader extends StatelessWidget {
  const _BabyHeader({required this.store, required this.passport});

  final EntryStore store;
  final Passport passport;

  @override
  Widget build(BuildContext context) {
    final birth = passport.birthDate;
    return AppCard(
      child: Row(
        children: [
          BabyAvatar(photo: store.photo, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(passport.babyName, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  birth == null
                      ? 'Add the date of birth in Profile'
                      : 'Born ${DateFormat('d MMM yyyy').format(birth)} · '
                          '${ageText(birth, passport.generatedAt)}',
                  style: TextStyle(color: AppColors.muted),
                ),
                Text(
                  'Updated ${DateFormat('d MMM yyyy, HH:mm').format(passport.generatedAt)}',
                  style: TextStyle(fontSize: AppText.label, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card of lines, with a message when there is nothing to show.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.empty,
    this.action,
    this.footnote,
  });

  final String title;
  final List<Widget> children;
  final String? empty;
  final Widget? action;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (action != null) ...[const SizedBox(height: 10), action!],
            const SizedBox(height: 8),
            if (empty != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(empty!, style: TextStyle(color: AppColors.muted)),
              )
            else
              ...children,
            if (footnote != null && empty == null) ...[
              const SizedBox(height: 8),
              Text(footnote!, style: TextStyle(fontSize: AppText.label, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.title, required this.trailing, this.detail});

  final IconData icon;
  final String title;
  final String? detail;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (detail != null)
                  Text(detail!, style: TextStyle(fontSize: AppText.label, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementLine extends StatelessWidget {
  const _MeasurementLine(this.m);

  final Measurement m;

  @override
  Widget build(BuildContext context) {
    final unit = m.unit.isEmpty ? '' : ' ${m.unit}';
    final prev = m.previous;
    final change = prev == null ? null : m.latest.value - prev.value;
    return _Line(
      icon: otherPresetFor(m.title)?.icon ?? Icons.straighten_rounded,
      title: m.title,
      detail: [
        DateFormat('d MMM yyyy').format(m.latest.at),
        if (change != null)
          '${change >= 0 ? '+' : ''}${formatNumber(change)}$unit since '
              '${DateFormat('d MMM').format(prev!.at)}',
      ].join(' · '),
      trailing: '${formatNumber(m.latest.value)}$unit',
    );
  }
}

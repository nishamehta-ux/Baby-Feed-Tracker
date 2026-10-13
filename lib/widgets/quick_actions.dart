import 'dart:async';

import 'package:flutter/material.dart';

import '../data/entry_store.dart';
import '../models/entry.dart';
import '../models/live_timer.dart';
import '../models/summary.dart';
import '../theme.dart';
import 'common.dart';

/// The side to start on: the other one from where the last feed ended.
BreastSide nextSide(EntryStore store) =>
    store.lastWhere((e) => e.type == EntryType.breast)?.endSide == BreastSide.left
        ? BreastSide.right
        : BreastSide.left;

/// One-tap tiles on Today: start a breastfeeding or pumping timer, or log a
/// repeat of the last bottle or a diaper straight away. [onLogged] runs after
/// an instant log, so the page can offer Undo.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.store, required this.onLogged});

  final EntryStore store;
  final ValueChanged<Entry> onLogged;

  Future<void> _log(Entry Function(DateTime now) make) async {
    final entry = make(DateTime.now());
    await store.upsert(entry);
    onLogged(entry);
  }

  @override
  Widget build(BuildContext context) {
    final side = nextSide(store);
    final lastBottle = store.lastWhere((e) => e.isBottle);
    Entry plain(DateTime now, EntryType type, {DiaperKind? diaper, int ml = 0}) => Entry(
          id: store.newId(),
          type: type,
          start: now,
          end: now,
          diaper: diaper,
          amountMl: ml,
        );

    final tiles = <Widget>[
      if (store.live == null) ...[
        _Tile(
          type: EntryType.breast,
          title: 'Breastfeed',
          subtitle: 'Start ${side == BreastSide.left ? 'left' : 'right'} side',
          icon: Icons.play_arrow_rounded,
          onTap: () {
            final now = DateTime.now();
            store.setLive(LiveTimer(type: EntryType.breast, start: now, side: side, since: now));
          },
        ),
        _Tile(
          type: EntryType.pump,
          title: 'Pump',
          subtitle: 'Start timer',
          icon: Icons.play_arrow_rounded,
          onTap: () {
            final now = DateTime.now();
            store.setLive(LiveTimer(type: EntryType.pump, start: now, since: now));
          },
        ),
      ],
      if (lastBottle != null && lastBottle.amountMl > 0)
        _Tile(
          type: lastBottle.type,
          title: 'Bottle ${lastBottle.amountMl} ml',
          subtitle: lastBottle.type.shortLabel,
          onTap: () => _log((now) => plain(now, lastBottle.type, ml: lastBottle.amountMl)),
        ),
      _Tile(
        type: EntryType.diaper,
        title: 'Diaper',
        subtitle: 'Wet',
        onTap: () => _log((now) => plain(now, EntryType.diaper, diaper: DiaperKind.wet)),
      ),
      _Tile(
        type: EntryType.diaper,
        title: 'Diaper',
        subtitle: 'Dirty',
        onTap: () => _log((now) => plain(now, EntryType.diaper, diaper: DiaperKind.dirty)),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final t in tiles) ...[t, const SizedBox(width: 10)],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
  });

  final EntryType type;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Shown at the corner, e.g. a play symbol for tiles that start a timer.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 116,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EntryIcon(type: type, size: 32),
                      const Spacer(),
                      if (icon != null) Icon(icon, color: AppColors.ink, size: 22),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The running (or paused) breastfeeding or pumping timer, with controls.
class LiveTimerCard extends StatefulWidget {
  const LiveTimerCard({super.key, required this.store, required this.onFinish});

  final EntryStore store;

  /// Opens the drawer to review and save the timed entry.
  final VoidCallback onFinish;

  @override
  State<LiveTimerCard> createState() => _LiveTimerCardState();
}

class _LiveTimerCardState extends State<LiveTimerCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.store.live?.running ?? false) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this timer?'),
        content: const Text('The time counted so far will not be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (ok == true) await widget.store.setLive(null);
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.store.live;
    if (live == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final isBreast = live.type == EntryType.breast;
    final status = !live.running
        ? 'Paused'
        : isBreast
            ? 'Timing ${live.side == BreastSide.right ? 'right' : 'left'} side'
            : 'Timing';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            children: [
              EntryIcon(type: live.type, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBreast ? 'Breastfeeding' : 'Pumping',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    Text(status, style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              Text(
                formatClock(live.total(now)),
                style: const TextStyle(
                  fontSize: 32,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isBreast)
            Row(
              children: [
                for (final s in BreastSide.values) ...[
                  if (s == BreastSide.right) const SizedBox(width: 10),
                  Expanded(
                    child: _SideButton(
                      label: s == BreastSide.left ? 'Left' : 'Right',
                      time: formatClock(live.onSide(s, now)),
                      running: live.running && live.side == s,
                      onTap: () => widget.store.setLive(live.toggled(DateTime.now(), s)),
                    ),
                  ),
                ],
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => widget.store.setLive(live.toggled(DateTime.now())),
                icon: Icon(live.running ? Icons.pause : Icons.play_arrow),
                label: Text(live.running ? 'Pause' : 'Resume'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink, width: 1.25),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _discard,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Discard'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: widget.onFinish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 44),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Finish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.time,
    required this.running,
    required this.onTap,
  });

  final String label;
  final String time;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = running ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      label: '$label side, $time, ${running ? 'running, tap to pause' : 'tap to time this side'}',
      child: Material(
        color: running ? AppColors.indigo : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: AppColors.ink, width: running ? 0 : 1.25)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(running ? Icons.pause : Icons.play_arrow, color: fg, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$label $time',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: fg,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

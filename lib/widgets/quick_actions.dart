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
          subtitle: 'Next: ${side == BreastSide.left ? 'left' : 'right'} side',
          onTap: () => store.setLive(LiveTimer.ready(EntryType.breast, DateTime.now())),
        ),
        _Tile(
          type: EntryType.pump,
          title: 'Pump',
          subtitle: 'Timer',
          onTap: () => store.setLive(LiveTimer.ready(EntryType.pump, DateTime.now())),
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
  });

  final EntryType type;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
                  EntryIcon(type: type, size: 32),
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
    // Nothing counted yet: just close the card.
    if (widget.store.live?.notStarted ?? true) {
      await widget.store.setLive(null);
      return;
    }
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
    final lastSide = widget.store.lastWhere((e) => e.type == EntryType.breast)?.endSide;
    final status = live.notStarted
        ? (isBreast ? 'Choose a side to start' : 'Tap Start when you begin')
        : !live.running
            ? 'Paused'
            : isBreast
                ? 'Timing ${live.side == BreastSide.right ? 'right' : 'left'} side'
                : 'Timing';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          // Header: what is being timed, and a way out.
          Row(
            children: [
              EntryIcon(type: live.type, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isBreast ? 'Breastfeeding' : 'Pumping',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              IconButton(
                onPressed: _discard,
                tooltip: live.notStarted ? 'Cancel' : 'Discard',
                icon: const Icon(Icons.close, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // The clock is the focus of the card.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatClock(live.total(now)),
                    style: TextStyle(
                      fontSize: 56,
                      height: 1.1,
                      letterSpacing: -1,
                      color: live.notStarted ? AppColors.muted : AppColors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (live.running) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isBreast)
                  Row(
                    children: [
                      for (final s in BreastSide.values) ...[
                        if (s == BreastSide.right) const SizedBox(width: 12),
                        Expanded(
                          child: _ControlTile(
                            title: s == BreastSide.left ? 'Left' : 'Right',
                            detail: live.notStarted ? 'Start' : formatClock(live.onSide(s, now)),
                            tag: live.notStarted && lastSide == s ? 'last side' : null,
                            running: live.running && live.side == s,
                            semanticsLabel: live.notStarted
                                ? 'Start ${s.name} side'
                                    '${lastSide == s ? ', the side the last feed ended on' : ''}'
                                : '${s.name} side, ${formatClock(live.onSide(s, now))}, '
                                    '${live.running && live.side == s ? 'running, tap to pause' : 'tap to time this side'}',
                            onTap: () => widget.store.setLive(live.toggled(DateTime.now(), s)),
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  _ControlTile(
                    title: live.running ? 'Pause' : (live.notStarted ? 'Start' : 'Resume'),
                    running: live.running,
                    semanticsLabel: live.running ? 'Pause' : 'Start',
                    onTap: () => widget.store.setLive(live.toggled(DateTime.now())),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: live.notStarted ? null : widget.onFinish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Finish'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A big tap target on the timer card: a breast side with its time, or the
/// pump's start/pause. Filled while it is the one running.
class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.title,
    required this.running,
    required this.onTap,
    required this.semanticsLabel,
    this.detail,
    this.tag,
  });

  final String title;

  /// "Start" before timing, else the time on this side.
  final String? detail;

  /// Marks the side the previous feed ended on, to help alternate.
  final String? tag;
  final bool running;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final fg = running ? Colors.white : AppColors.ink;
    final sub = running ? Colors.white70 : AppColors.muted;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: running ? AppColors.indigo : AppColors.field,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ExcludeSemantics(
            child: Container(
              height: detail == null ? 56 : 76,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (detail == null) ...[
                          Icon(running ? Icons.pause : Icons.play_arrow, color: fg, size: 22),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          title,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fg),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag!,
                              style: const TextStyle(fontSize: 11, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(running ? Icons.pause : Icons.play_arrow, color: sub, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            detail!,
                            style: TextStyle(
                              fontSize: 14,
                              color: sub,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/entry.dart';
import '../models/summary.dart';
import '../theme.dart';
import 'common.dart';
import 'presets.dart';

/// One entry in the day's timeline: the time on the left, then what it was.
class TimelineTile extends StatelessWidget {
  const TimelineTile({super.key, required this.entry, this.onTap});

  final Entry entry;

  /// Null for a read-only list.
  final VoidCallback? onTap;

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
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (hasRange)
                      Text(
                        hm.format(e.end),
                        style: const TextStyle(
                          fontSize: AppText.label,
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
                    padding: const EdgeInsets.only(top: 10),
                    child: EntryIcon(type: e.type, icon: iconForEntry(e), size: EntryIcon.small),
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
                          style:
                              const TextStyle(fontStyle: FontStyle.italic, fontSize: AppText.label),
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

import 'package:flutter/material.dart';

import '../models/entry.dart';
import '../models/trends.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/trend_chart.dart';

/// Opens a drawer with the full chart of one trend and every value in it.
///
/// [rowLabel] names each point in the list ("7 days to 14 Oct", "Mon 13 Oct").
Future<void> showTrendSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required EntryType type,
  IconData? icon,
  required List<TrendPoint> points,
  required String Function(double) format,
  required String Function(TrendPoint) rowLabel,
  bool zeroBased = true,
}) {
  final header = AppColors.headerForType(type);
  final onHeader = AppColors.onHeaderForType(type);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: AppColors.surface,
          child: Column(
            children: [
              Container(
                color: header,
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded, color: onHeader),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: onHeader,
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Row(
                      children: [
                        EntryIcon(type: type, icon: icon, size: EntryIcon.medium),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(subtitle, style: TextStyle(color: AppColors.muted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TrendChart(
                      points: points,
                      color: AppColors.lineForType(type),
                      format: format,
                      zeroBased: zeroBased,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the chart to read a point.',
                      style: TextStyle(color: AppColors.muted, fontSize: AppText.label),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'All values',
                      style: TextStyle(
                          fontSize: AppText.subtitle,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    for (final p in points.reversed)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(rowLabel(p), style: TextStyle(color: AppColors.ink)),
                            ),
                            Text(
                              format(p.value),
                              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

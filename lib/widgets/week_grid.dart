import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/feeding.dart';
import '../models/summary.dart';
import '../theme.dart';

/// 7 columns (Mon–Sun) x 24 hourly rows. Each feeding is drawn in the hour it
/// started; several feedings in the same hour share the cell side by side.
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.weekStart,
    required this.feedings,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final List<Feeding> feedings;
  final ValueChanged<DateTime> onDayTap;

  static const dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  static const _rowHeight = 18.0;
  static const _gap = 3.0;
  static const _labelWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );
    final today = dateOnly(DateTime.now());

    // cells[day][hour] -> feeding types started in that hour.
    final cells = List.generate(7, (_) => List.generate(24, (_) => <FeedingType>[]));
    for (final f in feedings) {
      final dayIndex = dateOnly(f.start).difference(days.first).inDays;
      if (dayIndex < 0 || dayIndex > 6) continue;
      cells[dayIndex][f.start.hour].add(f.type);
    }

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: _labelWidth),
            for (final day in days)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onDayTap(day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.E().format(day).substring(0, 2),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isSameDay(day, today)
                                ? AppColors.primary
                                : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var hour = 0; hour < 24; hour++)
          Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: SizedBox(
              height: _rowHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: hour % 6 == 0
                        ? Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          )
                        : null,
                  ),
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onDayTap(days[d]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _gap / 2),
                          child: _Cell(types: cells[d][hour]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.types});

  final List<FeedingType> types;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.soft,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.forType(types[i]),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

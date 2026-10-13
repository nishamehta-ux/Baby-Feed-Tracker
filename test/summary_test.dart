import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/models/summary.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _f(EntryType type, DateTime start,
        {int ml = 0, Duration left = Duration.zero, Duration right = Duration.zero}) =>
    Entry(
      id: start.toIso8601String(),
      type: type,
      start: start,
      end: start.add(const Duration(minutes: 20)),
      leftDuration: left,
      rightDuration: right,
      endSide: type == EntryType.breast ? BreastSide.left : null,
      amountMl: ml,
    );

void main() {
  test('startOfWeek returns Monday', () {
    expect(startOfWeek(DateTime(2026, 10, 6, 10, 37)), DateTime(2026, 10, 5));
    expect(startOfWeek(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
    expect(startOfWeek(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
  });

  test('breast duration uses side timers, else start/end window', () {
    final timed = _f(EntryType.breast, DateTime(2026, 10, 6, 8),
        left: const Duration(minutes: 10), right: const Duration(minutes: 5));
    expect(timed.breastDuration, const Duration(minutes: 15));
    final untimed = _f(EntryType.breast, DateTime(2026, 10, 6, 8));
    expect(untimed.breastDuration, const Duration(minutes: 20));
  });

  test('daily and weekly totals', () {
    final all = [
      _f(EntryType.breast, DateTime(2026, 10, 5, 3), left: const Duration(minutes: 12)),
      _f(EntryType.bottle, DateTime(2026, 10, 5, 9), ml: 90),
      _f(EntryType.breastMilk, DateTime(2026, 10, 6, 7), ml: 60),
      _f(EntryType.bottle, DateTime(2026, 10, 6, 11), ml: 120),
      _f(EntryType.bottle, DateTime(2026, 10, 12, 1), ml: 999), // next week
    ];

    final day = Totals.of(entriesOnDay(all, DateTime(2026, 10, 6)));
    expect(day.count, 2);
    expect(day.bottleMl, 120);
    expect(day.breastMilkMl, 60);
    expect(day.breast, Duration.zero);

    final week = Totals.of(entriesInWeek(all, DateTime(2026, 10, 5)));
    expect(week.count, 4);
    expect(week.bottleMl, 210);
    expect(week.breast, const Duration(minutes: 12));
    expect(week.dividedBy(2).bottleMl, 105);
  });

  test('json round trip', () {
    final f = _f(EntryType.breast, DateTime(2026, 10, 6, 8), left: const Duration(seconds: 61));
    final back = Entry.fromJson(f.toJson());
    expect(back.leftDuration, f.leftDuration);
    expect(back.endSide, BreastSide.left);
    expect(back.start, f.start);
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(minutes: 36, seconds: 10)), '36 m 10 s');
    expect(formatDuration(const Duration(hours: 1, minutes: 5)), '1 h 5 m');
    expect(formatDuration(const Duration(hours: 1)), '1 h');
    expect(formatDuration(const Duration(minutes: 13)), '13 m');
  });
}

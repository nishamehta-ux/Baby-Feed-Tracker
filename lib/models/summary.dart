import 'feeding.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) {
  final day = dateOnly(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class FeedingTotals {
  const FeedingTotals({
    this.count = 0,
    this.breast = Duration.zero,
    this.bottleMl = 0,
    this.breastMilkMl = 0,
  });

  final int count;
  final Duration breast;
  final int bottleMl;
  final int breastMilkMl;

  int get totalMl => bottleMl + breastMilkMl;

  factory FeedingTotals.of(Iterable<Feeding> feedings) {
    var count = 0;
    var breast = Duration.zero;
    var bottle = 0;
    var milk = 0;
    for (final f in feedings) {
      count++;
      switch (f.type) {
        case FeedingType.breast:
          breast += f.breastDuration;
        case FeedingType.bottle:
          bottle += f.amountMl;
        case FeedingType.breastMilk:
          milk += f.amountMl;
      }
    }
    return FeedingTotals(
      count: count,
      breast: breast,
      bottleMl: bottle,
      breastMilkMl: milk,
    );
  }

  FeedingTotals dividedBy(int days) => days <= 0
      ? this
      : FeedingTotals(
          count: (count / days).round(),
          breast: Duration(seconds: (breast.inSeconds / days).round()),
          bottleMl: (bottleMl / days).round(),
          breastMilkMl: (breastMilkMl / days).round(),
        );
}

/// Feedings that started on [day].
List<Feeding> feedingsOnDay(Iterable<Feeding> all, DateTime day) =>
    all.where((f) => isSameDay(f.start, day)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

/// Feedings that started in the Monday-based week beginning [weekStart].
List<Feeding> feedingsInWeek(Iterable<Feeding> all, DateTime weekStart) {
  final from = dateOnly(weekStart);
  final to = DateTime(from.year, from.month, from.day + 7);
  return all
      .where((f) => !f.start.isBefore(from) && f.start.isBefore(to))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '$h h $m m';
  if (m > 0) return s == 0 ? '$m m' : '$m m $s s';
  return '$s s';
}

String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

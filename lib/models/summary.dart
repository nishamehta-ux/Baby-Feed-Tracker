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
    this.breastLeft = Duration.zero,
    this.breastRight = Duration.zero,
    this.breastCount = 0,
    this.bottleMl = 0,
    this.bottleCount = 0,
    this.breastMilkMl = 0,
    this.breastMilkCount = 0,
  });

  final int count;

  /// Breastfeeding time, with the part timed on each side.
  final Duration breast;
  final Duration breastLeft;
  final Duration breastRight;
  final int breastCount;

  /// Formula by bottle.
  final int bottleMl;
  final int bottleCount;

  /// Expressed breast milk by bottle.
  final int breastMilkMl;
  final int breastMilkCount;

  int get totalMl => bottleMl + breastMilkMl;
  int get anyBottleCount => bottleCount + breastMilkCount;

  factory FeedingTotals.of(Iterable<Feeding> feedings) {
    var count = 0, breastCount = 0, bottleCount = 0, milkCount = 0;
    var breast = Duration.zero, left = Duration.zero, right = Duration.zero;
    var bottle = 0, milk = 0;
    for (final f in feedings) {
      count++;
      switch (f.type) {
        case FeedingType.breast:
          breastCount++;
          breast += f.breastDuration;
          left += f.leftDuration;
          right += f.rightDuration;
        case FeedingType.bottle:
          bottleCount++;
          bottle += f.amountMl;
        case FeedingType.breastMilk:
          milkCount++;
          milk += f.amountMl;
      }
    }
    return FeedingTotals(
      count: count,
      breast: breast,
      breastLeft: left,
      breastRight: right,
      breastCount: breastCount,
      bottleMl: bottle,
      bottleCount: bottleCount,
      breastMilkMl: milk,
      breastMilkCount: milkCount,
    );
  }

  /// Averages per day; only the totals the weekly summary uses.
  FeedingTotals dividedBy(int days) => days <= 0
      ? this
      : FeedingTotals(
          count: (count / days).round(),
          breast: Duration(seconds: (breast.inSeconds / days).round()),
          bottleMl: (bottleMl / days).round(),
          breastMilkMl: (breastMilkMl / days).round(),
        );
}

/// "just now", "45 m ago", "3 h 10 m ago", or "on 5 Oct" for older times.
String timeAgo(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} m ago';
  if (d.inHours < 24) {
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${d.inHours} h ago' : '${d.inHours} h $m m ago';
  }
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return 'on ${then.day} ${months[then.month - 1]}';
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
  if (h > 0) return m == 0 ? '$h h' : '$h h $m m';
  if (m > 0) return s == 0 ? '$m m' : '$m m $s s';
  return '$s s';
}

String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

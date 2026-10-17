import 'entry.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) {
  final day = dateOnly(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class Totals {
  const Totals({
    this.count = 0,
    this.breast = Duration.zero,
    this.breastLeft = Duration.zero,
    this.breastRight = Duration.zero,
    this.breastCount = 0,
    this.bottleMl = 0,
    this.bottleCount = 0,
    this.breastMilkMl = 0,
    this.breastMilkCount = 0,
    this.pumpMl = 0,
    this.pumpCount = 0,
    this.diaperCount = 0,
    this.wetCount = 0,
    this.dirtyCount = 0,
    this.bothCount = 0,
    this.routines = const [],
    this.others = const [],
  });

  /// Number of feedings (breast, formula and breast milk).
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

  /// Milk pumped.
  final int pumpMl;
  final int pumpCount;

  /// Diapers; one diaper can count as both wet and dirty.
  final int diaperCount;
  final int wetCount;
  final int dirtyCount;
  final int bothCount;

  /// Routine and Other entries, oldest first.
  final List<Entry> routines;
  final List<Entry> others;

  int get totalMl => bottleMl + breastMilkMl;
  int get anyBottleCount => bottleCount + breastMilkCount;

  factory Totals.of(Iterable<Entry> entries) {
    var count = 0, breastCount = 0, bottleCount = 0, milkCount = 0, pumpCount = 0;
    var diapers = 0, wet = 0, dirty = 0, both = 0;
    var breast = Duration.zero, left = Duration.zero, right = Duration.zero;
    var bottle = 0, milk = 0, pumped = 0;
    final routines = <Entry>[], others = <Entry>[];
    for (final e in entries) {
      if (e.type.isFeeding) count++;
      switch (e.type) {
        case EntryType.breast:
          breastCount++;
          breast += e.breastDuration;
          left += e.leftDuration;
          right += e.rightDuration;
        case EntryType.bottle:
          bottleCount++;
          bottle += e.amountMl;
        case EntryType.breastMilk:
          milkCount++;
          milk += e.amountMl;
        case EntryType.pump:
          pumpCount++;
          pumped += e.amountMl;
        case EntryType.diaper:
          diapers++;
          if (e.diaper?.isWet ?? false) wet++;
          if (e.diaper?.isDirty ?? false) dirty++;
          if (e.diaper == DiaperKind.both) both++;
        case EntryType.routine:
          routines.add(e);
        case EntryType.other:
          others.add(e);
      }
    }
    return Totals(
      count: count,
      breast: breast,
      breastLeft: left,
      breastRight: right,
      breastCount: breastCount,
      bottleMl: bottle,
      bottleCount: bottleCount,
      breastMilkMl: milk,
      breastMilkCount: milkCount,
      pumpMl: pumped,
      pumpCount: pumpCount,
      diaperCount: diapers,
      wetCount: wet,
      dirtyCount: dirty,
      bothCount: both,
      routines: routines,
      others: others,
    );
  }

  /// Averages per day; only the totals the weekly summary uses.
  Totals dividedBy(int days) => days <= 0
      ? this
      : Totals(
          count: (count / days).round(),
          breast: Duration(seconds: (breast.inSeconds / days).round()),
          bottleMl: (bottleMl / days).round(),
          breastMilkMl: (breastMilkMl / days).round(),
          pumpMl: (pumpMl / days).round(),
          diaperCount: (diaperCount / days).round(),
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
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return 'on ${then.day} ${months[then.month - 1]}';
}

/// Feedings that started on [day].
List<Entry> entriesOnDay(Iterable<Entry> all, DateTime day) =>
    all.where((f) => isSameDay(f.start, day)).toList()..sort((a, b) => a.start.compareTo(b.start));

/// Feedings that started in the Monday-based week beginning [weekStart].
List<Entry> entriesInWeek(Iterable<Entry> all, DateTime weekStart) {
  final from = dateOnly(weekStart);
  final to = DateTime(from.year, from.month, from.day + 7);
  return all.where((f) => !f.start.isBefore(from) && f.start.isBefore(to)).toList()
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

/// The name to show for [e] in lists: its routine or what was logged, for
/// those kinds, else the kind of entry.
String entryTitle(Entry e) => switch (e.type) {
      EntryType.routine || EntryType.other => e.title.isEmpty ? e.type.label : e.title,
      _ => e.type.label,
    };

/// One line of detail for [e], e.g. "16 m · L 10 m · R 6 m" or "120 ml".
String entryDetail(Entry e) {
  switch (e.type) {
    case EntryType.breast:
      return [
        formatDuration(e.breastDuration),
        if (e.leftDuration > Duration.zero) 'L ${formatDuration(e.leftDuration)}',
        if (e.rightDuration > Duration.zero) 'R ${formatDuration(e.rightDuration)}',
      ].join(' · ');
    case EntryType.bottle || EntryType.breastMilk:
      return '${e.amountMl} ml';
    case EntryType.pump:
      return [
        if (e.amountMl > 0) '${e.amountMl} ml',
        if (e.leftMl + e.rightMl > 0) 'L ${e.leftMl} ml · R ${e.rightMl} ml',
        if (e.duration > Duration.zero) formatDuration(e.duration),
      ].join(' · ');
    case EntryType.diaper:
      return [e.diaper?.label ?? '', if (e.rash) 'rash'].where((s) => s.isNotEmpty).join(' · ');
    case EntryType.routine || EntryType.other:
      // Routines and Other may be timed, e.g. a nap or a doctor visit.
      return [
        if (e.type == EntryType.other && e.valueWithUnit.isNotEmpty) e.valueWithUnit,
        if (e.duration > Duration.zero) formatDuration(e.duration),
      ].join(' · ');
  }
}

/// Entries that started in [from, to), oldest first.
List<Entry> entriesBetween(Iterable<Entry> all, DateTime from, DateTime to) =>
    all.where((e) => !e.start.isBefore(from) && e.start.isBefore(to)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

/// The baby's age on [now]: "3 days old", "5 weeks old", "4 months old" or
/// "1 year 2 months old".
String ageText(DateTime birth, DateTime now) {
  final days = dateOnly(now).difference(dateOnly(birth)).inDays;
  if (days < 0) return 'Not born yet';
  if (days < 14) return days == 1 ? '1 day old' : '$days days old';
  if (days < 56) return '${days ~/ 7} weeks old';
  var months = (now.year - birth.year) * 12 + now.month - birth.month;
  if (now.day < birth.day) months--;
  if (months < 24) return months == 1 ? '1 month old' : '$months months old';
  final years = months ~/ 12, rest = months % 12;
  final y = years == 1 ? '1 year' : '$years years';
  return rest == 0 ? '$y old' : '$y $rest month${rest == 1 ? '' : 's'} old';
}

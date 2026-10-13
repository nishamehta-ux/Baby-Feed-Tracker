import 'entry.dart';

/// One value at a moment: a reading, or a week's daily average.
class TrendPoint {
  const TrendPoint(this.at, this.value);

  final DateTime at;
  final double value;
}

/// Every numeric reading of one thing logged under Other, e.g. Weight in kg.
class Measurement {
  const Measurement({required this.title, required this.unit, required this.points});

  final String title;
  final String unit;

  /// Oldest first; never empty.
  final List<TrendPoint> points;

  TrendPoint get latest => points.last;
  TrendPoint? get previous => points.length > 1 ? points[points.length - 2] : null;
}

/// Reads an Other entry's value as a number ("3.9", "3,9"), or null.
double? numericValue(Entry e) => double.tryParse(e.value.trim().replaceAll(',', '.'));

/// Groups numeric Other entries by name and unit into series. Only entries
/// that started before [until] count. Series with the most recent reading
/// come first.
List<Measurement> measurementsFrom(Iterable<Entry> entries, {DateTime? until}) {
  final groups = <(String, String), List<TrendPoint>>{};
  for (final e in entries) {
    if (e.type != EntryType.other || e.title.isEmpty) continue;
    if (until != null && !e.start.isBefore(until)) continue;
    final v = numericValue(e);
    if (v == null) continue;
    groups.putIfAbsent((e.title, e.unit), () => []).add(TrendPoint(e.start, v));
  }
  final series = [
    for (final MapEntry(key: (title, unit), value: points) in groups.entries)
      Measurement(
        title: title,
        unit: unit,
        points: points..sort((a, b) => a.at.compareTo(b.at)),
      ),
  ];
  series.sort((a, b) => b.latest.at.compareTo(a.latest.at));
  return series;
}

/// Routine names logged before [until], most often logged first.
List<String> routineNames(Iterable<Entry> entries, {DateTime? until}) {
  final counts = <String, int>{};
  for (final e in entries) {
    if (e.type != EntryType.routine || e.title.isEmpty) continue;
    if (until != null && !e.start.isBefore(until)) continue;
    counts[e.title] = (counts[e.title] ?? 0) + 1;
  }
  return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
}

/// Up to 3 significant decimals, without trailing zeros: 3.9, 37.25, 120.
String formatNumber(double v) {
  final fixed = v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  return fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
}

import 'package:intl/intl.dart';

import 'appointment.dart';
import 'entry.dart';
import 'summary.dart';
import 'trends.dart';

/// A medicine (or vitamin) given, grouped by what was written down.
class MedicineUse {
  const MedicineUse(
      {required this.name, required this.times, required this.first, required this.last});

  final String name;
  final int times;
  final DateTime first;
  final DateTime last;
}

/// Everything a doctor usually asks about, gathered from the log: the latest
/// measurements, every vaccine and medicine, and daily averages for feeds,
/// diapers and sleep over the last [days] finished days.
class Passport {
  const Passport({
    required this.babyName,
    required this.birthDate,
    required this.generatedAt,
    required this.days,
    required this.measurements,
    required this.vaccines,
    required this.medicines,
    required this.averages,
    required this.totals,
    required this.sleepPerDay,
    this.visits = const [],
  });

  final String babyName;
  final DateTime? birthDate;
  final DateTime generatedAt;

  /// Finished days the averages cover (fewer than asked for when the log is
  /// newer than that); 0 when there is nothing to average.
  final int days;

  /// Weight, height, head size and temperature first, then any other numbers.
  final List<Measurement> measurements;

  /// Newest first.
  final List<Entry> vaccines;

  /// Most recently given first.
  final List<MedicineUse> medicines;

  /// Per-day averages over [days].
  final Totals averages;

  /// The sums over [days], for per-day counts [Totals.dividedBy] doesn't keep.
  final Totals totals;

  /// Logged sleep per day, or null when none was logged with a length.
  final Duration? sleepPerDay;

  /// The latest past appointments with visit notes, newest first.
  final List<Appointment> visits;

  static const _measurementOrder = ['Weight', 'Height', 'Head size', 'Temperature'];

  /// Builds the passport as of [now], averaging the [window] finished days
  /// before today.
  factory Passport.from(
    Iterable<Entry> all, {
    required String babyName,
    required DateTime? birthDate,
    required DateTime now,
    int window = 7,
    Iterable<Appointment> appointments = const [],
  }) {
    final entries = all.toList();
    final today = dateOnly(now);

    // Measurements: the standard four first, then the rest, latest first.
    int rank(Measurement m) {
      final i = _measurementOrder.indexOf(m.title);
      return i < 0 ? _measurementOrder.length : i;
    }

    final measurements = measurementsFrom(entries)
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : b.latest.at.compareTo(a.latest.at);
      });

    final vaccines = entries
        .where((e) => e.type == EntryType.other && e.title == 'Vaccine')
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    // Medicines from Other (by what was written), plus vitamins logged as a
    // routine.
    final groups = <String, List<Entry>>{};
    for (final e in entries) {
      final String name;
      if (e.type == EntryType.other && e.title == 'Medicine') {
        name = e.value.trim().isEmpty ? 'Medicine' : e.value.trim();
      } else if (e.type == EntryType.routine && e.title == 'Vitamin or probiotic') {
        name = e.notes.trim().isEmpty ? 'Vitamin or probiotic' : e.notes.trim();
      } else {
        continue;
      }
      groups.putIfAbsent(name.toLowerCase(), () => []).add(e);
    }
    final medicines = [
      for (final list in groups.values)
        () {
          list.sort((a, b) => a.start.compareTo(b.start));
          final name = list.last.title == 'Medicine'
              ? (list.last.value.trim().isEmpty ? 'Medicine' : list.last.value.trim())
              : (list.last.notes.trim().isEmpty ? 'Vitamin or probiotic' : list.last.notes.trim());
          return MedicineUse(
            name: name,
            times: list.length,
            first: list.first.start,
            last: list.last.start,
          );
        }(),
    ]..sort((a, b) => b.last.compareTo(a.last));

    // Averages over finished days, starting no earlier than the first entry.
    var from = DateTime(today.year, today.month, today.day - window);
    if (entries.isNotEmpty) {
      final first = dateOnly(entries.map((e) => e.start).reduce((a, b) => a.isBefore(b) ? a : b));
      if (first.isAfter(from)) from = first;
    }
    final days = today.difference(from).inDays.clamp(0, window);
    final inWindow = entriesBetween(entries, from, today);
    final totals = Totals.of(inWindow);
    final sleep = inWindow
        .where((e) => e.type == EntryType.routine && e.title == 'Sleep')
        .fold(Duration.zero, (sum, e) => sum + e.duration);

    return Passport(
      babyName: babyName,
      birthDate: birthDate,
      generatedAt: now,
      days: days,
      measurements: measurements,
      vaccines: vaccines,
      medicines: medicines,
      averages: days == 0 ? const Totals() : totals.dividedBy(days),
      totals: totals,
      visits: (appointments.where((a) => a.isPast(now) && a.visitNotes.trim().isNotEmpty).toList()
            ..sort((a, b) => b.start.compareTo(a.start)))
          .take(5)
          .toList(),
      sleepPerDay: days == 0 || sleep == Duration.zero
          ? null
          : Duration(minutes: (sleep.inMinutes / days).round()),
    );
  }

  /// [count] over [days] as a short number: "6" or "6.4".
  static String perDay(int count, int days) {
    if (days == 0) return '0';
    final v = count / days;
    return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
  }

  /// The whole passport as plain text, for sharing or pasting.
  String toText() {
    final date = DateFormat('d MMM yyyy');
    final b = StringBuffer()
      ..writeln('Health passport: $babyName')
      ..writeln([
        if (birthDate != null)
          'Born ${date.format(birthDate!)} (${ageText(birthDate!, generatedAt)})',
        'Updated ${date.format(generatedAt)}',
      ].join(' · '));

    b
      ..writeln()
      ..writeln('LATEST MEASUREMENTS');
    if (measurements.isEmpty) b.writeln('None logged');
    for (final m in measurements) {
      final unit = m.unit.isEmpty ? '' : ' ${m.unit}';
      final prev = m.previous;
      final change = prev == null
          ? ''
          : ', ${_signed(m.latest.value - prev.value)}$unit since ${date.format(prev.at)}';
      b.writeln(
          '${m.title}: ${formatNumber(m.latest.value)}$unit (${date.format(m.latest.at)})$change');
    }

    b
      ..writeln()
      ..writeln('VACCINATIONS');
    if (vaccines.isEmpty) b.writeln('None logged');
    for (final v in vaccines) {
      b.writeln('${date.format(v.start)}: ${v.value.trim().isEmpty ? 'Vaccine' : v.value.trim()}');
    }

    b
      ..writeln()
      ..writeln('MEDICINES AND VITAMINS');
    if (medicines.isEmpty) b.writeln('None logged');
    for (final m in medicines) {
      b.writeln('${m.name}: ${_times(m.times)}, last ${date.format(m.last)}'
          '${m.times > 1 ? ' (since ${date.format(m.first)})' : ''}');
    }

    if (visits.isNotEmpty) {
      b
        ..writeln()
        ..writeln('RECENT VISITS');
      for (final v in visits) {
        final who = [v.withWhom, v.place].where((s) => s.isNotEmpty).join(', ');
        b
          ..writeln('${date.format(v.start)}: ${v.title}${who.isEmpty ? '' : ' ($who)'}')
          ..writeln('  ${v.visitNotes.trim().replaceAll('\n', '\n  ')}');
      }
    }

    b
      ..writeln()
      ..writeln(days == 0
          ? 'DAILY AVERAGES: not enough logged yet'
          : 'DAILY AVERAGES (last ${days == 1 ? 'day' : '$days days'})');
    if (days > 0) {
      for (final line in summaryLines()) {
        b.writeln(line);
      }
    }

    b
      ..writeln()
      ..writeln('Logged by parents in Oh baby baby!. Not a medical record.');
    return b.toString().trimRight();
  }

  /// The daily averages, each as a name, its main value and a detail.
  List<({String label, String value, String? detail})> summaryItems() {
    final a = averages, raw = totals;
    String bottles(int n) => '${perDay(n, days)} bottles a day';
    return [
      (label: 'Feeds', value: '${perDay(raw.count, days)} a day', detail: null),
      if (raw.breastCount > 0)
        (
          label: 'Breastfeeding',
          value: '${formatDuration(a.breast)} a day',
          detail: '${perDay(raw.breastCount, days)} sessions a day',
        ),
      if (raw.bottleCount > 0)
        (label: 'Formula', value: '${a.bottleMl} ml a day', detail: bottles(raw.bottleCount)),
      if (raw.breastMilkCount > 0)
        (
          label: 'Breast milk by bottle',
          value: '${a.breastMilkMl} ml a day',
          detail: bottles(raw.breastMilkCount),
        ),
      if (raw.pumpCount > 0) (label: 'Pumped', value: '${a.pumpMl} ml a day', detail: null),
      (
        label: 'Diapers',
        value: '${perDay(raw.diaperCount, days)} a day',
        detail: '${perDay(raw.wetCount, days)} wet, ${perDay(raw.dirtyCount, days)} dirty',
      ),
      if (sleepPerDay != null)
        (label: 'Sleep (logged)', value: '${formatDuration(sleepPerDay!)} a day', detail: null),
    ];
  }

  /// [summaryItems] as text lines: "Diapers: 6 a day (4 wet, 2 dirty)".
  List<String> summaryLines() => [
        for (final i in summaryItems())
          '${i.label}: ${i.value}${i.detail == null ? '' : ' (${i.detail})'}',
      ];

  static String _signed(double v) => v >= 0 ? '+${formatNumber(v)}' : formatNumber(v);
  static String _times(int n) => n == 1 ? 'once' : '$n times';
}

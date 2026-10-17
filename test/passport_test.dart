import 'package:baby_feed_tracker/models/appointment.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/models/passport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 15);
  DateTime day(int ago, [int h = 9]) => DateTime(2026, 10, 17 - ago, h);
  Entry other(String id, int ago, String title, String value, [String unit = '']) => Entry(
        id: id,
        type: EntryType.other,
        start: day(ago),
        end: day(ago),
        title: title,
        value: value,
        unit: unit,
      );

  final entries = <Entry>[
    other('w1', 9, 'Weight', '4.6', 'kg'),
    other('w2', 2, 'Weight', '4.8', 'kg'),
    other('t1', 1, 'Temperature', '37.4', '°C'),
    other('v1', 30, 'Vaccine', 'BCG'),
    other('v2', 3, 'Vaccine', '6-in-1, 1st dose'),
    other('m1', 5, 'Medicine', 'Paracetamol 2.5 ml'),
    other('m2', 4, 'Medicine', 'paracetamol 2.5 ml'),
    Entry(
        id: 'vit',
        type: EntryType.routine,
        start: day(1),
        end: day(1),
        title: 'Vitamin or probiotic',
        notes: 'Vitamin D'),
    // Two days of feeds and diapers inside the window, plus today (left out).
    for (final ago in [1, 2]) ...[
      Entry(
          id: 'b$ago', type: EntryType.bottle, start: day(ago, 6), end: day(ago, 6), amountMl: 120),
      Entry(
          id: 'f$ago',
          type: EntryType.breast,
          start: day(ago, 8),
          end: day(ago, 8).add(const Duration(minutes: 20)),
          leftDuration: const Duration(minutes: 20)),
      Entry(
          id: 'd$ago',
          type: EntryType.diaper,
          start: day(ago, 10),
          end: day(ago, 10),
          diaper: DiaperKind.both),
      Entry(
          id: 's$ago',
          type: EntryType.routine,
          start: day(ago, 13),
          end: day(ago, 13).add(const Duration(hours: 2)),
          title: 'Sleep'),
    ],
    Entry(id: 'today', type: EntryType.bottle, start: day(0, 7), end: day(0, 7), amountMl: 500),
  ];

  test('gathers the latest measurements, vaccines and medicines', () {
    final p = Passport.from(entries, babyName: 'Ava', birthDate: DateTime(2026, 8, 1), now: now);
    expect(p.measurements.first.title, 'Weight'); // weight before temperature
    expect(p.measurements.first.latest.value, 4.8);
    expect(p.vaccines.map((v) => v.value), ['6-in-1, 1st dose', 'BCG']);
    // Same medicine written two ways counts once; the vitamin is included.
    expect(
        p.medicines.map((m) => (m.name, m.times)), [('Vitamin D', 1), ('paracetamol 2.5 ml', 2)]);
  });

  test('averages finished days only, from the first entry', () {
    final p = Passport.from(entries, babyName: 'Ava', birthDate: null, now: now, window: 7);
    expect(p.days, 7);
    // 240 ml of formula over 7 days; today's 500 ml bottle is left out.
    expect(p.averages.bottleMl, 34);
    expect(p.sleepPerDay, const Duration(minutes: 34));

    final short = Passport.from(
        entries.where(
            (e) => e.id != 'v1' && e.id != 'w1' && e.id != 'm1' && e.id != 'm2' && e.id != 'v2'),
        babyName: 'Ava',
        birthDate: null,
        now: now,
        window: 7);
    expect(short.days, 2); // the log only starts two days ago
    expect(short.averages.bottleMl, 120);
    expect(short.summaryLines(), contains('Diapers: 1 a day (1 wet, 1 dirty)'));
  });

  test('shares as readable text', () {
    final text =
        Passport.from(entries, babyName: 'Ava', birthDate: DateTime(2026, 8, 1), now: now).toText();
    expect(text, startsWith('Health passport: Ava'));
    expect(text, contains('Weight: 4.8 kg (15 Oct 2026), +0.2 kg since 8 Oct 2026'));
    expect(text, contains('14 Oct 2026: 6-in-1, 1st dose'));
    expect(text, contains('paracetamol 2.5 ml: 2 times, last 13 Oct 2026 (since 12 Oct 2026)'));
    expect(text, contains('Not a medical record.'));
  });

  test('recent visits with notes are included, newest first', () {
    final p = Passport.from(entries, babyName: 'Ava', birthDate: null, now: now, appointments: [
      Appointment(
          id: '1',
          kind: AppointmentKind.checkup,
          title: 'Newborn check',
          start: day(40),
          visitNotes: 'All fine.'),
      Appointment(
          id: '2',
          kind: AppointmentKind.doctor,
          title: 'Cold',
          start: day(5),
          withWhom: 'Dr Patel',
          visitNotes: 'Saline drops.\nCome back if fever.'),
      Appointment(id: '3', kind: AppointmentKind.checkup, title: 'No notes', start: day(2)),
      Appointment(
          id: '4',
          kind: AppointmentKind.vaccination,
          title: 'Future',
          start: day(-3),
          visitNotes: 'x'),
    ]);
    expect(p.visits.map((v) => v.title), ['Cold', 'Newborn check']);
    final text = p.toText();
    expect(text, contains('RECENT VISITS'));
    expect(text, contains('12 Oct 2026: Cold (Dr Patel)\n  Saline drops.\n  Come back if fever.'));
  });
}

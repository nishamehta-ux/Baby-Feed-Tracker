import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/models/trends.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _other(String id, DateTime at, String title, String value, [String unit = '']) => Entry(
      id: id,
      type: EntryType.other,
      start: at,
      end: at,
      title: title,
      value: value,
      unit: unit,
    );

void main() {
  test('numeric Other entries group into series by name and unit', () {
    final entries = [
      _other('a', DateTime(2026, 10, 1), 'Weight', '3.9', 'kg'),
      _other('b', DateTime(2026, 10, 8), 'Weight', '4,1', 'kg'),
      _other('c', DateTime(2026, 10, 9), 'Temperature', '37.2', '°C'),
      _other('d', DateTime(2026, 10, 9), 'Vaccine', 'DTaP'), // not a number
      _other('e', DateTime(2026, 10, 20), 'Weight', '4.3', 'kg'), // after cutoff
    ];
    final series = measurementsFrom(entries, until: DateTime(2026, 10, 15));

    expect(series.map((m) => m.title), ['Temperature', 'Weight']);
    final weight = series.last;
    expect(weight.points.map((p) => p.value), [3.9, 4.1]);
    expect(weight.previous!.value, 3.9);
    expect(weight.unit, 'kg');
  });

  test('routine names are ordered by how often they were logged', () {
    Entry r(String id, String title) => Entry(
          id: id,
          type: EntryType.routine,
          start: DateTime(2026, 10, 1),
          end: DateTime(2026, 10, 1),
          title: title,
        );
    expect(routineNames([r('1', 'Bath'), r('2', 'Tummy time'), r('3', 'Tummy time')]),
        ['Tummy time', 'Bath']);
  });

  test('formatNumber drops trailing zeros', () {
    expect(formatNumber(3.9), '3.9');
    expect(formatNumber(4.0), '4');
    expect(formatNumber(37.25), '37.25');
    expect(formatNumber(0.2000000001), '0.2');
    expect(formatNumber(120), '120');
  });
}

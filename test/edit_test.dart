import 'package:baby_feed_tracker/data/entry_store.dart';
import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editing a saved entry of each kind and saving it keeps Today on screen.
void main() {
  final now = DateTime.now();
  DateTime at(int h) => DateTime(now.year, now.month, now.day, h);
  final entries = <String, Entry>{
    'Breastfeeding': Entry(
        id: 'b',
        type: EntryType.breast,
        start: at(1),
        end: at(1).add(const Duration(minutes: 10)),
        leftDuration: const Duration(minutes: 10),
        endSide: BreastSide.left),
    'Formula (bottle)':
        Entry(id: 'f', type: EntryType.bottle, start: at(2), end: at(2), amountMl: 90),
    'Pumping': Entry(
        id: 'p',
        type: EntryType.pump,
        start: at(3),
        end: at(3).add(const Duration(minutes: 5)),
        amountMl: 50),
    'Diaper':
        Entry(id: 'd', type: EntryType.diaper, start: at(4), end: at(4), diaper: DiaperKind.wet),
    'Tummy time':
        Entry(id: 'r', type: EntryType.routine, start: at(5), end: at(5), title: 'Tummy time'),
    'Weight': Entry(
        id: 'o',
        type: EntryType.other,
        start: at(6),
        end: at(6),
        title: 'Weight',
        value: '4.2',
        unit: 'kg'),
  };
  for (final MapEntry(key: label, value: e) in entries.entries) {
    testWidgets('edit and save $label', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final store = EntryStore();
      await store.load();
      await store.upsert(e);
      await tester.pumpWidget(BabyFeedTrackerApp(store: store));
      await tester.pumpAndSettle();
      final row = find.text(label).last;
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      // Change something before saving.
      if (label == 'Breastfeeding') {
        await tester.tap(find.text('Start right'));
        await tester.pump(const Duration(seconds: 2));
      } else if (label == 'Formula (bottle)') {
        await tester.tap(find.byTooltip('More'));
        await tester.pump();
      } else if (label == 'Pumping') {
        await tester.tap(find.textContaining('Resume').first);
        await tester.pump(const Duration(seconds: 2));
      }
      // Pick a new start time: day and time in one step.
      final start =
          find.text('Start time').evaluate().isEmpty ? find.text('Time') : find.text('Start time');
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // A quick second tap on Save must not close the page behind the drawer.
      await tester.tap(find.text('Save changes'));
      await tester.tap(find.text('Save changes'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Timeline'), findsOneWidget);
    });
  }
}

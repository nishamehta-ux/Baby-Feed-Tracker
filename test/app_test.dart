import 'package:baby_feed_tracker/data/entry_store.dart';
import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/screens/entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<EntryStore> _startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final store = EntryStore();
  await store.load();
  await tester.pumpWidget(BabyFeedTrackerApp(store: store));
  return store;
}

/// Opens the add drawer and picks a feeding type from it.
Future<void> _openAdd(WidgetTester tester, String option) async {
  await tester.tap(find.text('Add an entry'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('log bottles from the drawer and see them in the summary', (tester) async {
    final store = await _startApp(tester);
    expect(find.text('Nothing logged yet today.'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Add an entry'), findsOneWidget);

    // Formula, 30 ml.
    await _openAdd(tester, 'Bottle feeding');
    expect(find.text('0 ml'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
    }
    expect(find.text('30 ml'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.entries.single.type, EntryType.bottle);
    expect(find.text('Formula (bottle)'), findsOneWidget);
    expect(find.text('Last feeding just now · Formula 30 ml', findRichText: true), findsOneWidget);
    expect(find.text('Bottle 30 ml'), findsOneWidget); // quick-add repeats it

    // Breast milk, reusing the last amount.
    await _openAdd(tester, 'Bottle feeding');
    await tester.tap(find.text('Breast\nmilk'));
    await tester.pump();
    await tester.tap(find.text('Yes'));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(EntrySheet), matching: find.text('30 ml')),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.entries, hasLength(2));
    expect(find.text('60 ml bottle', findRichText: true), findsOneWidget);
    expect(find.text('Breast milk (bottle)'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);

    // The Trends tab lists today; tapping it comes back to the Today summary.
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('Average per day'), findsOneWidget);
    final now = DateTime.now();
    final dayRow = find.byKey(ValueKey('day-${now.year}-${now.month}-${now.day}'));
    expect(find.descendant(of: dayRow, matching: find.text('60 ml')), findsOneWidget);
    await tester.ensureVisible(dayRow);
    await tester.pumpAndSettle();
    await tester.tap(dayRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open on Today to edit'));
    await tester.pumpAndSettle();
    expect(find.text('Timeline'), findsOneWidget);
  });

  testWidgets('breastfeeding needs a timed side before saving', (tester) async {
    final store = await _startApp(tester);

    await _openAdd(tester, 'Breastfeeding');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Start a timer or enter the time for a side.'), findsOneWidget);
    expect(store.entries, isEmpty);

    await tester.tap(find.text('Start left'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = store.entries.single;
    expect(saved.type, EntryType.breast);
    expect(saved.endSide, BreastSide.left);
    expect(saved.leftDuration, greaterThan(Duration.zero));
    expect(find.text('Breastfeeding'), findsWidgets);
  });

  testWidgets('closing a drawer with input asks before discarding', (tester) async {
    final store = await _startApp(tester);

    await _openAdd(tester, 'Bottle feeding');
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this entry?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this entry?'), findsNothing);
    expect(store.entries, isEmpty);
  });

  testWidgets('log a diaper, a pump, a routine and a weight', (tester) async {
    final store = await _startApp(tester);

    // Diaper: wet and dirty with a rash.
    await _openAdd(tester, 'Diaper');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Choose wet, dirty or dry.'), findsOneWidget);
    // The quick-add tiles behind the drawer also say Wet and Dirty.
    await tester.tap(find.text('Wet').last);
    await tester.tap(find.text('Dirty').last);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entries.single.diaper, DiaperKind.both);
    expect(store.entries.single.rash, isTrue);
    expect(find.text('1 diaper', findRichText: true), findsOneWidget);

    // Pumping: 60 ml left and 50 ml right.
    await _openAdd(tester, 'Pumping');
    await tester.tap(find.text('Per side'));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byTooltip('More').first);
      await tester.pump();
    }
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('More').last);
      await tester.pump();
    }
    expect(find.text('Total 110 ml'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final pump = store.entries.firstWhere((e) => e.type == EntryType.pump);
    expect((pump.leftMl, pump.rightMl, pump.amountMl), (60, 50, 110));
    expect(find.text('110 ml pumped', findRichText: true), findsOneWidget);

    // Routine from the presets.
    await _openAdd(tester, 'Routine');
    await tester.tap(find.text('Tummy time'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entries.where((e) => e.type == EntryType.routine).single.title, 'Tummy time');

    // Other: a weight needs a number.
    await _openAdd(tester, 'Other');
    await tester.tap(find.text('Weight'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'heavy');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter the weight as a number.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '3,9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final weight = store.entries.firstWhere((e) => e.type == EntryType.other);
    expect((weight.title, weight.value, weight.unit), ('Weight', '3.9', 'kg'));
    expect(find.text('3.9 kg'), findsOneWidget);
  });

  testWidgets('Other can log something without a preset', (tester) async {
    final store = await _startApp(tester);

    await _openAdd(tester, 'Other');
    await tester.tap(find.text('Something else'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Doctor visit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final e = store.entries.single;
    expect((e.type, e.title, e.value), (EntryType.other, 'Doctor visit', ''));
  });

  testWidgets('trends show measurements and open their chart', (tester) async {
    final store = await _startApp(tester);
    final now = DateTime.now();
    Entry weight(int daysAgo, String kg) => Entry(
          id: 'w$daysAgo',
          type: EntryType.other,
          start: DateTime(now.year, now.month, now.day - daysAgo, 9),
          end: DateTime(now.year, now.month, now.day - daysAgo, 9),
          title: 'Weight',
          value: kg,
          unit: 'kg',
        );
    await store.upsert(weight(14, '3.9'));
    await store.upsert(weight(7, '4.1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    final row = find.text('4.1 kg');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.text('Measurements'), findsOneWidget);
    expect(find.textContaining('+0.2 kg since'), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('All values'), findsOneWidget);
    expect(find.text('3.9 kg'), findsWidgets);
  });

  testWidgets('quick add starts a breastfeeding timer that saves from Today', (tester) async {
    final store = await _startApp(tester);

    await tester.tap(find.text('Breastfeed'));
    await tester.pump();
    expect(store.live?.type, EntryType.breast);
    // Nothing runs until a side is picked.
    expect(find.text('Choose a side to start'), findsOneWidget);
    expect(store.live!.running, isFalse);
    expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Finish')).onPressed, isNull);

    await tester.tap(find.text('Left'));
    await tester.pump();
    expect(find.text('Timing left side'), findsOneWidget);

    // Switch to the right side, let a second pass, then finish and save.
    await tester.tap(find.text('Right'));
    await tester.pump();
    expect(find.text('Timing right side'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.byType(EntrySheet), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = store.entries.single;
    expect(saved.type, EntryType.breast);
    expect(saved.endSide, BreastSide.right);
    expect(saved.rightDuration, greaterThan(Duration.zero));
    expect(store.live, isNull);
  });

  testWidgets('quick add logs a diaper at once, with undo', (tester) async {
    final store = await _startApp(tester);

    // The quick-add row scrolls sideways; bring the tile into view first.
    await tester.ensureVisible(find.text('Wet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wet'));
    await tester.pump();
    expect(store.entries.single.diaper, DiaperKind.wet);
    await tester.pump(const Duration(milliseconds: 750)); // snackbar slides in
    expect(find.text('Logged diaper · wet'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(store.entries, isEmpty);
  });

  testWidgets('tapping a day in trends opens its timeline in a sheet', (tester) async {
    final store = await _startApp(tester);
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 0, 5);
    await store.upsert(Entry(
      id: 'r1',
      type: EntryType.routine,
      start: at,
      end: at,
      title: 'Tummy time',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    final dayRow = find.byKey(ValueKey('day-${now.year}-${now.month}-${now.day}'));
    await tester.ensureVisible(dayRow);
    await tester.pumpAndSettle();
    await tester.tap(dayRow);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('Tummy time')),
      findsOneWidget,
    );

    await tester.tap(find.text('Open on Today to edit'));
    await tester.pumpAndSettle();
    expect(find.text('Timeline'), findsOneWidget);
  });

  testWidgets('trends switch to months', (tester) async {
    await _startApp(tester);
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('This week'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('The small lines show the last 6 months. Tap a row for its chart.'),
        findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('This month'), findsNothing);
  });
}

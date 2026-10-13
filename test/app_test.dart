import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/models/feeding.dart';
import 'package:baby_feed_tracker/screens/feeding_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FeedingStore> _startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final store = FeedingStore();
  await store.load();
  await tester.pumpWidget(BabyFeedTrackerApp(store: store));
  return store;
}

/// Opens the add drawer and picks a feeding type from it.
Future<void> _openAdd(WidgetTester tester, String option) async {
  await tester.tap(find.text('Add a feeding'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('log bottles from the drawer and see them in the summary', (tester) async {
    final store = await _startApp(tester);
    expect(find.text('Nothing logged yet today.'), findsOneWidget);

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

    expect(store.feedings.single.type, FeedingType.bottle);
    expect(find.text('Bottle feeding'), findsOneWidget);
    expect(find.text('30 ml formula'), findsOneWidget);

    // Breast milk, reusing the last amount.
    await _openAdd(tester, 'Bottle feeding');
    await tester.tap(find.text('Breast\nmilk'));
    await tester.pump();
    await tester.tap(find.text('Yes'));
    await tester.pump();
    expect(
      find.descendant(of: find.byType(FeedingSheet), matching: find.text('30 ml')),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.feedings, hasLength(2));
    expect(find.text('60 ml total'), findsOneWidget);
    expect(find.text('30 ml breast milk'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);

    // The week tab lists today; tapping it comes back to the Today summary.
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly summary'), findsOneWidget);
    final dayRow = find.textContaining('30 ml formula · 30 ml breast milk');
    await tester.ensureVisible(dayRow);
    await tester.pumpAndSettle();
    await tester.tap(dayRow);
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsOneWidget);
  });

  testWidgets('breastfeeding needs a timed side before saving', (tester) async {
    final store = await _startApp(tester);

    await _openAdd(tester, 'Breastfeeding');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Start a timer or enter the time for a side.'), findsOneWidget);
    expect(store.feedings, isEmpty);

    await tester.tap(find.text('Start left'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = store.feedings.single;
    expect(saved.type, FeedingType.breast);
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
    expect(find.text('Discard this feeding?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this feeding?'), findsNothing);
    expect(store.feedings, isEmpty);
  });
}

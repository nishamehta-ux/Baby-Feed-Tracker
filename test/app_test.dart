import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/models/feeding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('add a bottle feeding and see it in the totals', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = FeedingStore();
    await store.load();

    await tester.pumpWidget(BabyFeedTrackerApp(store: store));
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Formula: 0 ml'), findsWidgets);

    await tester.tap(find.text('Add a feeding'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bottle feeding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bottle feeding'));
    await tester.pumpAndSettle();
    expect(find.text('30 ml'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('40 ml'), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.feedings, hasLength(1));
    expect(store.feedings.single.type, FeedingType.bottle);
    expect(find.text('Formula: 40 ml'), findsWidgets);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Bottle feeding'), findsOneWidget);
    expect(find.text('Breastfeeding'), findsOneWidget);
    expect(find.text('Formula: 40 ml'), findsWidgets);
  });

  testWidgets('bottle tab can log expressed breast milk', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = FeedingStore();
    await store.load();
    await tester.pumpWidget(BabyFeedTrackerApp(store: store));

    await tester.tap(find.text('Add a feeding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bottle feeding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breast milk'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.feedings.single.type, FeedingType.breastMilk);
    expect(store.feedings.single.amountMl, 30);
    expect(find.text('Breast milk: 30 ml'), findsWidgets);
  });

  testWidgets('breastfeeding requires end side', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = FeedingStore();
    await store.load();
    await tester.pumpWidget(BabyFeedTrackerApp(store: store));

    await tester.tap(find.text('Add a feeding'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Please choose which breast you ended with.'), findsOneWidget);
    expect(store.feedings, isEmpty);
  });
}

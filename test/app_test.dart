import 'package:baby_feed_tracker/data/entry_store.dart';
import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/models/appointment.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/models/family.dart';
import 'package:baby_feed_tracker/screens/entry_sheet.dart';
import 'package:baby_feed_tracker/screens/passport_screen.dart';
import 'package:baby_feed_tracker/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
    }
    expect(find.text('30'), findsOneWidget);
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
      find.descendant(of: find.byType(EntrySheet), matching: find.text('30')),
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

  testWidgets('profile switches appearance and remembers it', (tester) async {
    final store = await _startApp(tester);
    expect(AppColors.dark, isFalse);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.appearance, Appearance.dark);
    expect(AppColors.dark, isTrue);

    final reloaded = EntryStore();
    await reloaded.load();
    expect(reloaded.appearance, Appearance.dark);

    await store.setAppearance(Appearance.system);
    await tester.pumpAndSettle();
    expect(AppColors.dark, isFalse);
  });

  testWidgets('sign in and log out from the profile tab', (tester) async {
    final store = await _startApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('You are not signed in'), findsOneWidget);

    final signIn = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(signIn);
    await tester.pumpAndSettle();
    await tester.tap(signIn);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Sam');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in').last);
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sam@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in').last);
    await tester.pumpAndSettle();
    expect(store.account?.email, 'sam@example.com');
    expect(find.text('sam@example.com'), findsWidgets);

    final logOut = find.widgetWithText(OutlinedButton, 'Log out');
    await tester.ensureVisible(logOut);
    await tester.pumpAndSettle();
    await tester.tap(logOut);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();
    expect(store.account, isNull);
    expect(find.text('You are not signed in'), findsOneWidget);
  });

  testWidgets('birth date shows the age on Today', (tester) async {
    final store = await _startApp(tester);
    final now = DateTime.now();
    await store.setBirthDate(DateTime(now.year, now.month, now.day - 21));
    await tester.pumpAndSettle();
    expect(find.text('3 weeks old'), findsWidgets);
  });

  testWidgets('bottle amount can be typed', (tester) async {
    final store = await _startApp(tester);
    await _openAdd(tester, 'Bottle feeding');
    await tester.enterText(
      find.descendant(of: find.byType(EntrySheet), matching: find.byType(TextField)).first,
      '125',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(find.text('135'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.entries.single.amountMl, 135);
  });

  testWidgets('a timed sleep shows as time a day in trends', (tester) async {
    final store = await _startApp(tester);
    await _openAdd(tester, 'Routine');
    await tester.tap(find.text('Sleep'));
    await tester.pump();
    await tester.tap(find.byTooltip('Enter the time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 min'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('45 m'), findsWidgets); // end time row
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final sleep = store.entries.single;
    expect((sleep.title, sleep.duration), ('Sleep', const Duration(minutes: 45)));
    expect(find.text('45 m'), findsOneWidget); // timeline detail

    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final dayRow = find.byKey(ValueKey('day-${now.year}-${now.month}-${now.day}'));
    await tester.ensureVisible(dayRow);
    await tester.pumpAndSettle();
    expect(find.descendant(of: dayRow, matching: find.text('Sleep 45m')), findsOneWidget);
    expect(find.textContaining('a day'), findsWidgets);
  });

  testWidgets('quick add puts the most used first', (tester) async {
    final store = await _startApp(tester);
    double x(String text) => tester.getTopLeft(find.text(text).first).dx;
    // Default order before anything is logged.
    expect(x('Breastfeed'), lessThan(x('Pump')));

    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      final t = now.subtract(Duration(hours: i + 1));
      await store.upsert(
          Entry(id: 'd$i', type: EntryType.diaper, start: t, end: t, diaper: DiaperKind.dirty));
    }
    final p = now.subtract(const Duration(hours: 5));
    await store.upsert(Entry(id: 'p', type: EntryType.pump, start: p, end: p, amountMl: 50));
    await tester.pumpAndSettle();

    // Dirty diapers (3), then pumping (1), then the rest in default order.
    expect(x('Dirty'), lessThan(x('Pump')));
    expect(x('Pump'), lessThan(x('Breastfeed')));
    expect(x('Breastfeed'), lessThan(x('Wet')));
  });

  testWidgets('health passport opens from profile and copies its summary', (tester) async {
    final store = await _startApp(tester);
    final t = DateTime.now().subtract(const Duration(days: 2));
    await store.upsert(
        Entry(id: 'v', type: EntryType.other, start: t, end: t, title: 'Vaccine', value: 'BCG'));
    await store.upsert(Entry(
        id: 'w',
        type: EntryType.other,
        start: t,
        end: t,
        title: 'Weight',
        value: '4.2',
        unit: 'kg'));
    await tester.pumpAndSettle();

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Health passport'));
    await tester.pumpAndSettle();
    expect(find.text('BCG'), findsOneWidget);
    expect(find.text('4.2 kg'), findsOneWidget);
    expect(find.text('No medicines logged yet.'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, contains('BCG'));
    expect(find.text('Copied. Paste it into a message or email.'), findsOneWidget);
  });

  testWidgets('invite someone by email from the family card', (tester) async {
    final store = await _startApp(tester);
    await store.signIn(const Account(name: 'Nisha', email: 'nisha@example.com'));
    await tester.pumpAndSettle();
    // No email app in tests: the launcher says it couldn't open one.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => false,
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final invite = find.text('Invite someone');
    await tester.ensureVisible(invite);
    await tester.pumpAndSettle();
    await tester.tap(invite);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Their name'), 'Raj');
    await tester.enterText(find.widgetWithText(TextField, 'Their email'), 'nisha@example.com');
    await tester.tap(find.text('Send invite'));
    await tester.pump();
    expect(find.text('This person is already in your family.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Their email'), 'raj@example.com');
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();

    // No email app in tests: the invite is copied instead.
    final raj = store.family.single;
    expect((raj.name, raj.email, raj.access), ('Raj', 'raj@example.com', Access.edit));
    expect(find.textContaining('The invite is copied'), findsOneWidget);
    expect(find.text('raj@example.com · Can add and edit'), findsOneWidget);
  });

  testWidgets('join a family with a code', (tester) async {
    final store = await _startApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final join = find.text('Got an invite? Join a family');
    await tester.ensureVisible(join);
    await tester.pumpAndSettle();
    await tester.tap(join);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'k7q');
    await tester.tap(find.text('Join'));
    await tester.pump();
    expect(find.text('The code has 6 letters and numbers.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'k7q 2mx');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(store.joinCode, 'K7Q2MX');
    expect(find.textContaining('Joining with code K7Q2MX'), findsOneWidget);
  });

  testWidgets('add, edit and delete an appointment in the calendar', (tester) async {
    final store = await _startApp(tester);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing planned.'), findsOneWidget);

    await tester.tap(find.text('Add appointment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaccination'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Where'), 'Riverside clinic');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final a = store.appointments.single;
    expect((a.kind, a.title, a.place),
        (AppointmentKind.vaccination, 'Vaccination', 'Riverside clinic'));
    expect(find.text('NEXT UP'), findsOneWidget);

    // Edit from the day's list, then delete.
    await tester.ensureVisible(find.text('Vaccination').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaccination').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'What'), '8-week jabs');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(store.appointments.single.title, '8-week jabs');

    await tester.ensureVisible(find.text('8-week jabs').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('8-week jabs').last);
    await tester.pumpAndSettle();
    final delete = find.text('Delete appointment');
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.appointments, isEmpty);
  });

  testWidgets('today shows the next appointment within a week', (tester) async {
    final store = await _startApp(tester);
    final soon = DateTime.now().add(const Duration(days: 3));
    await store.saveAppointment(Appointment(
      id: 'a',
      kind: AppointmentKind.checkup,
      title: '2-month check-up',
      start: DateTime(soon.year, soon.month, soon.day, 10, 30),
    ));
    await store.saveAppointment(Appointment(
      id: 'b',
      kind: AppointmentKind.doctor,
      title: 'Far away',
      start: DateTime.now().add(const Duration(days: 30)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('2-month check-up', findRichText: true), findsOneWidget);
    expect(find.textContaining('in 3 days', findRichText: true), findsOneWidget);
    expect(find.textContaining('Far away', findRichText: true), findsNothing);

    // Dismissing hides it, and it stays hidden after a restart.
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2-month check-up', findRichText: true), findsNothing);
    final reloaded = EntryStore();
    await reloaded.load();
    expect(reloaded.dismissedAppointment, 'a');

    // The calendar still has it.
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('NEXT UP'), findsOneWidget);
  });

  testWidgets('visit notes after an appointment', (tester) async {
    final store = await _startApp(tester);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await store.saveAppointment(Appointment(
      id: 'v',
      kind: AppointmentKind.checkup,
      title: '6-week check',
      start: DateTime(yesterday.year, yesterday.month, yesterday.day, 10),
      withWhom: 'Dr Patel',
    ));
    await tester.pumpAndSettle();

    // Today stays clean; the visit's row in the calendar invites notes.
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    final add = find.text('Add visit notes').last;
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    // Notes come before the appointment's details.
    expect(
      tester.getTopLeft(find.text('Visit notes')).dy,
      lessThan(tester.getTopLeft(find.text('Appointment details')).dy),
    );
    expect(find.text('Visit notes'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Weight on track. Next vaccines at 12 weeks.'),
        'Gaining well. Start tummy time twice a day.');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(store.appointments.single.visitNotes, 'Gaining well. Start tummy time twice a day.');

    // The calendar's past visits show the notes instead of the prompt.
    final notes = find.text('Gaining well. Start tummy time twice a day.');
    await tester.ensureVisible(notes.last);
    expect(notes, findsWidgets);
    expect(find.text('PAST VISITS'), findsOneWidget);
    expect(find.text('Add visit notes'), findsNothing);

    // And so does the health passport.
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Health passport'));
    await tester.pumpAndSettle();
    final recent = find.text('Recent visits');
    await tester.scrollUntilVisible(recent, 300,
        scrollable: find
            .descendant(of: find.byType(PassportScreen), matching: find.byType(Scrollable))
            .first);
    expect(recent, findsOneWidget);
  });

  testWidgets('breastfeeding total time can be entered by hand', (tester) async {
    final store = await _startApp(tester);
    await _openAdd(tester, 'Breastfeeding');
    // Ended on right, then type the total.
    await tester.tap(find.text('Right').last);
    await tester.pump();
    final total = find.text('Total time');
    await tester.ensureVisible(total);
    await tester.pumpAndSettle();
    await tester.tap(total);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 min'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('15 m'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final e = store.entries.single;
    expect((e.breastDuration, e.rightDuration, e.endSide),
        (const Duration(minutes: 15), const Duration(minutes: 15), BreastSide.right));
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

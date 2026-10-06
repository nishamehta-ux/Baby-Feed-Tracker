import 'package:flutter/material.dart';

import 'data/feeding_store.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = FeedingStore();
  await store.load();
  runApp(BabyFeedTrackerApp(store: store));
}

class BabyFeedTrackerApp extends StatelessWidget {
  const BabyFeedTrackerApp({super.key, required this.store});

  final FeedingStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Feed Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(store: store),
    );
  }
}

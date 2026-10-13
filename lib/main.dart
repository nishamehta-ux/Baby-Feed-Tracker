import 'package:flutter/material.dart';

import 'data/entry_store.dart';
import 'screens/main_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = EntryStore();
  await store.load();
  runApp(BabyFeedTrackerApp(store: store));
}

class BabyFeedTrackerApp extends StatelessWidget {
  const BabyFeedTrackerApp({super.key, required this.store});

  final EntryStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oh baby baby!',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: MainShell(store: store),
    );
  }
}

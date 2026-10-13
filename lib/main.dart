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

class BabyFeedTrackerApp extends StatefulWidget {
  const BabyFeedTrackerApp({super.key, required this.store});

  final EntryStore store;

  @override
  State<BabyFeedTrackerApp> createState() => _BabyFeedTrackerAppState();
}

class _BabyFeedTrackerAppState extends State<BabyFeedTrackerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The phone switched between light and dark.
  @override
  void didChangePlatformBrightness() => setState(() {});

  bool get _isDark => switch (widget.store.appearance) {
        Appearance.light => false,
        Appearance.dark => true,
        Appearance.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final dark = _isDark;
        AppColors.dark = dark;
        return MaterialApp(
          // Widgets read the palette as they build, so a switch between light
          // and dark rebuilds the whole app.
          key: ValueKey(dark),
          title: 'Oh baby baby!',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: MainShell(store: widget.store),
        );
      },
    );
  }
}

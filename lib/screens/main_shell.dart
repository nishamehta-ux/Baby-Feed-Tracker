import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../models/summary.dart';
import '../theme.dart';
import 'today_screen.dart';
import 'week_screen.dart';

/// Bottom navigation between the Today landing page and the weekly summary.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final FeedingStore store;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  /// The day shown on the Today tab. The week tab sets it when a day is tapped.
  final _day = ValueNotifier<DateTime>(dateOnly(DateTime.now()));

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }

  void _openDay(DateTime day) {
    _day.value = day;
    setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(store: widget.store, day: _day),
          WeekScreen(store: widget.store, onOpenDay: _openDay),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.banner,
        onDestinationSelected: (i) {
          // Coming back to Today from the tab bar shows today again.
          if (i == 0 && _tab != 0) _day.value = dateOnly(DateTime.now());
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Week',
          ),
        ],
      ),
    );
  }
}

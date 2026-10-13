import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/entry_store.dart';
import '../models/summary.dart';
import '../theme.dart';
import 'entry_sheet.dart';
import 'profile_screen.dart';
import 'today_screen.dart';
import 'trends_screen.dart';

/// Bottom navigation between the Today landing page and Trends.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.store});

  final EntryStore store;

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
    // Status bar icons that show on the page colour.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            TodayScreen(
              store: widget.store,
              day: _day,
              onOpenProfile: () => setState(() => _tab = 2),
            ),
            TrendsScreen(store: widget.store, onOpenDay: _openDay),
            ProfileScreen(store: widget.store),
          ],
        ),
        // Adding an entry is the main action on Today.
        floatingActionButton: _tab == 0
            ? FloatingActionButton.extended(
                onPressed: () => showAddMenu(context, widget.store),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add an entry'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.selected,
          onDestinationSelected: (i) {
            // Coming back to Today from the tab bar shows today again.
            if (i == 0 && _tab != 0) _day.value = dateOnly(DateTime.now());
            setState(() => _tab = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Trends',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';
import '../models/live_timer.dart';

/// Holds every logged entry in memory and persists it locally.
class EntryStore extends ChangeNotifier {
  // The key predates non-feeding entries; kept so existing data still loads.
  static const _feedingsKey = 'feedings_v1';
  static const _babyNameKey = 'baby_name';
  static const _liveKey = 'live_timer';

  SharedPreferences? _prefs;
  final List<Entry> _entries = [];
  String _babyName = 'My baby';
  LiveTimer? _live;

  List<Entry> get entries => List.unmodifiable(_entries);
  String get babyName => _babyName;

  /// The breastfeeding or pumping timer started from Today, if any.
  LiveTimer? get live => _live;

  Entry? get lastFeeding => lastWhere((e) => e.type.isFeeding);

  /// The most recent entry (by start time) that matches [test].
  Entry? lastWhere(bool Function(Entry f) test) {
    Entry? last;
    for (final f in _entries) {
      if (test(f) && (last == null || f.start.isAfter(last.start))) last = f;
    }
    return last;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_feedingsKey);
    _entries.clear();
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _entries.addAll(
        list.map((e) => Entry.fromJson(e as Map<String, dynamic>)),
      );
    }
    _babyName = _prefs!.getString(_babyNameKey) ?? _babyName;
    final live = _prefs!.getString(_liveKey);
    _live = live == null ? null : LiveTimer.fromJson(jsonDecode(live) as Map<String, dynamic>);
    notifyListeners();
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> upsert(Entry feeding) async {
    final i = _entries.indexWhere((f) => f.id == feeding.id);
    if (i >= 0) {
      _entries[i] = feeding;
    } else {
      _entries.add(feeding);
    }
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _entries.removeWhere((f) => f.id == id);
    notifyListeners();
    await _save();
  }

  /// Starts, replaces or updates the live timer; null clears it.
  Future<void> setLive(LiveTimer? timer) async {
    _live = timer;
    notifyListeners();
    if (timer == null) {
      await _prefs?.remove(_liveKey);
    } else {
      await _prefs?.setString(_liveKey, jsonEncode(timer.toJson()));
    }
  }

  Future<void> setBabyName(String name) async {
    _babyName = name.trim().isEmpty ? 'My baby' : name.trim();
    notifyListeners();
    await _prefs?.setString(_babyNameKey, _babyName);
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _feedingsKey,
      jsonEncode(_entries.map((f) => f.toJson()).toList()),
    );
  }
}

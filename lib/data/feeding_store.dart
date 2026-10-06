import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feeding.dart';

/// Holds all feedings in memory and persists them locally.
class FeedingStore extends ChangeNotifier {
  static const _feedingsKey = 'feedings_v1';
  static const _babyNameKey = 'baby_name';

  SharedPreferences? _prefs;
  final List<Feeding> _feedings = [];
  String _babyName = 'My baby';

  List<Feeding> get feedings => List.unmodifiable(_feedings);
  String get babyName => _babyName;

  Feeding? get lastFeeding {
    if (_feedings.isEmpty) return null;
    return _feedings.reduce((a, b) => a.start.isAfter(b.start) ? a : b);
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_feedingsKey);
    _feedings.clear();
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _feedings.addAll(
        list.map((e) => Feeding.fromJson(e as Map<String, dynamic>)),
      );
    }
    _babyName = _prefs!.getString(_babyNameKey) ?? _babyName;
    notifyListeners();
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> upsert(Feeding feeding) async {
    final i = _feedings.indexWhere((f) => f.id == feeding.id);
    if (i >= 0) {
      _feedings[i] = feeding;
    } else {
      _feedings.add(feeding);
    }
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _feedings.removeWhere((f) => f.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> setBabyName(String name) async {
    _babyName = name.trim().isEmpty ? 'My baby' : name.trim();
    notifyListeners();
    await _prefs?.setString(_babyNameKey, _babyName);
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _feedingsKey,
      jsonEncode(_feedings.map((f) => f.toJson()).toList()),
    );
  }
}

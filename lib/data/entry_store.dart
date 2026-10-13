import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';
import '../models/live_timer.dart';

/// Light or dark colours: following the phone's setting, or fixed.
enum Appearance {
  system('Match phone'),
  light('Light'),
  dark('Dark');

  const Appearance(this.label);

  final String label;
}

/// Holds every logged entry in memory and persists it locally.
class EntryStore extends ChangeNotifier {
  // The key predates non-feeding entries; kept so existing data still loads.
  static const _feedingsKey = 'feedings_v1';
  static const _babyNameKey = 'baby_name';
  static const _liveKey = 'live_timer';
  static const _appearanceKey = 'appearance';
  static const _birthDateKey = 'baby_birth_date';
  static const _photoKey = 'baby_photo';
  static const _accountKey = 'account';

  SharedPreferences? _prefs;
  final List<Entry> _entries = [];
  String _babyName = 'My baby';
  LiveTimer? _live;
  Appearance _appearance = Appearance.system;
  DateTime? _birthDate;
  Uint8List? _photo;
  Account? _account;

  List<Entry> get entries => List.unmodifiable(_entries);
  String get babyName => _babyName;
  Appearance get appearance => _appearance;

  /// The baby's date of birth, if set.
  DateTime? get birthDate => _birthDate;

  /// The baby's photo (JPEG or PNG bytes), if set.
  Uint8List? get photo => _photo;

  /// Who is signed in; null when signed out. Accounts live on this device
  /// until the server is connected.
  Account? get account => _account;

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
    _appearance =
        Appearance.values.asNameMap()[_prefs!.getString(_appearanceKey)] ?? Appearance.system;
    final birth = _prefs!.getString(_birthDateKey);
    _birthDate = birth == null ? null : DateTime.tryParse(birth);
    final photo = _prefs!.getString(_photoKey);
    _photo = photo == null ? null : base64Decode(photo);
    final account = _prefs!.getString(_accountKey);
    _account =
        account == null ? null : Account.fromJson(jsonDecode(account) as Map<String, dynamic>);
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

  Future<void> setAppearance(Appearance appearance) async {
    _appearance = appearance;
    notifyListeners();
    await _prefs?.setString(_appearanceKey, appearance.name);
  }

  Future<void> setBirthDate(DateTime? date) async {
    _birthDate = date;
    notifyListeners();
    if (date == null) {
      await _prefs?.remove(_birthDateKey);
    } else {
      await _prefs?.setString(_birthDateKey, date.toIso8601String());
    }
  }

  Future<void> setPhoto(Uint8List? bytes) async {
    _photo = bytes;
    notifyListeners();
    if (bytes == null) {
      await _prefs?.remove(_photoKey);
    } else {
      await _prefs?.setString(_photoKey, base64Encode(bytes));
    }
  }

  /// Signs in on this device. Entries are kept either way.
  Future<void> signIn(Account account) async {
    _account = account;
    notifyListeners();
    await _prefs?.setString(_accountKey, jsonEncode(account.toJson()));
  }

  /// Signs out. Entries and the baby's profile stay on the device.
  Future<void> signOut() async {
    _account = null;
    notifyListeners();
    await _prefs?.remove(_accountKey);
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _feedingsKey,
      jsonEncode(_entries.map((f) => f.toJson()).toList()),
    );
  }
}

/// The signed-in parent or carer.
class Account {
  const Account({required this.name, required this.email});

  final String name;
  final String email;

  Map<String, dynamic> toJson() => {'name': name, 'email': email};

  factory Account.fromJson(Map<String, dynamic> json) =>
      Account(name: json['name'] as String? ?? '', email: json['email'] as String? ?? '');
}

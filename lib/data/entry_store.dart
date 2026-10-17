import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';
import '../models/entry.dart';
import '../models/family.dart';
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
  static const _familyKey = 'family';
  static const _joinCodeKey = 'join_code';
  static const _appointmentsKey = 'appointments';

  SharedPreferences? _prefs;
  final List<Entry> _entries = [];
  String _babyName = 'My baby';
  LiveTimer? _live;
  Appearance _appearance = Appearance.system;
  DateTime? _birthDate;
  Uint8List? _photo;
  Account? _account;
  final List<Caregiver> _family = [];
  String? _joinCode;
  final List<Appointment> _appointments = [];

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

  /// People invited to help track the baby, oldest invite first.
  List<Caregiver> get family => List.unmodifiable(_family);

  /// Calendar appointments, soonest first.
  List<Appointment> get appointments =>
      List.unmodifiable(_appointments.toList()..sort((a, b) => a.start.compareTo(b.start)));

  /// The next appointment from [now] (including one in the last hour, which
  /// may still be going on), or null.
  Appointment? nextAppointment(DateTime now) {
    final from = now.subtract(const Duration(hours: 1));
    for (final a in appointments) {
      if (!a.start.isBefore(from)) return a;
    }
    return null;
  }

  /// A code entered under Join a family, waiting for syncing to connect.
  String? get joinCode => _joinCode;

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
    final family = _prefs!.getString(_familyKey);
    _family
      ..clear()
      ..addAll(family == null
          ? const []
          : (jsonDecode(family) as List<dynamic>)
              .map((e) => Caregiver.fromJson(e as Map<String, dynamic>)));
    _joinCode = _prefs!.getString(_joinCodeKey);
    final appointments = _prefs!.getString(_appointmentsKey);
    _appointments
      ..clear()
      ..addAll(appointments == null
          ? const []
          : (jsonDecode(appointments) as List<dynamic>)
              .map((e) => Appointment.fromJson(e as Map<String, dynamic>)));
    final live = _prefs!.getString(_liveKey);
    _live = live == null ? null : LiveTimer.fromJson(jsonDecode(live) as Map<String, dynamic>);
    notifyListeners();
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Adds or replaces [feeding]. New entries are credited to whoever is
  /// signed in; an edit keeps the original author.
  Future<void> upsert(Entry feeding) async {
    final i = _entries.indexWhere((f) => f.id == feeding.id);
    var entry = feeding;
    if (entry.by.isEmpty) {
      final author = i >= 0 ? _entries[i].by : (_account?.name ?? '');
      if (author.isNotEmpty) entry = entry.withAuthor(author);
    }
    if (i >= 0) {
      _entries[i] = entry;
    } else {
      _entries.add(entry);
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

  /// Adds or updates someone in the family (an invite, or a resend).
  Future<void> saveCaregiver(Caregiver c) async {
    final i = _family.indexWhere((f) => f.id == c.id);
    if (i >= 0) {
      _family[i] = c;
    } else {
      _family.add(c);
    }
    notifyListeners();
    await _saveFamily();
  }

  Future<void> removeCaregiver(String id) async {
    _family.removeWhere((f) => f.id == id);
    notifyListeners();
    await _saveFamily();
  }

  Future<void> _saveFamily() =>
      _prefs?.setString(_familyKey, jsonEncode(_family.map((f) => f.toJson()).toList())) ??
      Future.value();

  Future<void> saveAppointment(Appointment a) async {
    final i = _appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      _appointments[i] = a;
    } else {
      _appointments.add(a);
    }
    notifyListeners();
    await _saveAppointments();
  }

  Future<void> deleteAppointment(String id) async {
    _appointments.removeWhere((a) => a.id == id);
    notifyListeners();
    await _saveAppointments();
  }

  Future<void> _saveAppointments() =>
      _prefs?.setString(
          _appointmentsKey, jsonEncode(_appointments.map((a) => a.toJson()).toList())) ??
      Future.value();

  /// Keeps a join code until syncing can use it; null clears it.
  Future<void> setJoinCode(String? code) async {
    _joinCode = code;
    notifyListeners();
    if (code == null) {
      await _prefs?.remove(_joinCodeKey);
    } else {
      await _prefs?.setString(_joinCodeKey, code);
    }
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

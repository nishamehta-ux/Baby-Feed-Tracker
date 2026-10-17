/// Everything the app can log. The first three are feedings.
enum EntryType {
  breast('Breastfeeding', 'Breastfeeding'),
  bottle('Formula (bottle)', 'Formula'),
  breastMilk('Breast milk (bottle)', 'Breast milk'),
  pump('Pumping', 'Pumping'),
  diaper('Diaper', 'Diaper'),
  routine('Routine', 'Routine'),
  other('Other', 'Other');

  const EntryType(this.label, this.shortLabel);

  final String label;
  final String shortLabel;

  bool get isFeeding => this == breast || this == bottle || this == breastMilk;
  bool get isBottle => this == bottle || this == breastMilk;
}

enum BreastSide { left, right }

/// What was in a diaper. Wet and dirty together is [both].
enum DiaperKind {
  wet('Wet'),
  dirty('Dirty'),
  both('Wet and dirty'),
  dry('Dry');

  const DiaperKind(this.label);

  final String label;

  bool get isWet => this == wet || this == both;
  bool get isDirty => this == dirty || this == both;
}

class Entry {
  Entry({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    this.leftDuration = Duration.zero,
    this.rightDuration = Duration.zero,
    this.endSide,
    this.amountMl = 0,
    this.leftMl = 0,
    this.rightMl = 0,
    this.diaper,
    this.rash = false,
    this.title = '',
    this.value = '',
    this.unit = '',
    this.notes = '',
    this.by = '',
  });

  final String id;
  final EntryType type;
  final DateTime start;

  /// Equals [start] for entries without a duration.
  final DateTime end;

  /// Breastfeeding: time on each side.
  final Duration leftDuration;
  final Duration rightDuration;
  final BreastSide? endSide;

  /// Bottle: amount given. Pumping: total amount pumped.
  final int amountMl;

  /// Pumping: amount from each side, when recorded per side.
  final int leftMl;
  final int rightMl;

  /// Diaper.
  final DiaperKind? diaper;
  final bool rash;

  /// Routine: its name ("Bath"). Other: what was logged ("Weight", "Vaccine").
  final String title;

  /// Other: the reading or detail ("3.9", "DTaP") and its unit ("kg").
  final String value;
  final String unit;

  final String notes;

  /// Who logged it (their name), when someone was signed in.
  final String by;

  /// This entry with [by] set.
  Entry withAuthor(String name) => Entry(
        id: id,
        type: type,
        start: start,
        end: end,
        leftDuration: leftDuration,
        rightDuration: rightDuration,
        endSide: endSide,
        amountMl: amountMl,
        leftMl: leftMl,
        rightMl: rightMl,
        diaper: diaper,
        rash: rash,
        title: title,
        value: value,
        unit: unit,
        notes: notes,
        by: name,
      );

  bool get isBottle => type.isBottle;
  Duration get duration => end.difference(start).isNegative ? Duration.zero : end.difference(start);

  /// Time spent breastfeeding. Uses the per-side timers when they were used,
  /// otherwise falls back to the start/end window.
  Duration get breastDuration {
    if (type != EntryType.breast) return Duration.zero;
    final sides = leftDuration + rightDuration;
    return sides > Duration.zero ? sides : duration;
  }

  /// "3.9 kg", "DTaP", or "" for an Other entry.
  String get valueWithUnit => [value, unit].where((s) => s.isNotEmpty).join(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'leftMs': leftDuration.inMilliseconds,
        'rightMs': rightDuration.inMilliseconds,
        'endSide': endSide?.name,
        'amountMl': amountMl,
        'leftMl': leftMl,
        'rightMl': rightMl,
        'diaper': diaper?.name,
        'rash': rash,
        'title': title,
        'value': value,
        'unit': unit,
        'notes': notes,
        if (by.isNotEmpty) 'by': by,
      };

  /// Reads entries saved by any version of the app; fields added later
  /// default to empty.
  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        id: json['id'] as String,
        type: EntryType.values.byName(json['type'] as String),
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        leftDuration: Duration(milliseconds: json['leftMs'] as int? ?? 0),
        rightDuration: Duration(milliseconds: json['rightMs'] as int? ?? 0),
        endSide:
            json['endSide'] == null ? null : BreastSide.values.byName(json['endSide'] as String),
        amountMl: json['amountMl'] as int? ?? 0,
        leftMl: json['leftMl'] as int? ?? 0,
        rightMl: json['rightMl'] as int? ?? 0,
        diaper: json['diaper'] == null ? null : DiaperKind.values.byName(json['diaper'] as String),
        rash: json['rash'] as bool? ?? false,
        title: json['title'] as String? ?? '',
        value: json['value'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        by: json['by'] as String? ?? '',
      );
}

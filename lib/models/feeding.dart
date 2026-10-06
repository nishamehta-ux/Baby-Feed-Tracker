enum FeedingType {
  breast('Breastfeeding', 'Breast'),
  bottle('Bottle feeding', 'Bottle'),
  breastMilk('Breast milk (bottle)', 'Breast milk');

  const FeedingType(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

enum BreastSide { left, right }

class Feeding {
  Feeding({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    this.leftDuration = Duration.zero,
    this.rightDuration = Duration.zero,
    this.endSide,
    this.amountMl = 0,
    this.notes = '',
  });

  final String id;
  final FeedingType type;
  final DateTime start;
  final DateTime end;

  /// Breastfeeding only.
  final Duration leftDuration;
  final Duration rightDuration;
  final BreastSide? endSide;

  /// Bottle and breast milk only.
  final int amountMl;

  final String notes;

  bool get isBottle => type != FeedingType.breast;

  /// Time spent breastfeeding. Uses the per-side timers when they were used,
  /// otherwise falls back to the start/end window.
  Duration get breastDuration {
    if (type != FeedingType.breast) return Duration.zero;
    final sides = leftDuration + rightDuration;
    if (sides > Duration.zero) return sides;
    final window = end.difference(start);
    return window.isNegative ? Duration.zero : window;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'leftMs': leftDuration.inMilliseconds,
        'rightMs': rightDuration.inMilliseconds,
        'endSide': endSide?.name,
        'amountMl': amountMl,
        'notes': notes,
      };

  factory Feeding.fromJson(Map<String, dynamic> json) => Feeding(
        id: json['id'] as String,
        type: FeedingType.values.byName(json['type'] as String),
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        leftDuration: Duration(milliseconds: json['leftMs'] as int? ?? 0),
        rightDuration: Duration(milliseconds: json['rightMs'] as int? ?? 0),
        endSide: json['endSide'] == null
            ? null
            : BreastSide.values.byName(json['endSide'] as String),
        amountMl: json['amountMl'] as int? ?? 0,
        notes: json['notes'] as String? ?? '',
      );
}

/// Kinds of appointment, each with a default title.
enum AppointmentKind {
  checkup('Check-up'),
  vaccination('Vaccination'),
  doctor('Doctor visit'),
  specialist('Specialist'),
  hearing('Hearing or eye test'),
  other('Other');

  const AppointmentKind(this.label);

  final String label;
}

/// Something in the calendar: a check-up, a vaccination, a doctor visit.
/// Unlike entries, which log what happened, appointments are mostly ahead.
class Appointment {
  const Appointment({
    required this.id,
    required this.kind,
    required this.title,
    required this.start,
    this.withWhom = '',
    this.place = '',
    this.notes = '',
  });

  final String id;
  final AppointmentKind kind;

  /// What it is, e.g. "2-month check-up"; defaults to the kind's label.
  final String title;
  final DateTime start;

  /// Doctor, nurse or clinic person.
  final String withWhom;
  final String place;
  final String notes;

  bool isPast(DateTime now) => start.isBefore(now);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'start': start.toIso8601String(),
        'with': withWhom,
        'place': place,
        'notes': notes,
      };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        kind: AppointmentKind.values.asNameMap()[json['kind']] ?? AppointmentKind.other,
        title: json['title'] as String? ?? '',
        start: DateTime.parse(json['start'] as String),
        withWhom: json['with'] as String? ?? '',
        place: json['place'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

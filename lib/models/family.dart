import 'dart:math';

/// What someone in the family can do.
enum Access {
  edit('Can add and edit'),
  view('View only');

  const Access(this.label);

  final String label;
}

/// Someone invited to help track the baby.
class Caregiver {
  const Caregiver({
    required this.id,
    required this.name,
    required this.email,
    required this.access,
    required this.code,
    required this.invitedAt,
    this.joined = false,
  });

  final String id;
  final String name;
  final String email;
  final Access access;

  /// Entered on their phone to join; also in the invitation email.
  final String code;
  final DateTime invitedAt;

  /// Set once they have joined (when syncing is available).
  final bool joined;

  Caregiver copyWith({DateTime? invitedAt, Access? access}) => Caregiver(
        id: id,
        name: name,
        email: email,
        access: access ?? this.access,
        code: code,
        invitedAt: invitedAt ?? this.invitedAt,
        joined: joined,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'access': access.name,
        'code': code,
        'invitedAt': invitedAt.toIso8601String(),
        'joined': joined,
      };

  factory Caregiver.fromJson(Map<String, dynamic> json) => Caregiver(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        access: Access.values.asNameMap()[json['access']] ?? Access.edit,
        code: json['code'] as String? ?? '',
        invitedAt: DateTime.tryParse(json['invitedAt'] as String? ?? '') ?? DateTime.now(),
        joined: json['joined'] as bool? ?? false,
      );
}

/// A six-character join code without look-alike letters (no 0/O, 1/I/L).
String newInviteCode([Random? random]) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = random ?? Random.secure();
  return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Normalises a typed code: "k7q 2mx" → "K7Q2MX".
String cleanInviteCode(String typed) => typed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// The invitation email for [to], sent by [from] for [baby].
({String subject, String body}) inviteEmail({
  required Caregiver to,
  required String from,
  required String baby,
}) {
  final first = to.name.trim().split(' ').first;
  return (
    subject: '$from invited you to help track $baby',
    body: '''Hi $first,

$from has invited you to help track $baby in Oh baby baby!, so you can both log feeds, diapers, sleep and more and see the same timeline.

Your access: ${to.access.label}

To join:
1. Open Oh baby baby! on your phone.
2. Go to Profile, then Join a family.
3. Enter this code: ${to.code}

See you there!''',
  );
}

import 'entry.dart';

/// A breastfeeding or pumping timer started from the Today page. It lives
/// outside any drawer, so it keeps running while the app is used for other
/// things or closed, until it is finished (and saved) or discarded.
class LiveTimer {
  const LiveTimer({
    required this.type,
    required this.start,
    this.left = Duration.zero,
    this.right = Duration.zero,
    this.side,
    this.since,
  });

  /// [EntryType.breast] or [EntryType.pump].
  final EntryType type;

  /// When the timer was first started; the entry's start time.
  final DateTime start;

  /// Time already counted. Breastfeeding splits it by side; pumping uses
  /// [left] for its single timer.
  final Duration left;
  final Duration right;

  /// Breastfeeding: the side being timed now, or last timed while paused.
  final BreastSide? side;

  /// When the current run began; null while paused.
  final DateTime? since;

  bool get running => since != null;

  /// Opened but not started: no side chosen yet and nothing counted.
  bool get notStarted => !running && left == Duration.zero && right == Duration.zero;

  /// A timer waiting for a side (breastfeeding) or a tap on Start (pumping).
  /// Nothing is counted until then.
  factory LiveTimer.ready(EntryType type, DateTime now) => LiveTimer(type: type, start: now);

  /// Time on [side] (breastfeeding), counting the current run.
  Duration onSide(BreastSide s, DateTime now) {
    final base = s == BreastSide.left ? left : right;
    return running && side == s ? base + now.difference(since!) : base;
  }

  Duration total(DateTime now) => type == EntryType.pump
      ? left + (running ? now.difference(since!) : Duration.zero)
      : onSide(BreastSide.left, now) + onSide(BreastSide.right, now);

  /// The running time folded into the counted totals, and paused.
  LiveTimer paused(DateTime now) {
    if (!running) return this;
    final run = now.difference(since!);
    if (type == EntryType.pump) return _copy(left: left + run, since: null);
    return side == BreastSide.right
        ? _copy(right: right + run, since: null)
        : _copy(left: left + run, since: null);
  }

  /// Breastfeeding: pause if [s] is the side running, else time [s].
  /// Pumping: pause or resume.
  LiveTimer toggled(DateTime now, [BreastSide? s]) {
    final wasRunningSide = running && (type == EntryType.pump || side == s);
    final p = paused(now);
    if (wasRunningSide) return p;
    return LiveTimer(
      type: type,
      // The entry starts when timing does, not when the card was opened.
      start: notStarted ? now : start,
      left: p.left,
      right: p.right,
      side: type == EntryType.breast ? (s ?? side ?? BreastSide.left) : null,
      since: now,
    );
  }

  /// The entry this timer would save, for the drawer to review.
  Entry toDraft(DateTime now, String id) {
    final p = paused(now);
    return Entry(
      id: id,
      type: type,
      start: start,
      end: start.add(p.total(now)),
      leftDuration: type == EntryType.breast ? p.left : Duration.zero,
      rightDuration: type == EntryType.breast ? p.right : Duration.zero,
      endSide: type == EntryType.breast ? side : null,
    );
  }

  LiveTimer _copy({Duration? left, Duration? right, required DateTime? since}) => LiveTimer(
        type: type,
        start: start,
        left: left ?? this.left,
        right: right ?? this.right,
        side: side,
        since: since,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'start': start.toIso8601String(),
        'leftMs': left.inMilliseconds,
        'rightMs': right.inMilliseconds,
        'side': side?.name,
        'since': since?.toIso8601String(),
      };

  factory LiveTimer.fromJson(Map<String, dynamic> json) => LiveTimer(
        type: EntryType.values.byName(json['type'] as String),
        start: DateTime.parse(json['start'] as String),
        left: Duration(milliseconds: json['leftMs'] as int? ?? 0),
        right: Duration(milliseconds: json['rightMs'] as int? ?? 0),
        side: json['side'] == null ? null : BreastSide.values.byName(json['side'] as String),
        since: json['since'] == null ? null : DateTime.parse(json['since'] as String),
      );
}

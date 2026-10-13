import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/models/live_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 13, 9);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  test('a ready timer counts nothing until a side is picked', () {
    final opened = DateTime(2026, 1, 1, 10);
    final ready = LiveTimer.ready(EntryType.breast, opened);
    expect(ready.notStarted, isTrue);
    expect(ready.total(opened.add(const Duration(minutes: 5))), Duration.zero);

    final picked = opened.add(const Duration(minutes: 2));
    final started = ready.toggled(picked, BreastSide.right);
    expect(started.notStarted, isFalse);
    expect(started.start, picked);
    expect(started.side, BreastSide.right);
    expect(started.onSide(BreastSide.right, picked.add(const Duration(minutes: 3))),
        const Duration(minutes: 3));
  });

  test('breastfeeding counts time per side across switches and pauses', () {
    var live = LiveTimer(type: EntryType.breast, start: t0, side: BreastSide.left, since: t0);
    live = live.toggled(at(10), BreastSide.right); // 10 m left, now right
    live = live.toggled(at(16), BreastSide.right); // pause after 6 m right
    expect(live.running, isFalse);
    expect(live.onSide(BreastSide.left, at(30)), const Duration(minutes: 10));
    expect(live.onSide(BreastSide.right, at(30)), const Duration(minutes: 6));
    live = live.toggled(at(30), BreastSide.left); // resume left
    expect(live.total(at(32)), const Duration(minutes: 18));

    final draft = live.toDraft(at(32), 'x');
    expect(draft.leftDuration, const Duration(minutes: 12));
    expect(draft.rightDuration, const Duration(minutes: 6));
    expect(draft.endSide, BreastSide.left);
    expect(draft.end, at(18));
  });

  test('pumping uses one timer', () {
    var live = LiveTimer(type: EntryType.pump, start: t0, since: t0);
    live = live.toggled(at(12)); // pause
    live = live.toggled(at(20)); // resume
    expect(live.total(at(23)), const Duration(minutes: 15));
  });

  test('survives a round trip through JSON', () {
    final live = LiveTimer(
      type: EntryType.breast,
      start: t0,
      left: const Duration(minutes: 3),
      side: BreastSide.right,
      since: at(3),
    );
    final back = LiveTimer.fromJson(live.toJson());
    expect(back.total(at(5)), live.total(at(5)));
    expect(back.side, BreastSide.right);
  });
}

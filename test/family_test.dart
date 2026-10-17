import 'dart:math';

import 'package:baby_feed_tracker/data/entry_store.dart';
import 'package:baby_feed_tracker/models/entry.dart';
import 'package:baby_feed_tracker/models/family.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('invite codes avoid look-alike characters and clean up when typed', () {
    final code = newInviteCode(Random(1));
    expect(code, hasLength(6));
    expect(code, isNot(contains(RegExp('[01ILO]'))));
    expect(cleanInviteCode(' k7q-2mx '), 'K7Q2MX');
  });

  test('the invitation email names the sender, baby, access and code', () {
    final mail = inviteEmail(
      to: Caregiver(
        id: '1',
        name: 'Raj Mehta',
        email: 'raj@example.com',
        access: Access.edit,
        code: 'K7Q2MX',
        invitedAt: DateTime(2026, 10, 17),
      ),
      from: 'Nisha',
      baby: 'Ava',
    );
    expect(mail.subject, 'Nisha invited you to help track Ava');
    expect(mail.body, startsWith('Hi Raj,'));
    expect(mail.body, contains('Can add and edit'));
    expect(mail.body, contains('Enter this code: K7Q2MX'));
  });

  test('new entries are credited to whoever is signed in; edits keep the author', () async {
    SharedPreferences.setMockInitialValues({});
    final store = EntryStore();
    await store.load();
    await store.signIn(const Account(name: 'Nisha', email: 'n@example.com'));
    final t = DateTime(2026, 10, 17, 9);
    await store
        .upsert(Entry(id: 'a', type: EntryType.diaper, start: t, end: t, diaper: DiaperKind.wet));
    expect(store.entries.single.by, 'Nisha');

    await store.signIn(const Account(name: 'Raj', email: 'r@example.com'));
    await store
        .upsert(Entry(id: 'a', type: EntryType.diaper, start: t, end: t, diaper: DiaperKind.dirty));
    expect(store.entries.single.by, 'Nisha');

    // Family and the join code survive a restart.
    await store.saveCaregiver(Caregiver(
        id: 'c',
        name: 'Raj',
        email: 'r@example.com',
        access: Access.view,
        code: 'ABCDEF',
        invitedAt: t));
    await store.setJoinCode('K7Q2MX');
    final again = EntryStore();
    await again.load();
    expect(again.family.single.access, Access.view);
    expect(again.joinCode, 'K7Q2MX');
    expect(again.entries.single.by, 'Nisha');
  });
}

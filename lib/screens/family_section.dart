import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/entry_store.dart';
import '../models/family.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

/// The Family card on Profile: who is tracking the baby, inviting someone by
/// email, and joining someone else's family with a code.
class FamilyCard extends StatelessWidget {
  const FamilyCard({super.key, required this.store});

  final EntryStore store;

  Future<void> _invite(BuildContext context) async {
    // Invitations come from someone: sign in first if needed.
    if (store.account == null && !await promptSignIn(context, store)) return;
    if (!context.mounted) return;
    final invite = await showModalBottomSheet<Caregiver>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _InviteSheet(store: store),
    );
    if (invite == null || !context.mounted) return;
    await store.saveCaregiver(invite);
    if (context.mounted) await sendInvite(context, store, invite);
  }

  @override
  Widget build(BuildContext context) {
    final account = store.account;
    final code = store.joinCode;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Track ${store.babyName} together. Invite a partner, grandparent or nanny to add '
            'and see entries.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          _MemberRow(
            initial: account?.name ?? 'You',
            name: account == null ? 'You' : '${account.name} (you)',
            detail: account?.email ?? 'Not signed in',
            badge: 'Owner',
          ),
          for (final c in store.family)
            _MemberRow(
              initial: c.name,
              name: c.name,
              detail: '${c.email} · ${c.access.label}',
              badge: c.joined ? null : 'Invited ${DateFormat('d MMM').format(c.invitedAt)}',
              onTap: () => _showMemberActions(context, store, c),
            ),
          if (code != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 20, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Joining with code $code. This connects as soon as syncing between phones '
                      'is turned on.',
                      style: TextStyle(fontSize: AppText.label, color: AppColors.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => store.setJoinCode(null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _invite(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: const Text('Invite someone'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (context) => _JoinSheet(store: store),
              ),
              child: const Text('Got an invite? Join a family'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the email app with the invitation for [c]; if there is no email
/// app, copies it instead. Updates the invite date.
Future<void> sendInvite(BuildContext context, EntryStore store, Caregiver c) async {
  final messenger = ScaffoldMessenger.of(context);
  final mail = inviteEmail(to: c, from: store.account?.name ?? 'A parent', baby: store.babyName);
  final uri = Uri.parse('mailto:${Uri.encodeComponent(c.email)}'
      '?subject=${Uri.encodeComponent(mail.subject)}&body=${Uri.encodeComponent(mail.body)}');
  var opened = false;
  try {
    // Don't wait forever on a launcher that never answers.
    opened = await launchUrl(uri).timeout(const Duration(seconds: 5), onTimeout: () => false);
  } catch (_) {
    opened = false;
  }
  await store.saveCaregiver(c.copyWith(invitedAt: DateTime.now()));
  if (!opened) {
    await Clipboard.setData(ClipboardData(text: '${mail.subject}\n\n${mail.body}'));
    messenger.showSnackBar(SnackBar(
      content: Text('No email app found. The invite is copied: paste it into a message to '
          '${c.name}.'),
    ));
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text('Invite for ${c.name} is ready in your email app. Press send.')),
    );
  }
}

Future<void> _showMemberActions(BuildContext context, EntryStore store, Caregiver c) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(c.name, style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child:
                Text('${c.email} · join code ${c.code}', style: TextStyle(color: AppColors.muted)),
          ),
          if (!c.joined)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.forward_to_inbox_rounded, color: AppColors.ink),
              title: const Text('Send the invite again'),
              onTap: () => Navigator.pop(context, 'resend'),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.swap_horiz_rounded, color: AppColors.ink),
            title:
                Text(c.access == Access.edit ? 'Change to view only' : 'Allow adding and editing'),
            onTap: () => Navigator.pop(context, 'access'),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.person_remove_rounded, color: AppColors.danger),
            title: Text(c.joined ? 'Remove from family' : 'Cancel invite',
                style: TextStyle(color: AppColors.danger)),
            onTap: () => Navigator.pop(context, 'remove'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'resend':
      await sendInvite(context, store, c);
    case 'access':
      await store
          .saveCaregiver(c.copyWith(access: c.access == Access.edit ? Access.view : Access.edit));
    case 'remove':
      await store.removeCaregiver(c.id);
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.initial,
    required this.name,
    required this.detail,
    this.badge,
    this.onTap,
  });

  final String initial;
  final String name;
  final String detail;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final letter = initial.trim().isEmpty ? '?' : initial.trim()[0].toUpperCase();
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.selected,
              foregroundColor: AppColors.onSelected,
              child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(detail,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppText.label, color: AppColors.muted)),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tag,
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    Text(badge!, style: TextStyle(fontSize: AppText.caption, color: AppColors.ink)),
              ),
            ],
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.store});

  final EntryStore store;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  Access _access = Access.edit;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter their name.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    final lower = email.toLowerCase();
    if (lower == widget.store.account?.email.toLowerCase() ||
        widget.store.family.any((f) => f.email.toLowerCase() == lower)) {
      setState(() => _error = 'This person is already in your family.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(
      context,
      Caregiver(
        id: widget.store.newId(),
        name: name,
        email: email,
        access: _access,
        code: newInviteCode(),
        invitedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite someone', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              "We'll open your email app with an invitation and a join code.",
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Their name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Their email'),
            ),
            const SizedBox(height: 16),
            Text('What they can do', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<Access>(
                showSelectedIcon: false,
                segments: [
                  for (final a in Access.values) ButtonSegment(value: a, label: Text(a.label)),
                ],
                selected: {_access},
                onSelectionChanged: (v) => setState(() => _access = v.first),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text('Send invite'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.store});

  final EntryStore store;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = cleanInviteCode(_code.text);
    if (code.length != 6) {
      setState(() => _error = 'The code has 6 letters and numbers.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await widget.store.setJoinCode(code);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Join a family', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Enter the code from your invitation email.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(
                fontSize: AppText.headline, fontWeight: FontWeight.w800, letterSpacing: 6),
            decoration: const InputDecoration(hintText: 'K7Q2MX'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

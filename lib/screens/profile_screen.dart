import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/entry_store.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';

/// The third tab: the baby's profile (photo, name, birth date), the app's
/// appearance, and signing in and out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.store});

  final EntryStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(height: 22),
                const SizedBox(height: 16),
                Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                _BabyCard(store: store),
                const SizedBox(height: 28),
                const SectionLabel('Appearance'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Appearance>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(backgroundColor: AppColors.surface),
                    segments: [
                      for (final a in Appearance.values)
                        ButtonSegment(value: a, label: Text(a.label)),
                    ],
                    selected: {store.appearance},
                    onSelectionChanged: (v) => store.setAppearance(v.first),
                  ),
                ),
                const SizedBox(height: 28),
                const SectionLabel('Account'),
                const SizedBox(height: 10),
                _AccountCard(store: store),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a dialog to rename the baby.
Future<void> editBabyName(BuildContext context, EntryStore store) async {
  final controller = TextEditingController(text: store.babyName);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Baby's name"),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name != null) await store.setBabyName(name);
}

class _BabyCard extends StatelessWidget {
  const _BabyCard({required this.store});

  final EntryStore store;

  Future<void> _pickPhoto(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Kept small: the photo is stored on the device with the entries.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (file == null) return;
      await store.setPhoto(await file.readAsBytes());
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't open your photos.")));
    }
  }

  Future<void> _pickBirthDate(BuildContext context) async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: store.birthDate ?? today,
      firstDate: DateTime(today.year - 6),
      lastDate: today,
      helpText: 'Date of birth',
    );
    if (picked != null) await store.setBirthDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final birth = store.birthDate;
    return AppCard(
      child: Column(
        children: [
          // Photo with a small button to change it.
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _pickPhoto(context),
                child: BabyAvatar(photo: store.photo, size: 104),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: IconButton.filled(
                  tooltip: store.photo == null ? 'Add a photo' : 'Change photo',
                  onPressed: () => _pickPhoto(context),
                  icon: const Icon(Icons.photo_camera_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    side: BorderSide(color: AppColors.surface, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            store.babyName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (birth != null)
            Text(
              ageText(birth, DateTime.now()),
              style: TextStyle(color: AppColors.muted),
            ),
          const SizedBox(height: 16),
          _Row(
            label: 'Name',
            value: store.babyName,
            onTap: () => editBabyName(context, store),
          ),
          _Row(
            label: 'Date of birth',
            value: birth == null ? 'Add' : DateFormat('d MMMM yyyy').format(birth),
            onTap: () => _pickBirthDate(context),
          ),
          if (store.photo != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => store.setPhoto(null),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove photo'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

/// A label and value in a card, tappable to change the value.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.store});

  final EntryStore store;

  Future<void> _signIn(BuildContext context) async {
    final account = await showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _SignInSheet(),
    );
    if (account != null) await store.signIn(account);
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("Your entries and the baby's profile stay on this phone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) await store.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final account = store.account;
    if (account == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are not signed in', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Everything you log is saved on this phone. Sign in to add your name and email.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _signIn(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }
    final initial = account.name.trim().isEmpty ? '?' : account.name.trim()[0].toUpperCase();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.selected,
                foregroundColor: AppColors.onSelected,
                child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      account.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.divider, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet();

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
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
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    Navigator.pop(context, Account(name: name, email: email));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign in', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

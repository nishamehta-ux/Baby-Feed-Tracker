import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/entry_store.dart';
import '../models/appointment.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';

IconData iconForAppointment(AppointmentKind kind) => switch (kind) {
      AppointmentKind.checkup => Icons.child_care_rounded,
      AppointmentKind.vaccination => Icons.vaccines_rounded,
      AppointmentKind.doctor => Icons.medical_services_rounded,
      AppointmentKind.specialist => Icons.medical_information_rounded,
      AppointmentKind.hearing => Icons.hearing_rounded,
      AppointmentKind.other => Icons.event_rounded,
    };

/// "today", "tomorrow", "in 4 days", "2 days ago".
String relativeDay(DateTime when, DateTime now) {
  final days = dateOnly(when).difference(dateOnly(now)).inDays;
  return switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    -1 => 'yesterday',
    > 1 => 'in $days days',
    _ => '${-days} days ago',
  };
}

/// The Calendar tab: a month of appointments, the chosen day's list and
/// what's coming up next.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store});

  final EntryStore store;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // first of the month shown
  late DateTime _selected;

  EntryStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _selected = today;
    _month = DateTime(today.year, today.month);
  }

  void _shiftMonth(int by) => setState(() => _month = DateTime(_month.year, _month.month + by));

  /// Opens [a]; a past one without visit notes opens ready to write them.
  void _open(Appointment a, DateTime now) => showAppointmentSheet(
        context,
        store,
        existing: a,
        writeVisitNotes: a.isPast(now) && a.visitNotes.trim().isEmpty,
      );

  void _select(DateTime day) => setState(() {
        _selected = day;
        _month = DateTime(day.year, day.month);
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final all = store.appointments;
        final next = store.nextAppointment(now);
        final onDay = all.where((a) => isSameDay(a.start, _selected)).toList();
        final upcoming = all.where((a) => !a.start.isBefore(dateOnly(now))).toList();
        final pastVisits = all.where((a) => a.isPast(now)).toList().reversed.toList();
        final notesDue = store.visitNotesDue(now);
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add-appointment',
            onPressed: () => showAppointmentSheet(context, store, day: _selected),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add appointment'),
          ),
          body: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(height: 22),
                    const SizedBox(height: 16),
                    Text('Calendar', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 20),
                    if (next != null) ...[
                      const SectionLabel('Next up'),
                      const SizedBox(height: 10),
                      _NextCard(
                        appointment: next,
                        now: now,
                        onTap: () => _select(dateOnly(next.start)),
                      ),
                      const SizedBox(height: 24),
                    ],
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MonthGrid(
                            month: _month,
                            selected: _selected,
                            today: dateOnly(now),
                            busy: {for (final a in all) dateOnly(a.start)},
                            onSelect: _select,
                            onShift: _shiftMonth,
                          ),
                          const SizedBox(height: 16),
                          Divider(color: AppColors.divider, height: 1),
                          const SizedBox(height: 16),
                          Text(
                            isSameDay(_selected, now)
                                ? 'Today'
                                : DateFormat('EEEE d MMMM').format(_selected),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          if (onDay.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text('Nothing planned.',
                                  style: TextStyle(color: AppColors.muted)),
                            )
                          else
                            for (final a in onDay)
                              _AppointmentTile(
                                appointment: a,
                                now: now,
                                showDay: false,
                                onTap: () => _open(a, now),
                              ),
                        ],
                      ),
                    ),
                    if (upcoming.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const SectionLabel('Upcoming'),
                      const SizedBox(height: 10),
                      AppCard(
                        child: Column(
                          children: [
                            for (final a in upcoming.take(10))
                              _AppointmentTile(
                                appointment: a,
                                now: now,
                                showDay: true,
                                onTap: () => _open(a, now),
                              ),
                          ],
                        ),
                      ),
                    ],
                    // Every past appointment with what was said there.
                    if (pastVisits.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const SectionLabel('Past visits'),
                      const SizedBox(height: 10),
                      // A recent visit still without notes: ask how it went.
                      if (notesDue != null) ...[
                        _NotesReminder(appointment: notesDue, onTap: () => _open(notesDue, now)),
                        const SizedBox(height: 10),
                      ],
                      AppCard(
                        child: Column(
                          children: [
                            for (final a in pastVisits.take(20))
                              _AppointmentTile(
                                appointment: a,
                                now: now,
                                showDay: true,
                                onTap: () => _open(a, now),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotesReminder extends StatelessWidget {
  const _NotesReminder({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.selected,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Icon(Icons.sticky_note_2_rounded, color: AppColors.onSelected, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How was the ${appointment.title}?',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSelected),
                    ),
                    Text(
                      'Add visit notes while you remember what was said.',
                      style: TextStyle(fontSize: AppText.label, color: AppColors.onSelected),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.onSelected, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.appointment, required this.now, required this.onTap});

  final Appointment appointment;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _KindIcon(kind: a.kind, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${DateFormat('EEE d MMM · HH:mm').format(a.start)} · ${relativeDay(a.start, now)}',
                      style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                    ),
                    if (a.withWhom.isNotEmpty || a.place.isNotEmpty)
                      Text(
                        [a.withWhom, a.place].where((s) => s.isNotEmpty).join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppText.label, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind, this.size = 36});

  final AppointmentKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.selected, shape: BoxShape.circle),
      child: Icon(iconForAppointment(kind), size: size * 0.5, color: AppColors.onSelected),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.now,
    required this.showDay,
    required this.onTap,
  });

  final Appointment appointment;
  final DateTime now;
  final bool showDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final past = a.isPast(now);
    final when = showDay
        ? DateFormat('EEE d MMM · HH:mm').format(a.start)
        : DateFormat('HH:mm').format(a.start);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Opacity(opacity: past ? 0.55 : 1, child: _KindIcon(kind: a.kind)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: past ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                  Text(
                    [when, a.withWhom, a.place].where((s) => s.isNotEmpty).join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppText.label, color: AppColors.muted),
                  ),
                  if (past && a.visitNotes.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sticky_note_2_rounded, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              a.visitNotes.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppText.label, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (past)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Add visit notes',
                        style: TextStyle(
                          fontSize: AppText.label,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A month of days, Monday first, with a dot under days that have
/// appointments.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.busy,
    required this.onSelect,
    required this.onShift,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final Set<DateTime> busy;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - DateTime.monday;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            RoundIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous month',
              onPressed: () => onShift(-1),
            ),
            const SizedBox(width: 4),
            RoundIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next month',
              onPressed: () => onShift(1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final n in names)
              Expanded(
                child: Center(
                  child: Text(
                    n,
                    style: TextStyle(
                      fontSize: AppText.label,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: () {
                    final n = r * 7 + c - lead + 1;
                    if (n < 1 || n > daysInMonth) return const SizedBox(height: 46);
                    final day = DateTime(month.year, month.month, n);
                    final isSelected = day == selected;
                    final isToday = day == today;
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: DateFormat('EEEE d MMMM').format(day),
                      child: InkWell(
                        onTap: () => onSelect(day),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          height: 46,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? AppColors.selected : null,
                                  border: isToday && !isSelected
                                      ? Border.all(color: AppColors.primary, width: 1.5)
                                      : null,
                                ),
                                child: ExcludeSemantics(
                                  child: Text(
                                    '$n',
                                    style: TextStyle(
                                      fontWeight:
                                          isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                                      color: isSelected ? AppColors.onSelected : AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: busy.contains(day) ? AppColors.primary : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }(),
                ),
            ],
          ),
      ],
    );
  }
}

/// Opens the form to add an appointment on [day], or to edit [existing].
/// [writeVisitNotes] puts the cursor in the visit notes straight away.
Future<void> showAppointmentSheet(
  BuildContext context,
  EntryStore store, {
  Appointment? existing,
  DateTime? day,
  bool writeVisitNotes = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppointmentSheet(
      store: store,
      existing: existing,
      day: day,
      writeVisitNotes: writeVisitNotes,
    ),
  );
}

class _AppointmentSheet extends StatefulWidget {
  const _AppointmentSheet({
    required this.store,
    this.existing,
    this.day,
    this.writeVisitNotes = false,
  });

  final EntryStore store;
  final Appointment? existing;
  final DateTime? day;
  final bool writeVisitNotes;

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  late AppointmentKind _kind;
  late DateTime _start;
  late final TextEditingController _title;
  late final TextEditingController _with;
  late final TextEditingController _place;
  late final TextEditingController _notes;
  late final TextEditingController _visit;
  bool _titleEdited = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _kind = e?.kind ?? AppointmentKind.checkup;
    if (e != null) {
      _start = e.start;
    } else {
      final day = widget.day ?? dateOnly(now);
      // Today: the next full hour; another day: 9 in the morning.
      _start = isSameDay(day, now)
          ? DateTime(now.year, now.month, now.day, now.hour + 1)
          : DateTime(day.year, day.month, day.day, 9);
    }
    _title = TextEditingController(text: e?.title ?? _kind.label);
    _titleEdited = e != null && e.title != e.kind.label;
    _with = TextEditingController(text: e?.withWhom ?? '');
    _place = TextEditingController(text: e?.place ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _visit = TextEditingController(text: e?.visitNotes ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _with.dispose();
    _place.dispose();
    _notes.dispose();
    _visit.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    var picked = _start;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Date and time', style: Theme.of(context).textTheme.titleMedium),
                SizedBox(
                  height: 200,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: AppColors.dark ? Brightness.dark : Brightness.light,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          fontFamily: 'Heros',
                          fontSize: 20,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.dateAndTime,
                      use24hFormat: true,
                      minuteInterval: 5,
                      initialDateTime: DateTime(picked.year, picked.month, picked.day, picked.hour,
                          picked.minute - picked.minute % 5),
                      minimumDate: DateTime(now.year - 2),
                      maximumDate: DateTime(now.year + 3),
                      onDateTimeChanged: (d) => picked = d,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _BottomButton(label: 'Done', onPressed: () => Navigator.pop(context, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) setState(() => _start = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final title = _title.text.trim().isEmpty ? _kind.label : _title.text.trim();
    setState(() => _saving = true);
    try {
      await widget.store.saveAppointment(Appointment(
        id: widget.existing?.id ?? widget.store.newId(),
        kind: _kind,
        title: title,
        start: _start,
        withWhom: _with.text.trim(),
        place: _place.text.trim(),
        notes: _notes.text.trim(),
        visitNotes: _visit.text.trim(),
      ));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save on this device. Try again.";
        });
      }
      return;
    }
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this appointment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pop();
    await widget.store.deleteAppointment(widget.existing!.id);
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? hint,
    int maxLines = 1,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: TextField(
        controller: c,
        autofocus: autofocus,
        minLines: maxLines > 1 ? 2 : 1,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label.isEmpty ? null : label, hintText: hint),
        onChanged: c == _title ? (_) => _titleEdited = true : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final past = _start.isBefore(DateTime.now());
    final visitNotes = Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Icon(Icons.sticky_note_2_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Visit notes', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              past
                  ? 'What the doctor said, advice and next steps.'
                  : 'Fill in after the visit: what the doctor said, advice and next steps.',
              style: TextStyle(fontSize: AppText.label, color: AppColors.muted),
            ),
          ),
          _field('', _visit,
              hint: 'e.g. Weight on track. Next vaccines at 12 weeks.',
              maxLines: 8,
              autofocus: widget.writeVisitNotes),
        ],
      ),
    );
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: AppColors.surface,
          child: Column(
            children: [
              Container(
                color: AppColors.selected,
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded, color: AppColors.onSelected),
                    ),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit appointment' : 'New appointment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.onSelected,
                          fontSize: AppText.headline,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: AppColors.tag,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(_error!, style: TextStyle(color: AppColors.ink)),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final k in AppointmentKind.values)
                              ChoiceChip(
                                avatar: Icon(iconForAppointment(k), size: 18),
                                label: Text(k.label),
                                selected: _kind == k,
                                showCheckmark: false,
                                selectedColor: AppColors.selected,
                                onSelected: (_) => setState(() {
                                  _kind = k;
                                  // Follow the kind until a title has been typed.
                                  if (!_titleEdited) _title.text = k.label;
                                }),
                              ),
                          ],
                        ),
                      ),
                      _field('What', _title, hint: 'e.g. 2-month check-up'),
                      InkWell(
                        onTap: _pickWhen,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Row(
                            children: [
                              Text('When', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  DateFormat('EEE d MMM yyyy · HH:mm').format(_start),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
                            ],
                          ),
                        ),
                      ),
                      _field('With', _with, hint: 'e.g. Dr Patel, health visitor'),
                      _field('Where', _place, hint: 'e.g. Riverside clinic'),
                      // After the visit, its notes come first; before, they wait at the end.
                      if (past) visitNotes,
                      _field('To ask or bring', _notes,
                          hint: 'Questions to ask, what to bring', maxLines: 3),
                      if (!past) visitNotes,
                      if (_isEditing)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: _delete,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Delete appointment'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                padding:
                    EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                child: _BottomButton(
                  label: _isEditing ? 'Save changes' : 'Save',
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}

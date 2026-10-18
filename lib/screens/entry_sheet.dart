import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/entry_store.dart';
import '../models/entry.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/presets.dart';

/// Opens the drawer that asks what to log, then that kind's form.
Future<void> showAddMenu(BuildContext context, EntryStore store) async {
  final choice = await showModalBottomSheet<EntryType>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GrabHandle(),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'What do you want to log?',
                style: TextStyle(
                    fontSize: AppText.title, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            _MenuOption(type: EntryType.breast, title: 'Breastfeeding', subtitle: 'Time each side'),
            _MenuOption(
                type: EntryType.bottle,
                title: 'Bottle feeding',
                subtitle: 'Formula or breast milk'),
            _MenuOption(type: EntryType.pump, title: 'Pumping', subtitle: 'Time and amount pumped'),
            _MenuOption(type: EntryType.diaper, title: 'Diaper', subtitle: 'Wet, dirty or dry'),
            _MenuOption(
                type: EntryType.routine, title: 'Routine', subtitle: 'Bath, tummy time, walks…'),
            _MenuOption(
              type: EntryType.other,
              title: 'Other',
              subtitle: 'Weight, temperature, medicine, vaccines, firsts…',
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  // A bottle starts on whatever was in the last bottle.
  final type = choice == EntryType.bottle
      ? store.lastWhere((e) => e.isBottle)?.type ?? EntryType.bottle
      : choice;
  await showEntrySheet(context, store, type: type);
}

/// Opens the form for one entry in a tall drawer: a new entry of [type],
/// [existing] to edit, or a new entry pre-filled from [draft] (a finished
/// timer). [onDeleted] runs after the user deletes [existing]. Completes with
/// true when the entry was saved.
Future<bool> showEntrySheet(
  BuildContext context,
  EntryStore store, {
  EntryType? type,
  Entry? existing,
  Entry? draft,
  ValueChanged<Entry>? onDeleted,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Closing goes through the ✕ button, which asks before discarding.
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => EntrySheet(
      store: store,
      type: type ?? (existing ?? draft)!.type,
      existing: existing,
      draft: draft,
      onDeleted: onDeleted,
    ),
  );
  return saved ?? false;
}

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    required this.store,
    required this.type,
    this.existing,
    this.draft,
    this.onDeleted,
  });

  final EntryStore store;
  final EntryType type;
  final Entry? existing;

  /// Values to start a new entry from, e.g. a finished timer.
  final Entry? draft;
  final ValueChanged<Entry>? onDeleted;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  late EntryType _type;
  late DateTime _start;
  bool _startEdited = false;
  late final TextEditingController _notes;
  String? _error;
  Timer? _ticker;

  // Breastfeeding: a timer per side.
  Duration _left = Duration.zero;
  Duration _right = Duration.zero;
  BreastSide? _activeSide;
  DateTime? _activeSince;
  BreastSide? _endSide;

  // Bottle.
  int _amountMl = 0;

  // One timer for pumping, routines and Other (which may also have no
  // duration at all); pumping also has an amount per side or in total.
  Duration _timerTime = Duration.zero;
  DateTime? _timerSince;
  bool _saving = false;
  bool _pumpPerSide = false;
  int _leftMl = 0;
  int _rightMl = 0;

  // Diaper.
  bool _wet = false;
  bool _dirty = false;
  bool _dry = false;
  bool _rash = false;

  // Routine and Other.
  String _title = '';
  bool _customTitle = false;
  late final TextEditingController _titleText;
  late final TextEditingController _valueText;
  late final TextEditingController _unitText;

  bool get _isEditing => widget.existing != null;
  bool get _isBreast => _type == EntryType.breast;
  OtherPreset? get _preset => otherPresetFor(_title);

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? widget.draft;
    final now = DateTime.now();
    _type = widget.type;
    _start = e?.start ?? DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _startEdited = e != null;
    _notes = TextEditingController(text: e?.notes ?? '');
    _titleText = TextEditingController();
    _valueText = TextEditingController(text: e?.value ?? '');
    _unitText = TextEditingController(text: e?.unit ?? '');
    if (e == null) return;
    switch (e.type) {
      case EntryType.breast:
        _left = e.leftDuration;
        _right = e.rightDuration;
        _endSide = e.endSide;
        // Older entries may have only a start and end time: keep that length.
        if (_left + _right == Duration.zero) {
          if (e.endSide == BreastSide.right) {
            _right = e.breastDuration;
          } else {
            _left = e.breastDuration;
          }
        }
      case EntryType.bottle || EntryType.breastMilk:
        _amountMl = e.amountMl;
      case EntryType.pump:
        _timerTime = e.duration;
        _pumpPerSide = e.leftMl + e.rightMl > 0;
        _leftMl = e.leftMl;
        _rightMl = e.rightMl;
        _amountMl = e.amountMl;
      case EntryType.diaper:
        _wet = e.diaper?.isWet ?? false;
        _dirty = e.diaper?.isDirty ?? false;
        _dry = e.diaper == DiaperKind.dry;
        _rash = e.rash;
      case EntryType.routine:
        _timerTime = e.duration;
        _title = e.title;
        _customTitle = !routinePresets.any((p) => p.$1 == e.title);
        _titleText.text = _customTitle ? e.title : '';
      case EntryType.other:
        _timerTime = e.duration;
        _title = e.title;
        _customTitle = otherPresetFor(e.title) == null;
        _titleText.text = _customTitle ? e.title : '';
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notes.dispose();
    _titleText.dispose();
    _valueText.dispose();
    _unitText.dispose();
    super.dispose();
  }

  void _tick(bool running) {
    if (running && _ticker?.isActive != true) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else if (!running) {
      _ticker?.cancel();
    }
  }

  // ---- Breastfeeding timers ------------------------------------------------

  Duration _elapsed(BreastSide side) {
    var d = side == BreastSide.left ? _left : _right;
    if (_activeSide == side && _activeSince != null) {
      d += DateTime.now().difference(_activeSince!);
    }
    return d;
  }

  Duration get _breastTotal => _elapsed(BreastSide.left) + _elapsed(BreastSide.right);

  void _commitSide() {
    final side = _activeSide, since = _activeSince;
    if (side == null || since == null) return;
    final now = DateTime.now();
    if (side == BreastSide.left) {
      _left += now.difference(since);
    } else {
      _right += now.difference(since);
    }
    _activeSince = now;
  }

  void _toggleSide(BreastSide side) {
    setState(() {
      _error = null;
      if (_activeSide == null && _breastTotal == Duration.zero && !_startEdited) {
        _start = DateTime.now();
      }
      _commitSide();
      if (_activeSide == side) {
        _activeSide = null;
        _activeSince = null;
      } else {
        _activeSide = side;
        _activeSince = DateTime.now();
        _endSide = side;
      }
      _tick(_activeSide != null);
    });
  }

  /// Sets the whole feed's length at once, credited to the side it ended on
  /// (left when none is chosen yet).
  Future<void> _editTotal() async {
    if (_activeSide != null) _toggleSide(_activeSide!); // pause before editing
    final picked = await _pickDuration('Total time', _breastTotal);
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      _endNowIfUntouched(picked);
      final side = _endSide ?? BreastSide.left;
      _endSide = side;
      _left = side == BreastSide.left ? picked : Duration.zero;
      _right = side == BreastSide.right ? picked : Duration.zero;
    });
  }

  Future<void> _editSide(BreastSide side) async {
    if (_activeSide == side) _toggleSide(side); // pause before editing
    final name = side == BreastSide.left ? 'Left' : 'Right';
    final picked = await _pickDuration('$name side time', _elapsed(side));
    if (picked == null) return;
    setState(() {
      _error = null;
      if (side == BreastSide.left) {
        _left = picked;
      } else {
        _right = picked;
      }
      // Typing only one side's time also tells us which side it was.
      final other = side == BreastSide.left ? BreastSide.right : BreastSide.left;
      if (picked > Duration.zero && _elapsed(other) == Duration.zero) _endSide = side;
    });
  }

  // ---- Single timer (pumping, routines, Other) ------------------------------

  Duration get _timerElapsed =>
      _timerTime + (_timerSince == null ? Duration.zero : DateTime.now().difference(_timerSince!));

  void _toggleTimer() {
    setState(() {
      _error = null;
      if (_timerSince == null) {
        if (_timerTime == Duration.zero && !_startEdited) _start = DateTime.now();
        _timerSince = DateTime.now();
      } else {
        _timerTime = _timerElapsed;
        _timerSince = null;
      }
      _tick(_timerSince != null);
    });
  }

  /// Sets the length by hand, from the timer's pencil or the Total time row.
  Future<void> _editTimer() async {
    if (_timerSince != null) _toggleTimer();
    final picked = await _pickDuration('Total time', _timerTime);
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      _endNowIfUntouched(picked);
      _timerTime = picked;
    });
  }

  /// A length typed in for a new entry, with no start time chosen, is for
  /// something that just ended: start it that long ago.
  void _endNowIfUntouched(Duration length) {
    if (!_startEdited) _start = DateTime.now().subtract(length);
  }

  /// Sets the duration from an end time picked for routines and Other.
  Future<void> _pickEnd() async {
    if (_timerSince != null) _toggleTimer();
    final end = await _pickDateTime(
      'End time',
      _timerTime > Duration.zero ? _start.add(_timerTime) : DateTime.now(),
      notBefore: _start,
    );
    if (end == null || !mounted) return;
    setState(() => _timerTime = end.isAfter(_start) ? end.difference(_start) : Duration.zero);
  }

  int get _pumpTotalMl => _pumpPerSide ? _leftMl + _rightMl : _amountMl;

  // ---- Pickers -------------------------------------------------------------

  /// A duration in hours and minutes, with quick picks for common lengths.
  Future<Duration?> _pickDuration(String title, Duration initial) {
    var picked = Duration(minutes: initial.inMinutes);
    return showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _GrabHandle(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final m in const [5, 10, 15, 20, 30, 45, 60])
                        _Pill(
                          label: m < 60 ? '$m min' : '1 h',
                          selected: picked == Duration(minutes: m),
                          onTap: () => setSheet(() => picked = Duration(minutes: m)),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 180,
                    child: CupertinoTimerPicker(
                      key: ValueKey(picked),
                      mode: CupertinoTimerPickerMode.hm,
                      initialTimerDuration: picked,
                      onTimerDurationChanged: (d) => picked = d,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context, picked)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Day and time together in one wheel (the day rarely changes), with a
  /// shortcut back to now.
  Future<DateTime?> _pickDateTime(String title, DateTime initial, {DateTime? notBefore}) {
    final now = DateTime.now();
    final latest = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final earliest = notBefore ?? latest.subtract(const Duration(days: 365 * 3));
    var picked = initial.isAfter(latest)
        ? latest
        : initial.isBefore(earliest)
            ? earliest
            : DateTime(initial.year, initial.month, initial.day, initial.hour, initial.minute);
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _GrabHandle(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        TextButton(
                          onPressed: () => setSheet(() => picked = latest),
                          child: const Text('Now'),
                        ),
                      ],
                    ),
                  ),
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
                        key: ValueKey(picked == latest),
                        mode: CupertinoDatePickerMode.dateAndTime,
                        use24hFormat: true,
                        initialDateTime: picked,
                        minimumDate: earliest,
                        maximumDate: latest,
                        onDateTimeChanged: (d) => picked = d,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context, picked)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime('Start time', _start);
    if (picked == null || !mounted) return;
    setState(() {
      _start = picked;
      _startEdited = true;
    });
  }

  String _dayAndTime(DateTime t) {
    final today = dateOnly(DateTime.now());
    final day = dateOnly(t);
    final hm = DateFormat.Hm().format(t);
    if (day == today) return 'Today $hm';
    if (day == DateTime(today.year, today.month, today.day - 1)) return 'Yesterday $hm';
    return '${DateFormat('d MMM').format(t)} $hm';
  }

  /// The amount of the last bottle with the same contents, for the shortcut.
  int? get _lastBottleAmount {
    if (_isEditing) return null;
    final last =
        widget.store.lastWhere((e) => e.type == _type) ?? widget.store.lastWhere((e) => e.isBottle);
    return last?.amountMl;
  }

  // ---- Close, save, delete -------------------------------------------------

  bool get _hasInput =>
      _notes.text.isNotEmpty ||
      switch (_type) {
        EntryType.breast => _breastTotal > Duration.zero,
        EntryType.bottle || EntryType.breastMilk => _amountMl > 0,
        EntryType.pump => _timerElapsed > Duration.zero || _pumpTotalMl > 0,
        EntryType.diaper => _wet || _dirty || _dry,
        EntryType.routine || EntryType.other => _title.isNotEmpty ||
            _titleText.text.isNotEmpty ||
            _valueText.text.isNotEmpty ||
            _timerElapsed > Duration.zero,
      };

  Future<void> _close() async {
    // A draft comes from a timer that stays on Today, so nothing is lost.
    if (_isEditing || widget.draft != null || !_hasInput) {
      Navigator.of(context).pop(false);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this entry?'),
        content: const Text("It hasn't been saved."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  /// What is missing before this entry can be saved, or null.
  String? _validate() {
    switch (_type) {
      case EntryType.breast:
        if (_breastTotal == Duration.zero) return 'Start a timer or enter the time for a side.';
        if (_endSide == null) return 'Choose the side you ended on.';
      case EntryType.bottle || EntryType.breastMilk:
        if (_amountMl <= 0) return 'Add the amount.';
      case EntryType.pump:
        if (_pumpTotalMl <= 0 && _timerElapsed == Duration.zero) {
          return 'Add the amount pumped or start the timer.';
        }
      case EntryType.diaper:
        if (!_wet && !_dirty && !_dry) return 'Choose wet, dirty or dry.';
      case EntryType.routine:
        if (_finalTitle.isEmpty) return 'Choose a routine or type one.';
      case EntryType.other:
        if (_finalTitle.isEmpty) return 'Choose what you are logging or type it.';
        final preset = _preset;
        if (preset != null && preset.numeric) {
          final v = double.tryParse(_valueText.text.trim().replaceAll(',', '.'));
          if (v == null) return 'Enter the ${preset.valueLabel.toLowerCase()} as a number.';
        }
    }
    return null;
  }

  String get _finalTitle => _customTitle ? _titleText.text.trim() : _title;

  Future<void> _save() async {
    // One save at a time: a second tap while saving must not close the page
    // behind the drawer.
    if (_saving) return;
    // Close the keyboard first, so the page isn't left scrolled under it.
    FocusManager.instance.primaryFocus?.unfocus();
    if (_activeSide != null) {
      _commitSide();
      _activeSide = null;
      _activeSince = null;
    }
    if (_timerSince != null) {
      _timerTime = _timerElapsed;
      _timerSince = null;
    }
    _ticker?.cancel();

    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final preset = _preset;
    final entry = Entry(
      id: widget.existing?.id ?? widget.store.newId(),
      type: _type,
      start: _start,
      end: switch (_type) {
        EntryType.breast => _start.add(_breastTotal),
        EntryType.pump || EntryType.routine || EntryType.other => _start.add(_timerTime),
        _ => _start,
      },
      leftDuration: _isBreast ? _left : Duration.zero,
      rightDuration: _isBreast ? _right : Duration.zero,
      endSide: _isBreast ? _endSide : null,
      amountMl: switch (_type) {
        EntryType.bottle || EntryType.breastMilk => _amountMl,
        EntryType.pump => _pumpTotalMl,
        _ => 0,
      },
      leftMl: _type == EntryType.pump && _pumpPerSide ? _leftMl : 0,
      rightMl: _type == EntryType.pump && _pumpPerSide ? _rightMl : 0,
      diaper: _type == EntryType.diaper
          ? (_dry
              ? DiaperKind.dry
              : _wet && _dirty
                  ? DiaperKind.both
                  : _wet
                      ? DiaperKind.wet
                      : DiaperKind.dirty)
          : null,
      rash: _type == EntryType.diaper && _rash,
      title: _type == EntryType.routine || _type == EntryType.other ? _finalTitle : '',
      value: _type == EntryType.other ? _valueText.text.trim().replaceAll(',', '.') : '',
      unit: _type == EntryType.other ? (preset?.unit ?? _unitText.text.trim()) : '',
      notes: _notes.text.trim(),
    );
    setState(() => _saving = true);
    try {
      await widget.store.upsert(entry);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save on this device. Try again.";
        });
      }
      return;
    }
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    Navigator.of(context).pop();
    await widget.store.delete(existing.id);
    widget.onDeleted?.call(existing);
  }

  // ---- UI ------------------------------------------------------------------

  String get _sheetTitle => switch (_type) {
        EntryType.breast => 'Breastfeeding',
        EntryType.bottle || EntryType.breastMilk => 'Bottle feeding',
        EntryType.pump => 'Pumping',
        EntryType.diaper => 'Diaper',
        EntryType.routine => 'Routine',
        EntryType.other => 'Other',
      };

  @override
  Widget build(BuildContext context) {
    // Bottle drawers keep the sand header whichever contents are chosen.
    final headerType = _type.isBottle ? EntryType.bottle : _type;
    final headerColor = AppColors.headerForType(headerType);
    final onHeader = AppColors.onHeaderForType(headerType);

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: AppColors.surface,
          child: Column(
            children: [
              Container(
                color: headerColor,
                padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _close,
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded, color: onHeader),
                    ),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit ${_sheetTitle.toLowerCase()}' : _sheetTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: onHeader,
                            fontSize: AppText.headline,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    // Balances the close button so the title stays centred.
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: AppColors.tag,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.ink, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...switch (_type) {
                        EntryType.breast => _breastFields(),
                        EntryType.bottle || EntryType.breastMilk => _bottleFields(),
                        EntryType.pump => _pumpFields(),
                        EntryType.diaper => _diaperFields(),
                        EntryType.routine => _routineFields(),
                        EntryType.other => _otherFields(),
                      },
                      _NotesRow(controller: _notes, onChanged: () => setState(() {})),
                      if (_isEditing)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: _delete,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Delete entry'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Save sits at the end of the form, within thumb reach.
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                padding:
                    EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                child: _PrimaryButton(
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

  /// Total time on its own: tap to type it, no timer or end time needed.
  Widget _totalRow(Duration total, VoidCallback onTap) => _FormRow(
        label: 'Total time',
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RowValue(
              total == Duration.zero ? 'Add' : formatDuration(total),
              muted: total == Duration.zero,
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      );

  Widget _timeRow([String label = 'Time']) => _FormRow(
        label: label,
        onTap: _pickStart,
        trailing: _RowValue(_dayAndTime(_start)),
      );

  List<Widget> _breastFields() {
    // The side the previous feed ended on, so parents can alternate.
    final lastSide =
        _isEditing ? null : widget.store.lastWhere((e) => e.type == EntryType.breast)?.endSide;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Row(
          children: [
            for (final side in BreastSide.values)
              Expanded(
                child: _TimerBlock(
                  name: side == BreastSide.left ? 'Left' : 'Right',
                  elapsed: _elapsed(side),
                  running: _activeSide == side,
                  tag: lastSide == side ? 'Last side' : null,
                  onToggle: () => _toggleSide(side),
                  onEdit: () => _editSide(side),
                ),
              ),
          ],
        ),
      ),
      _FormRow(
        label: 'Ended on',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final side in BreastSide.values) ...[
              if (side == BreastSide.right) const SizedBox(width: 8),
              _Pill(
                label: side == BreastSide.left ? 'Left' : 'Right',
                selected: _endSide == side,
                onTap: () => setState(() {
                  _error = null;
                  _endSide = side;
                }),
              ),
            ],
          ],
        ),
      ),
      // Tap to type the whole feed's length instead of timing each side.
      _totalRow(_breastTotal, _editTotal),
      _timeRow('Start time'),
    ];
  }

  List<Widget> _bottleFields() {
    final last = _lastBottleAmount;
    return [
      _CircleChoices(
        children: [
          for (final content in const [EntryType.breastMilk, EntryType.bottle])
            _ChoiceCircle(
              label: content == EntryType.bottle ? 'Formula' : 'Breast\nmilk',
              selected: _type == content,
              color: AppColors.forType(content),
              onTap: () => setState(() => _type = content),
            ),
        ],
      ),
      _timeRow('Start time'),
      _FormRow(
        label: 'Amount',
        trailing: _MlStepper(
          value: _amountMl,
          step: 10,
          onChanged: (v) => setState(() {
            _error = null;
            _amountMl = v;
          }),
        ),
      ),
      if (last != null && last > 0 && last != _amountMl)
        Container(
          color: AppColors.field,
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Use last amount: $last ml?',
                  style: TextStyle(fontSize: AppText.body, color: AppColors.ink),
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _error = null;
                  _amountMl = last;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: BorderSide(color: AppColors.ink),
                ),
                child: const Text('Yes'),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _pumpFields() {
    Widget ml(String label, int value, ValueChanged<int> set) => _FormRow(
          label: label,
          trailing: _MlStepper(
            value: value,
            step: 5,
            onChanged: (v) => setState(() {
              _error = null;
              set(v);
            }),
          ),
        );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: _TimerBlock(
          name: 'timer',
          elapsed: _timerElapsed,
          running: _timerSince != null,
          onToggle: _toggleTimer,
          onEdit: _editTimer,
        ),
      ),
      _totalRow(_timerElapsed, _editTimer),
      _timeRow('Start time'),
      _FormRow(
        label: 'Amount',
        trailing: SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: true, label: Text('Per side')),
            ButtonSegment(value: false, label: Text('Total')),
          ],
          selected: {_pumpPerSide},
          onSelectionChanged: (v) => setState(() => _pumpPerSide = v.first),
        ),
      ),
      if (_pumpPerSide) ...[
        ml('Left side', _leftMl, (v) => _leftMl = v),
        ml('Right side', _rightMl, (v) => _rightMl = v),
        Container(
          color: AppColors.field,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            'Total ${_leftMl + _rightMl} ml',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
      ] else
        ml('Total amount', _amountMl, (v) => _amountMl = v),
    ];
  }

  List<Widget> _diaperFields() {
    return [
      _timeRow(),
      _CircleChoices(
        children: [
          _ChoiceCircle(
            label: 'Wet',
            selected: _wet,
            color: AppColors.selected,
            onTap: () => setState(() {
              _error = null;
              _wet = !_wet;
              _dry = false;
            }),
          ),
          _ChoiceCircle(
            label: 'Dirty',
            selected: _dirty,
            color: AppColors.selected,
            onTap: () => setState(() {
              _error = null;
              _dirty = !_dirty;
              _dry = false;
            }),
          ),
          _ChoiceCircle(
            label: 'Dry',
            selected: _dry,
            color: AppColors.selected,
            onTap: () => setState(() {
              _error = null;
              _dry = !_dry;
              if (_dry) _wet = _dirty = false;
            }),
          ),
        ],
      ),
      _FormRow(
        label: 'Diaper rash',
        trailing: Switch(value: _rash, onChanged: (v) => setState(() => _rash = v)),
      ),
    ];
  }

  /// For routines and Other: an optional timer, or the total time typed in,
  /// and the end time it implies.
  List<Widget> _durationFields() {
    final duration = _timerElapsed;
    return [
      Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: _TimerBlock(
          name: 'timer',
          elapsed: duration,
          running: _timerSince != null,
          onToggle: _toggleTimer,
          onEdit: _editTimer,
        ),
      ),
      _totalRow(duration, _editTimer),
      _timeRow('Start time'),
      _FormRow(
        label: 'End time',
        onTap: _pickEnd,
        trailing: duration == Duration.zero
            ? const _RowValue('Add', muted: true)
            : _RowValue(_dayAndTime(_start.add(duration))),
      ),
    ];
  }

  List<Widget> _routineFields() {
    return [
      _ChoiceGrid(
        label: 'Routine',
        children: [
          for (final (name, icon) in routinePresets)
            _Pill(
              label: name,
              icon: icon,
              selected: !_customTitle && _title == name,
              onTap: () => setState(() {
                _error = null;
                _customTitle = false;
                _title = name;
              }),
            ),
          _Pill(
            label: 'Something else',
            icon: Icons.add_rounded,
            selected: _customTitle,
            onTap: () => setState(() {
              _error = null;
              _customTitle = true;
              _title = '';
            }),
          ),
        ],
      ),
      if (_customTitle)
        _TextRow(
          label: 'Name',
          controller: _titleText,
          hint: 'e.g. Massage',
          autofocus: !_isEditing,
          onChanged: () => setState(() => _error = null),
        ),
      ..._durationFields(),
    ];
  }

  List<Widget> _otherFields() {
    final preset = _preset;
    final chosen = preset != null || _customTitle;
    return [
      _ChoiceGrid(
        label: 'What are you logging?',
        children: [
          for (final p in otherPresets)
            _Pill(
              label: p.name,
              icon: p.icon,
              selected: !_customTitle && _title == p.name,
              onTap: () => setState(() {
                _error = null;
                if (_title != p.name) _valueText.clear();
                _customTitle = false;
                _title = p.name;
              }),
            ),
          _Pill(
            label: 'Something else',
            icon: Icons.add_rounded,
            selected: _customTitle,
            onTap: () => setState(() {
              _error = null;
              _customTitle = true;
              _title = '';
            }),
          ),
        ],
      ),
      if (_customTitle)
        _TextRow(
          label: 'What',
          controller: _titleText,
          hint: 'e.g. Doctor visit',
          autofocus: !_isEditing,
          onChanged: () => setState(() => _error = null),
        ),
      if (chosen)
        _TextRow(
          label: preset?.valueLabel ?? 'Value',
          controller: _valueText,
          hint: preset == null ? 'Optional' : (preset.numeric ? '0' : ''),
          suffix: preset?.unit,
          numeric: preset?.numeric ?? false,
          onChanged: () => setState(() => _error = null),
        ),
      if (_customTitle) _TextRow(label: 'Unit', controller: _unitText, hint: 'Optional, e.g. ml'),
      ..._durationFields(),
    ];
  }
}

// ---- Pieces ---------------------------------------------------------------

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 4),
        decoration:
            BoxDecoration(color: AppColors.softBorder, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({required this.type, required this.title, required this.subtitle});

  final EntryType type;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: EntryIcon(type: type, size: EntryIcon.large),
      title: Text(
        title,
        style: TextStyle(
            fontSize: AppText.subtitle, fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.muted)),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
      onTap: () => Navigator.pop(context, type),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.trailing, this.onTap});

  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _RowValue extends StatelessWidget {
  const _RowValue(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: AppText.subtitle,
        fontWeight: FontWeight.w600,
        color: muted ? AppColors.muted : AppColors.ink,
      ),
    );
  }
}

/// A labelled text field laid out like the other rows.
class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.label,
    required this.controller,
    this.hint = '',
    this.suffix,
    this.numeric = false,
    this.autofocus = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? suffix;
  final bool numeric;
  final bool autofocus;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: (_) => onChanged?.call(),
              textAlign: TextAlign.right,
              keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                  fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          if (suffix != null && suffix!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(suffix!, style: TextStyle(fontSize: AppText.subtitle, color: AppColors.ink)),
          ],
        ],
      ),
    );
  }
}

class _NotesRow extends StatelessWidget {
  const _NotesRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider),
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: AppText.subtitle, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Notes',
          hintStyle: TextStyle(
              fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: AppColors.muted),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

/// A timer readout with a pencil to type the time, and Start / Pause / Resume.
class _TimerBlock extends StatelessWidget {
  const _TimerBlock({
    required this.name,
    required this.elapsed,
    required this.running,
    required this.onToggle,
    required this.onEdit,
    this.tag,
  });

  /// "Left", "Right" or "timer"; used in the button and tooltip.
  final String name;
  final Duration elapsed;
  final bool running;
  final String? tag;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final lower = name.toLowerCase();
    final action = running
        ? 'Pause'
        : elapsed > Duration.zero
            ? 'Resume $lower'
            : 'Start $lower';
    return Column(
      children: [
        SizedBox(
          height: 28,
          child: tag == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration:
                      BoxDecoration(color: AppColors.tag, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    tag!,
                    style: TextStyle(
                        fontSize: AppText.label, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatClock(elapsed),
                style: TextStyle(
                  fontSize: AppText.timer,
                  fontWeight: FontWeight.w300,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: name == 'timer' ? 'Enter the time' : 'Enter $name time',
                icon: Icon(Icons.edit_rounded, color: AppColors.ink, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        running
            ? FilledButton.icon(
                onPressed: onToggle,
                icon: const Icon(Icons.pause_rounded),
                label: Text(action),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  shape: const StadiumBorder(),
                  // Running is a state, not the drawer's main action (Save).
                  backgroundColor: AppColors.selected,
                  foregroundColor: AppColors.onSelected,
                ),
              )
            : OutlinedButton(
                onPressed: onToggle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                  foregroundColor: AppColors.ink,
                  side: BorderSide(color: AppColors.ink, width: 1.5),
                  textStyle: const TextStyle(
                      fontFamily: 'Heros', fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
                ),
                child: Text(action),
              ),
      ],
    );
  }
}

class _CircleChoices extends StatelessWidget {
  const _CircleChoices({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 16,
        children: children,
      ),
    );
  }
}

class _ChoiceCircle extends StatelessWidget {
  const _ChoiceCircle({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color : AppColors.surface,
            border: Border.all(color: AppColors.ink, width: selected ? 2.5 : 1.25),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppText.subtitle,
              height: 1.15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading over a wrap of choice pills.
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: AppText.subtitle, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onSelected : AppColors.ink;
    return Material(
      color: selected ? AppColors.selected : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.selected : AppColors.ink, width: 1.25),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(icon == null ? 18 : 12, 8, 18, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// − value + for an amount in ml. The value is a box you can type into.
class _MlStepper extends StatefulWidget {
  const _MlStepper({required this.value, required this.step, required this.onChanged});

  final int value;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  State<_MlStepper> createState() => _MlStepperState();
}

class _MlStepperState extends State<_MlStepper> {
  late final TextEditingController _text =
      TextEditingController(text: widget.value == 0 ? '' : '${widget.value}');

  @override
  void didUpdateWidget(_MlStepper old) {
    super.didUpdateWidget(old);
    // Keep the box in step with − / + and "use last amount", without fighting
    // what is being typed.
    if ((int.tryParse(_text.text) ?? 0) != widget.value) {
      _text.text = widget.value == 0 ? '' : '${widget.value}';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _set(int v) => widget.onChanged(v.clamp(0, 500));

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          tooltip: 'Less',
          onTap: value > 0 ? () => _set(value - widget.step) : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: TextField(
            controller: _text,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (v) => _set(int.tryParse(v) ?? 0),
            style: TextStyle(
              fontSize: AppText.subtitle,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              // Always shown, not only while typing.
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  'ml',
                  style: TextStyle(fontSize: AppText.body, color: AppColors.muted),
                ),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              filled: true,
              fillColor: AppColors.field,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StepButton(
          icon: Icons.add_rounded,
          tooltip: 'More',
          onTap: () => _set(value + widget.step),
        ),
      ],
    );
  }
}

/// The drawer's full-width main button.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.field,
        foregroundColor: AppColors.ink,
        disabledForegroundColor: AppColors.muted,
      ),
    );
  }
}

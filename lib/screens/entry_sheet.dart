import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
          children: const [
            _GrabHandle(),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'What do you want to log?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
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

/// Opens the form for one entry in a tall drawer: a new entry of [type], or
/// [existing] to edit. [onDeleted] runs after the user deletes [existing].
Future<void> showEntrySheet(
  BuildContext context,
  EntryStore store, {
  EntryType? type,
  Entry? existing,
  ValueChanged<Entry>? onDeleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Closing goes through the ✕ button, which asks before discarding.
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => EntrySheet(
      store: store,
      type: type ?? existing!.type,
      existing: existing,
      onDeleted: onDeleted,
    ),
  );
}

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    required this.store,
    required this.type,
    this.existing,
    this.onDeleted,
  });

  final EntryStore store;
  final EntryType type;
  final Entry? existing;
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

  // Pumping: one timer, amount per side or in total.
  Duration _pumpTime = Duration.zero;
  DateTime? _pumpSince;
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
    final e = widget.existing;
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
        _pumpTime = e.duration;
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
        _title = e.title;
        _customTitle = !routinePresets.any((p) => p.$1 == e.title);
        _titleText.text = _customTitle ? e.title : '';
      case EntryType.other:
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

  // ---- Pumping timer -------------------------------------------------------

  Duration get _pumpElapsed =>
      _pumpTime + (_pumpSince == null ? Duration.zero : DateTime.now().difference(_pumpSince!));

  void _togglePump() {
    setState(() {
      _error = null;
      if (_pumpSince == null) {
        if (_pumpTime == Duration.zero && !_startEdited) _start = DateTime.now();
        _pumpSince = DateTime.now();
      } else {
        _pumpTime = _pumpElapsed;
        _pumpSince = null;
      }
      _tick(_pumpSince != null);
    });
  }

  Future<void> _editPumpTime() async {
    if (_pumpSince != null) _togglePump();
    final picked = await _pickDuration('Pumping time', _pumpTime);
    if (picked != null) setState(() => _pumpTime = picked);
  }

  int get _pumpTotalMl => _pumpPerSide ? _leftMl + _rightMl : _amountMl;

  // ---- Pickers -------------------------------------------------------------

  Future<Duration?> _pickDuration(String title, Duration initial) async {
    var picked = initial;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GrabHandle(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            SizedBox(
              height: 200,
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hms,
                initialTimerDuration: initial,
                onTimerDurationChanged: (d) => picked = d,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true ? picked : null;
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

  Future<int?> _typeMl(String title, int current) async {
    final controller = TextEditingController(text: current == 0 ? '' : '$current');
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'ml'),
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        EntryType.pump => _pumpElapsed > Duration.zero || _pumpTotalMl > 0,
        EntryType.diaper => _wet || _dirty || _dry,
        EntryType.routine ||
        EntryType.other =>
          _title.isNotEmpty || _titleText.text.isNotEmpty || _valueText.text.isNotEmpty,
      };

  Future<void> _close() async {
    if (_isEditing || !_hasInput) {
      Navigator.of(context).pop();
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
    if (discard == true && mounted) Navigator.of(context).pop();
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
        if (_pumpTotalMl <= 0 && _pumpElapsed == Duration.zero) {
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
    if (_activeSide != null) {
      _commitSide();
      _activeSide = null;
      _activeSince = null;
    }
    if (_pumpSince != null) {
      _pumpTime = _pumpElapsed;
      _pumpSince = null;
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
        EntryType.pump => _start.add(_pumpTime),
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
    await widget.store.upsert(entry);
    if (mounted) Navigator.of(context).pop();
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
    final headerColor =
        headerType == EntryType.other ? AppColors.field : AppColors.forType(headerType);
    final onHeader = AppColors.onType(headerType);

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: Colors.white,
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
                      icon: Icon(Icons.close, color: onHeader),
                    ),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit ${_sheetTitle.toLowerCase()}' : _sheetTitle,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: onHeader, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      style: TextButton.styleFrom(foregroundColor: onHeader),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: AppColors.sand,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.ink, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
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
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete entry'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      _timeRow('Start time'),
      _FormRow(
        label: 'Total time',
        trailing: _RowValue(
          _breastTotal == Duration.zero ? '0 m' : formatDuration(_breastTotal),
          muted: _breastTotal == Duration.zero,
        ),
      ),
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
          onType: () async {
            final v = await _typeMl('Amount', _amountMl);
            if (v != null) setState(() => _amountMl = v.clamp(0, 500));
          },
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
                  style: const TextStyle(fontSize: 15, color: AppColors.ink),
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _error = null;
                  _amountMl = last;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink),
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
            onType: () async {
              final v = await _typeMl(label, value);
              if (v != null) setState(() => set(v.clamp(0, 500)));
            },
          ),
        );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: _TimerBlock(
          name: 'timer',
          elapsed: _pumpElapsed,
          running: _pumpSince != null,
          onToggle: _togglePump,
          onEdit: _editPumpTime,
        ),
      ),
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
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
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
            color: AppColors.cream,
            onTap: () => setState(() {
              _error = null;
              _wet = !_wet;
              _dry = false;
            }),
          ),
          _ChoiceCircle(
            label: 'Dirty',
            selected: _dirty,
            color: AppColors.cream,
            onTap: () => setState(() {
              _error = null;
              _dirty = !_dirty;
              _dry = false;
            }),
          ),
          _ChoiceCircle(
            label: 'Dry',
            selected: _dry,
            color: AppColors.cream,
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

  List<Widget> _routineFields() {
    return [
      _timeRow(),
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
            icon: Icons.add,
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
    ];
  }

  List<Widget> _otherFields() {
    final preset = _preset;
    final chosen = preset != null || _customTitle;
    return [
      _timeRow(),
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
            icon: Icons.add,
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
      leading: EntryIcon(type: type, size: 44),
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
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
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
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
        fontSize: 17,
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
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
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
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          if (suffix != null && suffix!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(suffix!, style: const TextStyle(fontSize: 17, color: AppColors.ink)),
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
      decoration: const BoxDecoration(
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
        style: const TextStyle(fontSize: 17, color: AppColors.ink),
        decoration: const InputDecoration(
          hintText: 'Notes',
          hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.muted),
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
                      BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    tag!,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
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
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w300,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: name == 'timer' ? 'Enter the time' : 'Enter $name time',
                icon: const Icon(Icons.edit_outlined, color: AppColors.ink, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        running
            ? FilledButton.icon(
                onPressed: onToggle,
                icon: const Icon(Icons.pause),
                label: Text(action),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48), shape: const StadiumBorder()),
              )
            : OutlinedButton(
                onPressed: onToggle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink, width: 1.5),
                  textStyle: const TextStyle(
                      fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700),
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
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
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
            color: selected ? color : Colors.white,
            border: Border.all(color: AppColors.ink, width: selected ? 2.5 : 1.25),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
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
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
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
    final fg = selected ? Colors.white : AppColors.ink;
    return Material(
      color: selected ? AppColors.indigo : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.indigo : AppColors.ink, width: 1.25),
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// − value + for an amount in ml; tapping the value lets you type it.
class _MlStepper extends StatelessWidget {
  const _MlStepper({
    required this.value,
    required this.step,
    required this.onChanged,
    required this.onType,
  });

  final int value;
  final int step;
  final ValueChanged<int> onChanged;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          tooltip: 'Less',
          onTap: value > 0 ? () => onChanged((value - step).clamp(0, 500)) : null,
        ),
        InkWell(
          onTap: onType,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            alignment: Alignment.center,
            child: Text(
              '$value ml',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
        ),
        _StepButton(
            icon: Icons.add, tooltip: 'More', onTap: () => onChanged((value + step).clamp(0, 500))),
      ],
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

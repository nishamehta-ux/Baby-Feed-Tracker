import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/feeding_store.dart';
import '../models/feeding.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens the drawer that asks what kind of feeding to add, then the form.
Future<void> showAddFeedingMenu(BuildContext context, FeedingStore store) async {
  final choice = await showModalBottomSheet<FeedingType>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GrabHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Add a feeding',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            _MenuOption(
              type: FeedingType.breast,
              title: 'Breastfeeding',
              subtitle: 'Time each side',
            ),
            _MenuOption(
              type: FeedingType.bottle,
              title: 'Bottle feeding',
              subtitle: 'Formula or breast milk',
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  // Bottle starts on whatever was in the last bottle.
  final type = choice == FeedingType.breast
      ? FeedingType.breast
      : store.lastWhere((f) => f.isBottle)?.type ?? FeedingType.bottle;
  await showFeedingSheet(context, store, type: type);
}

/// Opens the feeding form in a tall drawer, to add a feeding of [type] or
/// edit [existing]. [onDeleted] runs after the user deletes [existing].
Future<void> showFeedingSheet(
  BuildContext context,
  FeedingStore store, {
  FeedingType? type,
  Feeding? existing,
  ValueChanged<Feeding>? onDeleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Closing goes through the ✕ button, which asks before discarding.
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => FeedingSheet(
      store: store,
      type: type ?? existing!.type,
      existing: existing,
      onDeleted: onDeleted,
    ),
  );
}

class FeedingSheet extends StatefulWidget {
  const FeedingSheet({
    super.key,
    required this.store,
    required this.type,
    this.existing,
    this.onDeleted,
  });

  final FeedingStore store;
  final FeedingType type;
  final Feeding? existing;
  final ValueChanged<Feeding>? onDeleted;

  @override
  State<FeedingSheet> createState() => _FeedingSheetState();
}

class _FeedingSheetState extends State<FeedingSheet> {
  late FeedingType _type;
  late DateTime _start;
  bool _startEdited = false;
  late final TextEditingController _notes;
  String? _error;

  // Breastfeeding.
  Duration _left = Duration.zero;
  Duration _right = Duration.zero;
  BreastSide? _active;
  DateTime? _activeSince;
  BreastSide? _endSide;
  Timer? _ticker;

  // Bottle.
  int _amountMl = 0;

  bool get _isEditing => widget.existing != null;
  bool get _isBreast => _type == FeedingType.breast;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _type = widget.type;
    _start = e?.start ?? DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _startEdited = e != null;
    _notes = TextEditingController(text: e?.notes ?? '');
    if (e != null && e.type == FeedingType.breast) {
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
    }
    if (e != null && e.isBottle) _amountMl = e.amountMl;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notes.dispose();
    super.dispose();
  }

  // ---- Breastfeeding timers ------------------------------------------------

  Duration _elapsed(BreastSide side) {
    var d = side == BreastSide.left ? _left : _right;
    if (_active == side && _activeSince != null) {
      d += DateTime.now().difference(_activeSince!);
    }
    return d;
  }

  Duration get _breastTotal => _elapsed(BreastSide.left) + _elapsed(BreastSide.right);

  void _commitActive() {
    final side = _active, since = _activeSince;
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
      final first = _active == null && _breastTotal == Duration.zero;
      if (first && !_startEdited) _start = DateTime.now();
      _commitActive();
      if (_active == side) {
        _active = null;
        _activeSince = null;
        _ticker?.cancel();
      } else {
        _active = side;
        _activeSince = DateTime.now();
        _endSide = side;
        if (_ticker?.isActive != true) {
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
        }
      }
    });
  }

  Future<void> _editSide(BreastSide side) async {
    if (_active == side) _toggleSide(side); // pause before editing
    var picked = _elapsed(side);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GrabHandle(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${side == BreastSide.left ? 'Left' : 'Right'} side time',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.ms,
                initialTimerDuration: picked,
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
    if (ok != true) return;
    setState(() {
      _error = null;
      if (side == BreastSide.left) {
        _left = picked;
      } else {
        _right = picked;
      }
      // Typing a single side's time also tells us which side it was.
      if (picked > Duration.zero &&
          _elapsed(side == BreastSide.left ? BreastSide.right : BreastSide.left) == Duration.zero) {
        _endSide = side;
      }
    });
  }

  // ---- Start time ----------------------------------------------------------

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

  // ---- Bottle amount -------------------------------------------------------

  /// The amount of the last bottle with the same contents, for the shortcut.
  int? get _lastAmount {
    if (_isEditing) return null;
    final last =
        widget.store.lastWhere((f) => f.type == _type) ?? widget.store.lastWhere((f) => f.isBottle);
    return last?.amountMl;
  }

  void _setAmount(int v) => setState(() {
        _error = null;
        _amountMl = v.clamp(0, 500);
      });

  Future<void> _typeAmount() async {
    final controller = TextEditingController(text: _amountMl == 0 ? '' : '$_amountMl');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount'),
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
    if (value != null) _setAmount(value);
  }

  // ---- Close, save, delete -------------------------------------------------

  bool get _hasInput => _isBreast
      ? _breastTotal > Duration.zero || _notes.text.isNotEmpty
      : _amountMl > 0 || _notes.text.isNotEmpty;

  Future<void> _close() async {
    if (_isEditing || !_hasInput) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this feeding?'),
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

  Future<void> _save() async {
    if (_active != null) {
      _commitActive();
      _ticker?.cancel();
      _active = null;
      _activeSince = null;
    }
    final String? error;
    if (_isBreast) {
      if (_breastTotal == Duration.zero) {
        error = 'Start a timer or enter the time for a side.';
      } else if (_endSide == null) {
        error = 'Choose the side you ended on.';
      } else {
        error = null;
      }
    } else {
      error = _amountMl <= 0 ? 'Add the amount.' : null;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final feeding = Feeding(
      id: widget.existing?.id ?? widget.store.newId(),
      type: _type,
      start: _start,
      end: _isBreast ? _start.add(_breastTotal) : _start,
      leftDuration: _isBreast ? _left : Duration.zero,
      rightDuration: _isBreast ? _right : Duration.zero,
      endSide: _isBreast ? _endSide : null,
      amountMl: _isBreast ? 0 : _amountMl,
      notes: _notes.text.trim(),
    );
    await widget.store.upsert(feeding);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    Navigator.of(context).pop();
    await widget.store.delete(existing.id);
    widget.onDeleted?.call(existing);
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final headerColor = _isBreast ? AppColors.indigo : AppColors.sand;
    final onHeader = _isBreast ? Colors.white : AppColors.ink;
    final title = _isBreast ? 'Breastfeeding' : 'Bottle feeding';

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
                        _isEditing ? 'Edit ${title.toLowerCase()}' : title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: onHeader,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
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
                  color: AppColors.cream,
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
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isBreast) ..._breastFields() else ..._bottleFields(),
                      _NotesRow(controller: _notes, onChanged: () => setState(() {})),
                      if (_isEditing)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete feeding'),
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

  List<Widget> _breastFields() {
    // The side the previous feed ended on, so parents can alternate.
    final lastSide =
        _isEditing ? null : widget.store.lastWhere((f) => f.type == FeedingType.breast)?.endSide;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Row(
          children: [
            for (final side in BreastSide.values)
              Expanded(
                child: _SideTimer(
                  side: side,
                  elapsed: _elapsed(side),
                  running: _active == side,
                  wasLastSide: lastSide == side,
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
                selectedColor: AppColors.indigo,
                onTap: () => setState(() {
                  _error = null;
                  _endSide = side;
                }),
              ),
            ],
          ],
        ),
      ),
      _FormRow(
        label: 'Start time',
        onTap: _pickStart,
        trailing: _RowValue(_dayAndTime(_start)),
      ),
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
    final last = _lastAmount;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final content in const [FeedingType.breastMilk, FeedingType.bottle]) ...[
              if (content == FeedingType.bottle) const SizedBox(width: 24),
              _ContentCircle(
                label: content == FeedingType.bottle ? 'Formula' : 'Breast\nmilk',
                selected: _type == content,
                color: AppColors.forType(content),
                onTap: () => setState(() => _type = content),
              ),
            ],
          ],
        ),
      ),
      _FormRow(
        label: 'Start time',
        onTap: _pickStart,
        trailing: _RowValue(_dayAndTime(_start)),
      ),
      _FormRow(
        label: 'Amount',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove,
              tooltip: 'Less',
              onTap: _amountMl > 0 ? () => _setAmount(_amountMl - 10) : null,
            ),
            InkWell(
              onTap: _typeAmount,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minWidth: 84),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                alignment: Alignment.center,
                child: Text(
                  '$_amountMl ml',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              tooltip: 'More',
              onTap: () => _setAmount(_amountMl + 10),
            ),
          ],
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
                onPressed: () => _setAmount(last),
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
        decoration: BoxDecoration(
          color: AppColors.softBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  const _MenuOption({required this.type, required this.title, required this.subtitle});

  final FeedingType type;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: FeedingTypeIcon(type: type, size: 48),
      title: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink),
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
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
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

class _SideTimer extends StatelessWidget {
  const _SideTimer({
    required this.side,
    required this.elapsed,
    required this.running,
    required this.wasLastSide,
    required this.onToggle,
    required this.onEdit,
  });

  final BreastSide side;
  final Duration elapsed;
  final bool running;
  final bool wasLastSide;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = side == BreastSide.left ? 'Left' : 'Right';
    final action = running
        ? 'Pause'
        : elapsed > Duration.zero
            ? 'Resume ${name.toLowerCase()}'
            : 'Start ${name.toLowerCase()}';
    return Column(
      children: [
        SizedBox(
          height: 28,
          child: wasLastSide
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Last side',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                )
              : null,
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
                tooltip: 'Enter $name time',
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
                  minimumSize: const Size(120, 48),
                  shape: const StadiumBorder(),
                ),
              )
            : OutlinedButton(
                onPressed: onToggle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink, width: 1.5),
                  textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: Text(action),
              ),
      ],
    );
  }
}

class _ContentCircle extends StatelessWidget {
  const _ContentCircle({
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
          width: 104,
          height: 104,
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? selectedColor : AppColors.ink, width: 1.25),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
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

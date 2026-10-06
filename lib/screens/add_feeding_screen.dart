import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/feeding_store.dart';
import '../models/feeding.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/bottle_gauge.dart';
import '../widgets/common.dart';

class AddFeedingScreen extends StatefulWidget {
  const AddFeedingScreen({super.key, required this.store, this.existing});

  final FeedingStore store;
  final Feeding? existing;

  @override
  State<AddFeedingScreen> createState() => _AddFeedingScreenState();
}

class _AddFeedingScreenState extends State<AddFeedingScreen> {
  late FeedingType _type;
  late DateTime _start;
  late DateTime _end;
  bool _endEdited = false;
  late final TextEditingController _notes;

  // Breastfeeding timers.
  Duration _left = Duration.zero;
  Duration _right = Duration.zero;
  BreastSide? _active;
  DateTime? _activeSince;
  BreastSide? _endSide;
  Timer? _ticker;

  // Bottle / breast milk.
  int _amountMl = 30;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _type = e?.type ?? FeedingType.breast;
    _start = e?.start ?? DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _end = e?.end ?? _start.add(const Duration(minutes: 30));
    _endEdited = e != null;
    _notes = TextEditingController(text: e?.notes ?? '');
    _left = e?.leftDuration ?? Duration.zero;
    _right = e?.rightDuration ?? Duration.zero;
    _endSide = e?.endSide;
    if (e != null && e.isBottle) _amountMl = e.amountMl;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notes.dispose();
    super.dispose();
  }

  // ---- Breastfeeding timer -------------------------------------------------

  Duration _elapsed(BreastSide side) {
    var d = side == BreastSide.left ? _left : _right;
    if (_active == side && _activeSince != null) {
      d += DateTime.now().difference(_activeSince!);
    }
    return d;
  }

  Duration get _breastTotal => _elapsed(BreastSide.left) + _elapsed(BreastSide.right);

  void _commitActive() {
    final side = _active;
    final since = _activeSince;
    if (side == null || since == null) return;
    final now = DateTime.now();
    final add = now.difference(since);
    if (side == BreastSide.left) {
      _left += add;
    } else {
      _right += add;
    }
    _activeSince = now;
  }

  void _syncEndWithTimers() {
    final total = _breastTotal;
    if (_type == FeedingType.breast && !_endEdited && total > Duration.zero) {
      _end = _start.add(total);
    }
  }

  void _toggleSide(BreastSide side) {
    setState(() {
      if (_active == null && _left == Duration.zero && _right == Duration.zero && !_isEditing) {
        _start = DateTime.now();
      }
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
          _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
            setState(_syncEndWithTimers);
          });
        }
      }
      _syncEndWithTimers();
    });
  }

  void _resetTimers() {
    setState(() {
      _ticker?.cancel();
      _active = null;
      _activeSince = null;
      _left = Duration.zero;
      _right = Duration.zero;
      _endSide = null;
    });
  }

  Future<void> _editSideDuration(BreastSide side) async {
    if (_active == side) _toggleSide(side); // pause before editing
    var picked = _elapsed(side);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${side == BreastSide.left ? 'Left' : 'Right'} breast duration',
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
      if (side == BreastSide.left) {
        _left = picked;
      } else {
        _right = picked;
      }
      _syncEndWithTimers();
    });
  }

  // ---- Date & time ---------------------------------------------------------

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null) return;
    _setDateTime(
      isStart,
      DateTime(date.year, date.month, date.day, current.hour, current.minute),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;
    _setDateTime(
      isStart,
      DateTime(current.year, current.month, current.day, time.hour, time.minute),
    );
  }

  void _setDateTime(bool isStart, DateTime value) {
    setState(() {
      if (isStart) {
        final length = _end.difference(_start);
        _start = value;
        if (!_endEdited) _end = _start.add(length);
      } else {
        _end = value;
        _endEdited = true;
      }
    });
  }

  // ---- Save ----------------------------------------------------------------

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_active != null) {
      _commitActive();
      _ticker?.cancel();
      _active = null;
      _activeSince = null;
      _syncEndWithTimers();
    }

    if (_end.isBefore(_start)) {
      _showError('End time must be after the start time.');
      return;
    }
    if (_type == FeedingType.breast) {
      if (_endSide == null) {
        _showError('Please choose which breast you ended with.');
        return;
      }
      if (_left + _right == Duration.zero && _end == _start) {
        _showError('Add a duration or start and end time.');
        return;
      }
    } else if (_amountMl <= 0) {
      _showError('Please set an amount.');
      return;
    }

    final isBreast = _type == FeedingType.breast;
    final feeding = Feeding(
      id: widget.existing?.id ?? widget.store.newId(),
      type: _type,
      start: _start,
      end: _end,
      leftDuration: isBreast ? _left : Duration.zero,
      rightDuration: isBreast ? _right : Duration.zero,
      endSide: isBreast ? _endSide : null,
      amountMl: isBreast ? 0 : _amountMl,
      notes: _notes.text.trim(),
    );
    await widget.store.upsert(feeding);
    if (mounted) Navigator.of(context).pop();
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Stack(
          children: [
            const PurpleHeaderBackground(height: 320),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 24),
                  _buildTabs(),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_type == FeedingType.breast)
                            ..._buildBreastSection(context)
                          else
                            ..._buildBottleSection(context),
                          const SizedBox(height: 24),
                          _buildDateTimeRow('Start time', isStart: true),
                          const SizedBox(height: 16),
                          _buildDateTimeRow('End time', isStart: false),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _notes,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Notes',
                              filled: true,
                              fillColor: AppColors.field,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _save,
                            child: Text(_isEditing ? 'Save changes' : 'Save'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left, size: 30),
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
              fixedSize: const Size(52, 52),
            ),
          ),
          Expanded(
            child: Text(
              _isEditing ? 'Edit feeding' : 'Add a feeding',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final type in FeedingType.values) ...[
            _TypeTab(
              label: type.label,
              selected: _type == type,
              onTap: () => setState(() => _type = type),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildBreastSection(BuildContext context) {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Select left or right to start',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19),
            ),
          ),
          IconButton(
            onPressed: _resetTimers,
            tooltip: 'Reset timers',
            icon: const Icon(Icons.restart_alt, color: AppColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final side in BreastSide.values)
            _SideTimerCircle(
              label: side == BreastSide.left ? 'Left' : 'Right',
              running: _active == side,
              elapsed: _elapsed(side),
              onTap: () => _toggleSide(side),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          for (final side in BreastSide.values) ...[
            if (side == BreastSide.right) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  _FieldButton(
                    label: formatClock(_elapsed(side)),
                    onTap: () => _editSideDuration(side),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 20),
      const Text('Which breast did you end with?*', style: TextStyle(fontSize: 16)),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final side in BreastSide.values) ...[
            if (side == BreastSide.right) const SizedBox(width: 12),
            Expanded(
              child: _ChoiceButton(
                label: side == BreastSide.left ? 'Left' : 'Right',
                selected: _endSide == side,
                onTap: () => setState(() => _endSide = side),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        '*required to fill in',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ];
  }

  List<Widget> _buildBottleSection(BuildContext context) {
    void setAmount(int v) => setState(() => _amountMl = v.clamp(0, 500));
    return [
      if (_type == FeedingType.breastMilk)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Expressed breast milk given by bottle',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      BottleGauge(amountMl: _amountMl, onChanged: setAmount),
      const SizedBox(height: 24),
      const Text('Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: _amountMl > 0 ? () => setAmount(_amountMl - 10) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FieldButton(
              label: '$_amountMl ml',
              onTap: () => _editAmount(setAmount),
            ),
          ),
          const SizedBox(width: 10),
          _StepButton(icon: Icons.add, onTap: () => setAmount(_amountMl + 10)),
        ],
      ),
    ];
  }

  Future<void> _editAmount(ValueChanged<int> setAmount) async {
    final controller = TextEditingController(text: '$_amountMl');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount (ml)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'ml'),
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value != null) setAmount(value);
  }

  Widget _buildDateTimeRow(String label, {required bool isStart}) {
    final value = isStart ? _start : _end;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
        Flexible(
          flex: 3,
          child: _FieldButton(
            label: DateFormat('d MMM yyyy').format(value),
            onTap: () => _pickDate(isStart: isStart),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: _FieldButton(
            label: DateFormat.Hm().format(value),
            onTap: () => _pickTime(isStart: isStart),
          ),
        ),
      ],
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.ink : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SideTimerCircle extends StatelessWidget {
  const _SideTimerCircle({
    required this.label,
    required this.running,
    required this.elapsed,
    required this.onTap,
  });

  final String label;
  final bool running;
  final Duration elapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = running ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      label: '$label breast timer, ${running ? 'running' : 'paused'}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: running ? AppColors.primary : AppColors.soft,
            border: Border.all(color: running ? AppColors.primary : AppColors.softBorder, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fg),
              ),
              if (running || elapsed > Duration.zero) ...[
                const SizedBox(height: 4),
                Text(formatClock(elapsed), style: TextStyle(color: fg)),
                Icon(running ? Icons.pause : Icons.play_arrow, color: fg, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 17)),
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.soft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.softBorder, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
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
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: onTap == null ? AppColors.muted : AppColors.ink),
        ),
      ),
    );
  }
}

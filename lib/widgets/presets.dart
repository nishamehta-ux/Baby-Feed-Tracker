import 'package:flutter/material.dart';

import '../models/entry.dart';
import 'common.dart';

/// Routines offered in the Routine drawer. Anything else can be typed.
const routinePresets = <(String, IconData)>[
  ('Sleep', Icons.bedtime_rounded),
  ('Bath', Icons.bathtub_rounded),
  ('Nail trim', Icons.content_cut_rounded),
  ('Play time', Icons.toys_rounded),
  ('Story time', Icons.menu_book_rounded),
  ('Tummy time', Icons.child_care_rounded),
  ('Vitamin or probiotic', Icons.medication_rounded),
  ('Walk or outdoor time', Icons.park_rounded),
];

/// One kind of thing the Other drawer can log.
class OtherPreset {
  const OtherPreset({
    required this.name,
    required this.icon,
    required this.valueLabel,
    this.unit = '',
    this.numeric = false,
  });

  final String name;
  final IconData icon;

  /// Label of the value row ("Weight", "Which vaccine").
  final String valueLabel;
  final String unit;
  final bool numeric;
}

const otherPresets = <OtherPreset>[
  OtherPreset(
      name: 'Weight',
      icon: Icons.monitor_weight_rounded,
      valueLabel: 'Weight',
      unit: 'kg',
      numeric: true),
  OtherPreset(
      name: 'Height', icon: Icons.height_rounded, valueLabel: 'Height', unit: 'cm', numeric: true),
  OtherPreset(
      name: 'Head size',
      icon: Icons.face_rounded,
      valueLabel: 'Around the head',
      unit: 'cm',
      numeric: true),
  OtherPreset(
      name: 'Temperature',
      icon: Icons.thermostat_rounded,
      valueLabel: 'Temperature',
      unit: '°C',
      numeric: true),
  OtherPreset(
      name: 'Medicine',
      icon: Icons.medication_liquid_rounded,
      valueLabel: 'Which medicine and dose'),
  OtherPreset(name: 'Vaccine', icon: Icons.vaccines_rounded, valueLabel: 'Which vaccine'),
  OtherPreset(name: 'Baby first', icon: Icons.star_rounded, valueLabel: 'What happened'),
];

/// The preset an Other entry was made from, if its name matches one.
OtherPreset? otherPresetFor(String title) {
  for (final p in otherPresets) {
    if (p.name == title) return p;
  }
  return null;
}

IconData? _routineIcon(String title) {
  for (final (name, icon) in routinePresets) {
    if (name == title) return icon;
  }
  return null;
}

/// The icon to show for [e]: its routine or preset icon when it has one.
IconData iconForEntry(Entry e) => switch (e.type) {
      EntryType.routine => _routineIcon(e.title) ?? iconForType(e.type),
      EntryType.other => otherPresetFor(e.title)?.icon ?? iconForType(e.type),
      _ => iconForType(e.type),
    };

import 'package:flutter/material.dart';

import '../models/entry.dart';
import 'common.dart';

/// Routines offered in the Routine drawer. Anything else can be typed.
const routinePresets = <(String, IconData)>[
  ('Bath', Icons.bathtub_outlined),
  ('Nail trim', Icons.content_cut_rounded),
  ('Play time', Icons.toys_outlined),
  ('Story time', Icons.menu_book_outlined),
  ('Tummy time', Icons.child_care_outlined),
  ('Vitamin or probiotic', Icons.medication_outlined),
  ('Walk or outdoor time', Icons.park_outlined),
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
      icon: Icons.monitor_weight_outlined,
      valueLabel: 'Weight',
      unit: 'kg',
      numeric: true),
  OtherPreset(
      name: 'Height', icon: Icons.height_rounded, valueLabel: 'Height', unit: 'cm', numeric: true),
  OtherPreset(
      name: 'Head size',
      icon: Icons.face_outlined,
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
      icon: Icons.medication_liquid_outlined,
      valueLabel: 'Which medicine and dose'),
  OtherPreset(name: 'Vaccine', icon: Icons.vaccines_outlined, valueLabel: 'Which vaccine'),
  OtherPreset(name: 'Baby first', icon: Icons.star_outline_rounded, valueLabel: 'What happened'),
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

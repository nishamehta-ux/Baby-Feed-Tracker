# Baby Feed Tracker

A simple Flutter app for logging a baby's feedings and seeing daily and weekly summaries.

## Features

- **Three feeding types**
  - **Breastfeeding**: tap the Left/Right circles to start, pause or switch the side timers. You can also type each side's time. Choose which breast you ended with (required).
  - **Bottle feeding** (formula): set the amount with the bottle gauge (tap or drag it), the −/+ buttons (10 ml steps), or by typing.
  - **Breast milk (bottle)**: expressed breast milk given by bottle, with the same amount controls.
  - Every entry has a start and end date/time and optional notes.
- **Overview**
  - **Week view** (Mon–Sun): weekly totals, daily averages, an hourly grid coloured by feeding type, and a per-day breakdown. Tap a day to open it.
  - **Day view**: totals for the day and a list of feedings. Tap one to edit it, swipe left to delete it (with undo).
  - A banner with the time of the last feeding, and arrows to move between weeks or days.
- The baby's name can be edited by tapping it.
- Data is stored on the device with `shared_preferences`.

## Run

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter analyze
flutter test
```

## Structure

```
lib/
  main.dart                    app entry
  theme.dart                   colours and theme
  models/feeding.dart          Feeding model + JSON
  models/summary.dart          daily/weekly totals and formatting
  data/feeding_store.dart      in-memory store persisted to shared_preferences
  screens/home_screen.dart     overview (week/day)
  screens/add_feeding_screen.dart  add/edit a feeding
  widgets/                     week grid, bottle gauge, shared UI
```

## Screenshots

| Week | Day | Breastfeeding | Bottle |
|---|---|---|---|
| ![](docs/screenshots/week.png) | ![](docs/screenshots/day.png) | ![](docs/screenshots/add_breastfeeding.png) | ![](docs/screenshots/add_bottle.png) |

# Baby Feed Tracker

A simple Flutter app for logging a baby's feedings and seeing daily and weekly summaries.

## Features

- **Two ways to log a feeding**
  - **Breastfeeding**: tap the Left/Right circles to start, pause or switch the side timers. You can also type each side's time. Choose which breast you ended with (required).
  - **Bottle feeding**: choose what's in the bottle (**formula** or expressed **breast milk**), then set the amount with the bottle gauge (tap or drag it), the −/+ buttons (10 ml steps), or by typing.
  - Every entry has a start and end date/time and optional notes.
- **Overview**
  - **Day view** (default): totals for the day and a list of feedings. Tap one to edit it, swipe left to delete it (with undo).
  - **Week view** (Mon–Sun): weekly totals, two trend line charts and a per-day list. Tap a day to open it.
    - *Bottle feeding* plots formula and breast milk (ml) together. *Breastfeeding* plots time at the breast.
    - Switch between *This week* (total per day; today is dashed until it ends) and *8 weeks* (average per day for each week) to see how feeds increase.
    - Each line shows this week's daily average and the change on last week. Tap or drag across a chart to read a day or week. Current-week averages count finished days only.
  - A banner with the time of the last feeding, and arrows to move between days or weeks.
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
  widgets/                     trend line chart, bottle gauge, shared UI
```

## Screenshots

| Week (8-week trends) | Day | Breastfeeding | Bottle |
|---|---|---|---|
| ![](docs/screenshots/week.png) | ![](docs/screenshots/day.png) | ![](docs/screenshots/add_breastfeeding.png) | ![](docs/screenshots/add_bottle.png) |

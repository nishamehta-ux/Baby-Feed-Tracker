<p align="center"><img src="assets/branding/ohbaby_logo.png" alt="Oh baby baby!" width="420"></p>

# Oh baby baby!

A simple Flutter app for logging a baby's feedings and seeing daily and weekly summaries.

## Features

- **Logging happens in drawers.** *Add a feeding* opens a drawer to pick Breastfeeding or Bottle feeding; each opens a tall drawer with Close, the title and Save at the top.
  - **Breastfeeding**: start, pause or switch the left and right timers, or tap the pencil to type a side's time. A "Last side" tag marks where the previous feed ended. *Ended on* fills in from the last timer used.
  - **Bottle feeding**: pick **breast milk** or **formula**, set the amount with −/+ (10 ml steps) or by typing, or tap **Yes** to reuse the last amount.
  - Both have a start time and notes. Closing a drawer with unsaved input asks first; editing a feeding adds *Delete feeding*.
- **Two tabs**
  - **Today** (landing page): *Add a feeding*, a *Last feeding* card (how long ago and how much), a **Summary** for *Today* or the *Last 24 h* (a count per feeding type, breastfeeding time with left/right, bottle total split into breast milk and formula), and the **Timeline** of feedings. Arrows step back through earlier days. Tap a feeding to edit it, swipe left to delete it (with undo).
  - **Week**: the average per day for breastfeeding, formula and breast milk by bottle, the change on last week, and a small line showing the last 8 weeks. Below that is a list of the days; tap one to open it on the Today tab. Current-week averages count finished days only.
- The baby's name can be edited by tapping it.
- Data is stored on the device with `shared_preferences`.

## Brand

- **Palette**: `#413C58` indigo · `#A3C4BC` sage · `#BFD7B5` mint · `#E7EFC5` cream · `#F2DDA4` sand. Breastfeeding is indigo, formula is sand and breast milk is sage. Thin chart lines use deeper steps of sand and sage so they stay visible on white.
- **Logo**: a sleepy baby face with a curl of hair and a little "oh" mouth, in `assets/branding/` (SVG and PNG). App icons are generated from `ohbaby_app_icon.png` with `dart run flutter_launcher_icons`.
- **Name**: "Oh baby baby!" everywhere, except under the iPhone home-screen icon, which shows "Oh baby!" because iOS cuts off longer names.
- **Typeface**: [Nunito](https://github.com/googlefonts/nunito), bundled under the SIL Open Font License (`assets/fonts/OFL.txt`).

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
  screens/main_shell.dart      bottom tabs (Today, Week)
  screens/today_screen.dart    landing page: last feeding, summary, timeline
  screens/feeding_sheet.dart   add/edit drawers
  screens/week_screen.dart     weekly summary
  widgets/                     logo, shared UI
```

## Screenshots

| Week | Today | Breastfeeding drawer | Bottle drawer |
|---|---|---|---|
| ![](docs/screenshots/week.png) | ![](docs/screenshots/day.png) | ![](docs/screenshots/add_breastfeeding.png) | ![](docs/screenshots/add_bottle.png) |

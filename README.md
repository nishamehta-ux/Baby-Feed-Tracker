<p align="center"><img src="assets/branding/ohbaby_logo.png" alt="Oh baby baby!" width="420"></p>

# Oh baby baby!

A simple Flutter app for logging a baby's feeds, pumping, diapers, routines and anything else (weight, temperature, medicine, vaccines, firsts), with daily and weekly summaries.

## Features

- **Logging happens in drawers.** *Add an entry* opens a drawer to pick what to log; each kind opens a tall drawer with Close, the title and Save at the top, in its own colour.
  - Every drawer saves from a full-width **Save** button at the bottom of the form. Times are picked in one step (day and time on one wheel, with *Now*), durations on an hours-and-minutes wheel with quick picks (5 min … 1 h), and amounts in ml can be typed or stepped with − / +.
  - **Breastfeeding**: start, pause or switch the left and right timers, or tap the pencil to type a side's time. Or tap *Total time* to enter the whole feed's length at once (it counts towards the side under *Ended on*, left if none). A "Last side" tag marks where the previous feed ended. *Ended on* fills in from the last timer used.
  - **Bottle feeding**: pick **breast milk** or **formula**, set the amount with −/+ (10 ml steps) or by typing, or tap **Yes** to reuse the last amount.
  - **Pumping**: a timer, and the amount per side or in total (5 ml steps).
  - **Diaper**: wet, dirty (both together allowed) or dry, and a diaper-rash switch.
  - **Routine**: sleep, bath, nail trim, play time, story time, tummy time, vitamin or probiotic, walk or outdoor time, or something typed. Optionally timed: a timer, or a start and end time.
  - **Other**: one entry for anything else. Presets for weight (kg), height (cm), head size (cm), temperature (°C), medicine, vaccine and baby firsts, or *Something else* with your own name, value and unit. Can also be timed, like routines.
  - Every entry has a time and notes. Closing a drawer with unsaved input asks first; editing an entry adds *Delete entry*.
- **Two tabs**
  - **Today** (landing page): a floating *Add an entry* button; **Quick add** tiles that open a breastfeeding or pumping timer card, or log a repeat of the last bottle or a wet or dirty diaper at once (with Undo). The tiles are ordered by use: whatever you logged most in the last 14 days comes first. The timer does not start on its own: it starts when you pick a side (*Start left* / *Start right*, with the last side marked) or tap *Start* for pumping. From then on you can switch side, pause, finish to review and save, or discard, and it keeps running in the background and across app restarts. Below that, the day card shows a one-line *Last feeding*, chips with the day's totals (breastfeeding time, bottle ml, pumped ml, diapers), and the **Timeline** as the main content: each entry with its time on the left. Arrows step through days, and tapping the date opens a calendar to jump to any day, however long ago. Tap an entry to edit it, swipe left to delete it (with undo).
  - **Family** (on Profile): invite a partner, grandparent or nanny by name and email, with *Can add and edit* or *View only* access. Sending opens your email app with a ready-written invitation and a 6-character join code (or copies it when there is no email app). Each invite shows as *Invited* with its date; tap it to send it again, change access or cancel it. *Got an invite? Join a family* takes a code on the other person's phone. Every new entry records who logged it, shown as "by Raj" in the timeline once there is more than one person. **Joining and shared tracking need the sync server**: until it exists, invites, codes and members are stored on each phone only, and the join code waits on the invitee's phone.
  - **Health passport** (from Profile): the latest information to show or send to a doctor. The baby's name, birth date and age; the latest weight, height, head size and temperature (with the change since the reading before); every vaccine given, with dates; every medicine and vitamin (grouped by what was written, with how many times and when last given); and daily averages over the last 7, 14 or 30 finished days (feeds, breastfeeding time, formula and breast-milk bottles, pumping, diapers wet and dirty, logged sleep). **Share with doctor** opens the phone's share sheet with a plain-text summary (email on devices without one), and **Copy** puts it on the clipboard. It notes that it was logged by parents and isn't a medical record.
  - **Calendar** (third tab): every appointment in one place. A month view with a dot on days that have something planned (arrows to move between months), the chosen day's appointments, the next one up, and an upcoming list. **Add appointment** takes the kind (check-up, vaccination, doctor visit, specialist, hearing or eye test, other), a title, the date and time in one step (5-minute steps, any day up to three years ahead), who it's with, where, and notes such as questions to ask; tap an appointment to edit or delete it. Today shows the next appointment when it's within a week (tap it to open the calendar, or ✕ to dismiss it; the next appointment shows again). Every appointment also has **Visit notes** for afterwards (what the doctor said, advice, next steps), kept apart from *To ask or bring*. The calendar lists **Past visits** led by their notes (the date, doctor and place underneath), or *Add visit notes* for one without; opening a past appointment puts its visit notes first and the appointment details after, and the health passport includes the five most recent visits with notes, in the shared text too.
  - **Profile** (third tab): the baby's photo (from the photo library, stored small on the device), name and date of birth, with their age shown here and next to the photo on Today; the appearance switch; and **Sign in / Log out**. Accounts are kept on this device only (name and email) until the server is connected; logging out keeps every entry and the baby's profile.
  - **Trends**: switch between **7 days** (a rolling *Last 7 days*: today and the six days before, not a calendar week) and **Month**; arrows go back 7 days or a month at a time, as far as you like, and tapping the dates opens a calendar to jump to the 7 days up to any date, or any month. For the period on screen: the average per day of breastfeeding, formula, breast milk by bottle, pumping and diapers, compared with the previous period; how many times each routine happened, or for timed routines such as sleep, the average time a day; and **Measurements**, every number logged under Other (weight, height, head size, temperature, or your own) with its latest reading and the change since the one before. Each row has a small line of the last 8 weeks (7 days at a time) or 6 months (or the latest readings); tap it for a full chart and every value. Below that, **Each day** lists the period's days with their totals on one line (breastfeeding time, bottle ml, pumped ml, diapers) and, beneath, that day's routines and Other entries (with total time for timed ones, e.g. *Sleep 2h 30m*, and the reading for measurements). Tap a day to see its full timeline, routines and Other included, in a bottom sheet, with a button to open it on Today to edit. Averages count finished days only, and none before the first entry ever logged.
- The baby's name can be edited by tapping it.
- Data is stored on the device with `shared_preferences`.

## Brand

- **Palette**: main colours taupe `#EDDCD2`, mint `#DBE7E4` and mist `#D6E2E9` with a linen `#F0EFEB` base, plus added lilac for routines, charcoal `#263241` for text and steel for the main button. Light mode uses slightly richer steps of these for contrast: a deeper page `#E9E7E1` with white cards on a soft shadow; feeds `#E8CFC0`, pumping `#C9DAE5`, diapers `#CBDFD8`, routines `#DDD5EA`; selected `#B8CDDB`; main button `#3D5A70` with white text (7.3:1). Colour has few jobs: the main button colour only for the primary action, one selection colour for anything chosen or running, and one colour per group of entries (all feeds share one; their icons tell them apart). Every Material role in the theme is set from these. Chart lines use deeper steps of the same hues so they stay visible on white.
- **Dark mode**: follows the phone's light or dark setting by default; the Profile tab switches between *Match phone*, *Light* and *Dark*, and the choice is remembered. Dark mode uses a charcoal page (`#15191E`) with slightly lighter cards (`#1F252C`), light text, a light steel-blue main button with dark text, and deep tones of the entry colours (feeds `#5C4A40`, pumping `#3D5566`, diapers `#3C5850`, routines `#4E4865`) with near-white icons, so nothing glares at night. Text and icons are tuned to at least 4.5:1 contrast in both modes (icons on the entry colours 6.5:1 or more). Every colour role in `lib/theme.dart` has a light and a dark value.
- **Logo**: a sleepy baby face with a curl of hair and a little "oh" mouth, in `assets/branding/` (SVG and PNG). App icons are generated from `ohbaby_app_icon.png` with `dart run flutter_launcher_icons`.
- **Name**: "Oh baby baby!" everywhere, except under the iPhone home-screen icon, which shows "Oh baby!" because iOS cuts off longer names.
- **Typefaces**: app text uses [TeX Gyre Heros](https://www.gust.org.pl/projects/e-foundry/tex-gyre/heros), a free font drawn after Helvetica (GUST Font License, `assets/fonts/GUST-FONT-LICENSE.txt`); Helvetica itself can't be bundled under its licence. The logo wordmark uses [Nunito](https://github.com/googlefonts/nunito) (SIL Open Font License, `assets/fonts/OFL.txt`).

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
  models/entry.dart            Entry model (every kind of entry) + JSON
  models/summary.dart          daily/weekly totals and formatting
  models/trends.dart           measurement series and routine counts
  models/live_timer.dart       breastfeeding/pumping timer started from Today
  data/entry_store.dart        in-memory store persisted to shared_preferences
  screens/main_shell.dart      bottom tabs (Today, Week)
  screens/today_screen.dart    landing page: quick add, day totals, timeline
  screens/entry_sheet.dart     add/edit drawers for every kind of entry
  screens/trends_screen.dart   Trends tab
  screens/trend_sheet.dart     full chart of one trend
  widgets/                     logo, presets, quick add + live timer, sparkline, trend chart, shared UI
```

## Screenshots

| Today | Add menu | Trends | Weight chart |
|---|---|---|---|
| ![](docs/screenshots/day.png) | ![](docs/screenshots/add_menu.png) | ![](docs/screenshots/week.png) | ![](docs/screenshots/trend_weight.png) |

| Breastfeeding | Bottle | Pumping | Diaper | Routine | Other |
|---|---|---|---|---|---|
| ![](docs/screenshots/add_breastfeeding.png) | ![](docs/screenshots/add_bottle.png) | ![](docs/screenshots/add_pump.png) | ![](docs/screenshots/add_diaper.png) | ![](docs/screenshots/add_routine.png) | ![](docs/screenshots/add_other.png) |

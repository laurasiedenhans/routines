# Routines App – Project Plan & Context

> This file is the central reference for the project. It serves as context for AI assistants (Claude, Xcode AI) and as documentation. Please update it whenever requirements or the architecture change.
>
> The app's UI is in German. UI labels are quoted in German as they appear in the app, with an English translation in parentheses where helpful.

Working title: **Routines** (placeholder)

---

## 1. Vision

A to-do app for **recurring routines**. Users create several lists (e.g. "Morgenroutine" / morning routine, "Wochenputz" / weekly cleaning), fill them with to-dos and check them off. When the configured recurrence period ends, all to-dos are automatically open again. Lists with a start time trigger a **Live Activity** in which the to-dos are checked off one after another.

---

## 2. Platforms & Requirements

| Item | Decision |
|---|---|
| Platforms | iOS, iPadOS, macOS – **one native SwiftUI multiplatform app** (no Mac Catalyst) |
| Minimum version | **iOS 26 / iPadOS 26 / macOS 26** (required for the planned Live Activities) |
| UI | SwiftUI |
| Persistence | SwiftData (local), later sync via CloudKit (private database) |
| External services | **none** (no own server, no third-party database) |
| App language | German (strings via String Catalog so the app can be translated later) |
| Developer account | Start with a free account; paid account only from phase 6 (iCloud sync) |

**Free account:** Local notifications, Live Activities and App Groups work. iCloud/CloudKit does not. The installation on the iPhone has to be renewed from Xcode every 7 days.

---

## 3. Scope

### MVP
- Multiple lists with name, emoji, colour
- Recurrence per list: none, daily, weekly, monthly, yearly – each with an interval n ("every n days/weeks/months/years") and a start day
- Optional start time per list
- Add to-dos (one-off or permanent), check off, uncheck, delete (only today / all future)
- Home screen with a daily progress ring and a list overview with progress bars
- Local notification at the start time
- Live Activity at the start time with sequential checking off

### Later
- iCloud sync (phase 6)
- Statistics / streaks / further analyses (history is already stored)
- Keep showing overdue "every n days" lists in the daily ring until the next period
- Trash ("Recently deleted"), then possibly deleting whole lists by swiping
- Archive for completed one-off lists (for statistics)
- Home Screen widgets (progress ring), interactive widgets
- Siri / Shortcuts via App Intents, Control Center control
- SF Symbols in addition to emojis
- Apple Watch
- Notion integration (private only): dedicated view mapping 1:1 to the to-do database, internal integration, token in the Keychain, changes (title, status, progress) written back to Notion via the API

---

## 4. Recurrence Logic (Core Logic)

### Core principle: nothing is ever "reset"
The app does **not reset any data** at midnight. Instead there are:
- **Task templates** (`RoutineTask`): the permanent to-do
- **Period records** (`TaskRecord`): "completed" or "skipped" for a specific period

A to-do counts as completed if a completed record exists for the **current period**. When a new period starts, there is no record for it yet → the to-do is automatically open again. No background process needed, no conflicts between devices, history included.

### Period
At any point in time, every list has exactly one current period `[periodStart, periodEnd)`. Boundaries always fall on **00:00 local time**. The period is stored as a `periodKey` in the format `yyyy-MM-dd` (date of `periodStart`) so it is stable across devices and time zones.

Every list with a recurrence has a **start day** (`anchorDate`, default: day of creation).

### Rules

Every recurrence kind has an **interval n ≥ 1** (default 1). Counting always starts from the start day.

| Kind | Period starts | Example |
|---|---|---|
| None | once on the start day, never ends | Moving checklist |
| Daily (every n days) | start day + k·n days, 00:00 | n = 1: every day; n = 3, start 1 Oct → 1 Oct, 4 Oct, 7 Oct … |
| Weekly (every n weeks) | on the chosen weekday at 00:00, every n weeks | Thu, n = 2 → every second Thursday at 00:00 |
| Monthly (every n months) | on the anchor day, every n months; if the day doesn't exist, on the last day of the month | Start 13 Jan, n = 1 → every 13th; start 30 Jan → 28/29 Feb, then 30 Mar; n = 3 → 30 Jan, 30 Apr, 30 Jul … |
| Yearly (every n years) | on the date of the start day, every n years; 29 Feb → 28 Feb in non-leap years | Start 29 Feb 2028 → 28 Feb 2029 |

Notes:
- **The anchor day is always kept (decided):** The original date is used whenever the month allows it. Moving to the last day of the month only applies to the affected month.
- **Weekly:** The weekday is stored separately (`weekday`). The first period starts on the last chosen weekday on or before the start day; the n weeks are counted from there.
- **No recurrence:** exactly one period from the start day, without an end. Completed to-dos stay completed permanently. The options "only today / always" (adding) and "only today / all future" (deleting) don't apply – tasks are simply added or deleted. The start time triggers once on the start day. Never counts towards the daily ring.
- **Daily ring:** counts lists of the kind "daily" with any n, but only on days on which their period starts (see 7.1).
- Before the start day, the list is not active and shows "Startet am …" (starts on …).

### Calculation (pseudocode)
```
func currentPeriod(for list, at date) -> (start, end):
  n = list.interval
  switch list.recurrence:
    none:    start = anchor; end = nil (open)
    daily:   k = floor(daysBetween(anchor, date) / n); start = anchor + k·n days
    weekly:  first = last day ≤ anchor with weekday == list.weekday
             k = floor(daysBetween(first, date) / (7·n)); start = first + k·7·n days
    monthly: k = floor(monthsBetween(anchor, date) / n)  // candidate = anchor month + k·n,
             start = clamp(anchorDay, monthLength)       // day clamped; if > date → k − 1
    yearly:  same with years, 29 Feb clamped
  end = nextPeriodStart(after: start)   // always recompute from anchor + (k+1)·n, never from the clamped predecessor
```
This logic lives in `RoutineKit` as pure, synchronously testable functions (`RecurrenceEngine`) with extensive unit tests (month ends, leap years, daylight saving time, time zone changes).

### Actions on to-dos
| Action | Implementation |
|---|---|
| Check off | create `TaskRecord(kind: .completed, periodKey: current)` |
| Uncheck | delete all `.completed` records of the current `periodKey` for this to-do |
| Delete "only today" | create `TaskRecord(kind: .skipped, periodKey: current)` |
| Delete "all future" | `RoutineTask.deletedAt = now` (soft delete, history is kept) |
| Add "one-off" | `RoutineTask.oneOffPeriodKey = current periodKey` |
| Add "always" | `RoutineTask` without `oneOffPeriodKey` |

### Behaviour of checked-off to-dos (deliberately different from Reminders)
- **Requirement:** A checked-off to-do stays completed until the end of the current period and does **not** immediately reappear as open (unlike the Reminders app, where recurring items jump to the next date as soon as they are checked off).
- Implementation: Checking off doesn't change the `RoutineTask`; it only creates a `TaskRecord` for the current `periodKey`. The to-do only becomes open again when a new period starts.
- For weekly/monthly/yearly lists, a to-do accordingly stays completed for the whole period.
- **Period change:** Data is never reset; only the **display** has to be recalculated (SwiftUI doesn't re-render on its own just because time passes). No background processes needed.
  - Implemented as one shared `@Observable` building block `AppClock` in `RoutineKit`, identical on **all platforms**. Views only read `now` from there. `AppClock` updates `now`:
    1. when the app becomes active (`scenePhase == .active`) – needed because timers don't run in suspended apps,
    2. via a one-shot timer to the next `periodEnd` of all lists (then rescheduled, no polling),
    3. on system events: day change, clock or time zone change (`significantTimeChangeNotification` / `NSCalendarDayChanged` / `NSSystemClockDidChange`).
  - Widgets/Live Activity: set the timeline entry or `staleDate` to the end of the period.
- Periods are calculated in local time; a time zone change can shift the change of period (accepted).

A to-do is **visible** in a period if: it was not deleted (or `deletedAt` is after the start of the period) **and** there is no `.skipped` record **and** (`oneOffPeriodKey == nil` or `== the period's key`). Permanent to-dos only appear from the period in which they were created.

---

## 5. Data Model (SwiftData, CloudKit-compatible)

CloudKit rules that are followed **from the start**:
- no `@Attribute(.unique)`
- every attribute optional or with a default value
- all relationships optional, with an inverse
- duplicates after sync are possible → logic must be tolerant (e.g. two completed records = completed)

```swift
@Model final class RoutineList {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "✅"
    var colorRaw: String = "blue"         // ListColor (Apple system colour, adapts to light/dark)
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    // Recurrence
    var recurrenceRaw: String = "daily"   // none | daily | weekly | monthly | yearly
    var interval: Int = 1                  // every n days/weeks/months/years (≥ 1)
    var weekday: Int = 2                   // 1 = Sun … 7 = Sat (Calendar), weekly only
    var anchorDate: Date = Date()          // start day

    // Start time & reminder
    var startTimeMinutes: Int? = nil       // minutes since 00:00, nil = no start time
    var notificationEnabled: Bool = false
    var liveActivityEnabled: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \RoutineTask.list)
    var tasks: [RoutineTask]? = []
}

@Model final class RoutineTask {
    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var deletedAt: Date? = nil             // soft delete ("all future")
    var oneOffPeriodKey: String? = nil     // set = only in this period
    var list: RoutineList?

    @Relationship(deleteRule: .cascade, inverse: \TaskRecord.task)
    var records: [TaskRecord]? = []
}

@Model final class TaskRecord {
    var id: UUID = UUID()
    var periodKey: String = ""             // yyyy-MM-dd of the period start
    var kindRaw: String = "completed"      // completed | skipped
    var createdAt: Date = Date()
    var task: RoutineTask?
}
```

Colours (`ColorPalette` in `RoutineKit/Theme/ListColor.swift`, experimental, still being fine-tuned): groups, each with its own row in the picker (7 per row, then wrap, grey divider between groups).
- **Apple:** 13 system colours (dark mode variants by Apple)
- **Chocolate:** Arsenic `#354242`, Morning Blue `#8B9B93`, American Silver `#CFCFCD`, Liver Chestnut `#55453A`, Bistre `#362419`
- **Denim:** Silver Chalice `#B5ACA3`, Pale Cornflower Blue `#B0D2EC`, Pewter Blue `#849DBB`, Silver Lake Blue `#648EC0`, Royal Brown `#533A33`
- **Forest green:** Cork Wedge `#C0A889`, Cheeky Chestnut `#7A4E39`, Green Beret `#536D5F`, Roycroft Bottle Green `#363F37`, Quartzite `#1F2B27`
- **Autumn leaves:** Space Cadet `#25344F`, Slate Gray `#617891`, Tan `#D5B893`, Coffee `#6F4D38`, Caput Mortuum `#632024`
- **Bordeaux:** Camel Coat `#C6B39A`, Boho `#7B694E`, Rubine `#6D3A3C`, Tamarind `#361319`, Italian Roast `#280B0F`
- **Dark mode variants** only for very dark colours: Bistre `#8B7568`, Quartzite `#707E79`, Italian Roast `#866063` (same hue and chroma, only lighter, calculated in OKLCH).
- `colorRaw` stores the `rawValue` (e.g. `blue`, `italianRoast`). Never change existing keys.

---

## 6. Architecture

**Project data:** App "Routines", bundle ID `de.laurasiedenhans.Routines`, widget `de.laurasiedenhans.Routines.RoutinesWidget`, App Group (from phase 5) `group.de.laurasiedenhans.routines`. Created with Xcode 27, minimum version iOS/macOS 26.6. Synchronized folders: files in `Routines/Routines/` appear in Xcode automatically.

```
routines/                              Git repository
├── README.md
├── Docs/
│   ├── PROJECT.md                     this file
│   └── Images/                        screenshots used in the README
└── Routines/
    ├── Routines.xcodeproj
    ├── RoutineKit/                    local Swift package ("backend")
    │   ├── Sources/RoutineKit/
    │   │   ├── Models/                SwiftData models
    │   │   ├── Recurrence/            RecurrenceEngine (pure logic)
    │   │   ├── Services/              ListStatus, TaskVisibility, actions (ModelContext extension)
    │   │   ├── DayRing/               RingStyle, RingSelectionPolicy, DayRingSummary
    │   │   ├── Settings/              AppSettings (UserDefaults)
    │   │   ├── Clock/                 AppClock (incl. time travel for testing)
    │   │   ├── Persistence/           ModelContainer for app, sample data, previews
    │   │   ├── SampleData/            sample data set
    │   │   └── Theme/                 Theme, ListColor, EmojiInput
    │   │   (later: Scheduling/, Intents/, LiveActivity/)
    │   └── Tests/RoutineKitTests/     Swift Testing
    ├── Routines/                      multiplatform app target (iOS, iPadOS, macOS)
    │   ├── RoutinesApp.swift, ContentView.swift
    │   ├── Support/                   RecurrenceFormatting / PeriodFormatting (texts), QuickAddCenter, PreviewSupport
    │   └── Views/                     Home, Sections, ListDetail, ListSettings, Settings, Components
    └── RoutinesWidget/                widget extension (still the Xcode template, Live Activity in phase 5)
```

- **Separation:** All logic, models and intents live in `RoutineKit`. The app and the extension are thin UI layers. UI texts live in the app (String Catalog).
- **App Group:** only add it in phase 5. `ModelConfiguration(groupContainer: .automatic)` then uses it automatically; switch `AppSettings.sharedDefaults` to the group suite.
- **ModelContainer:** `RoutinePersistence.makeContainer()` with `groupContainer: .automatic, cloudKitDatabase: .none` (phase 6: `.private("iCloud.de.laurasiedenhans.Routines")`).
- Pattern: `@Query` in views, logic in `RoutineKit` (`ListStatus`, `DayRingSummary`, `ModelContext` actions).
- Time: views only read `AppClock.now` from the environment.

---

## 7. User Interface

### 7.0 Design approach & theme
- **Approach:** functional prototype first, then a design revision after everyday testing. No Figma; design directly in Xcode with previews, plus mockup canvases to compare variants.
- **Base style:** standard Apple design (iOS 26 / Liquid Glass, system fonts, system colours, standard components).
- **All style values centralised as default parameters** in a `Theme` (in `RoutineKit`) so they can later be changed in one place. Views **never** use hard-coded values. At least:
  - Colours: list palette, accent, backgrounds, ring track, completed state
  - Spacing (`spacing.xs … xl`), corner radii, row heights
  - Typography (text styles, weights)
  - Progress ring: diameter, line width, line cap, colour/gradient, track opacity, animation duration
  - Progress bar: height, radius
  - Toggle: size, line width
  - Animations (duration/spring for checking off, moving)
  - Period strip: chip height, radius, dot size, swipe threshold
- Components such as `ProgressRing`, `ListProgressBar` and `CheckToggle` get their default values from the `Theme` but can be overridden per call.

### 7.0a Navigation (iPhone)
- **Bottom navigation bar** in the iOS 26 style, not a continuous bar: two Liquid Glass containers (`GlassEffectContainer`), aligned to the edges, growing towards the centre.
  - **Left:** group with three sections (icon + text, icons are placeholders): **Heute** (Today – daily dashboard, default), **Routinen** (Routines), **Listen** (Lists). The active section is highlighted.
  - **Right:** separate round **"+"** button. On the overview screens it creates whatever fits the section: Today/Routines → "Neue Routine" (new routine), Lists → "Neue Liste" (new list). Always the same form, just with a matching preselection (recurrence daily or none). **Inside an open list** it opens the input row instead, exactly like "Aufgabe hinzufügen" (add task) (`QuickAddCenter`).
  - The bar is hidden while the keyboard is shown.
- **Routine vs. list:** no separate field. Routine = recurrence ≠ none, list = without recurrence. Changing the recurrence moves an entry between the sections.
- **Today (daily dashboard):** daily card with the ring (ring selection from the settings), below it "Heute fällig" (due today) = all daily routines (including "every n days") whose period starts today, regardless of the ring selection. No weekly, monthly, yearly or one-off lists. Customisable later.
- **Routines / Lists:** current entries, below them a collapsible "Geplant (n)" (planned, next first); for lists additionally a collapsible "Abgeschlossen (n)" (completed – all to-dos done).
- **Settings:** gear icon at the top right in all three sections.
- **Liquid Glass on list containers:** rejected (tried and reverted). SwiftUI offers no API for a glass background on whole `List` sections, only per row; rebuilding without `List` loses reordering and swiping. Apple also intends Liquid Glass for the floating navigation/control layer (tab bar, toolbars, buttons, sheets), not for content such as lists. Glass therefore stays on the daily card and the navigation bar.
- **iPad/Mac:** unchanged for now (sidebar with all lists, `HomeView`), will be redesigned later.

### 7.0b Cleaning up one-off lists
- **Detail view of a one-off list:** "Alle löschen" (delete all, with confirmation) in the header of "Erledigt (n)" (done) – permanently deletes all completed to-dos. Routines don't have this button.
- **"Wiederverwenden"** (reuse; only when the one-off list is completely done): deletes all to-dos; the list is then empty and back among the current lists. Name, symbol and colour are kept.
- **Lists section:** "Alle löschen" (with confirmation) in the header of "Abgeschlossen (n)".
- **Automatic:** setting "Abgeschlossene löschen" (delete completed): never (default) / 1 day / 3 days / 1 week / 2 weeks / 1 month. The deadline counts from the last checked-off to-do (`CompletedListCleanup`, no model change). Cleanup runs when the app opens, at the day change and when the setting changes. Completed lists show "Wird in n Tagen gelöscht" (will be deleted in n days).
- Whole lists **can't** be deleted by swiping (no trash yet, protection against accidental deletion).
- Deletion is permanent. An archive for statistics on one-off lists can be added later (optional field `archivedAt`), but would only cover lists from its introduction onwards.

### 7.1 Home screen
- **Top:** compact **daily card** (Liquid Glass): small ring on the left (~92 pt), text on the right ("Heute", "x von y täglichen To-dos" / x of y daily to-dos, "Als Nächstes: <list> · <start time>" / up next).
  - **Selectable for the ring:** all lists of the kind "daily", i.e. daily (n = 1) **and** every n days. Never weekly, monthly or yearly lists or lists without recurrence.
  - **Selected vs. due today:**
    - *Selected* = checked in the settings for the style. The maximum applies to the selection.
    - *Due today* = a new period of the list starts today (always for n = 1, every second day for n = 2, etc.).
    - Only lists that are **selected and due today** appear in the ring. On other days their segment or ring is missing, and **no other list moves up**.
    - **Percentage, "x of y" and "up next"** only refer to the lists visible today, so ring and numbers match.
    - E: The segment lengths are distributed across the lists visible today.
    - F: The rings visible today are **always as far out as possible** (in `sortOrder` order, no gaps). If a list is missing today, the remaining rings move outwards. Identified by the list colour.
    - "Due today" only applies on the first day of the period (decided). Possible later: keep showing overdue "every n days" lists in the ring until the next period (e.g. as a setting). Checking off in the list itself is already possible during the whole period anyway.
    - If no selected list is due today → the card shows "Heute keine Routinen fällig" (no routines due today).
  - **Selection per style:** Each style remembers its own selection (switching styles loses nothing).
    - Maximum: D unlimited, E max. 5, F max. 3.
    - Order in the ring = order of the lists (`sortOrder`); for F the first list is the outer ring.
    - **Default filling:** first lists with n = 1 (by `sortOrder`), then, if there's room left, lists with n > 1.
    - A new selectable list is added automatically as long as the style's maximum isn't reached.
    - **Never evict automatically:** A selected list (even with n > 1) is not removed automatically to make room for a new daily list. That only happens manually.
    - List deleted or changed to a non-selectable kind → automatically drops out of the selection.
    - No list selected → the card shows an empty ring and the hint "Listen in den Einstellungen auswählen" (select lists in the settings).
  - **The ring style can be chosen in the general settings** (see 7.5). All three styles are implemented (prototype in the canvas "Progress Ring Varianten"):
    - **D · Simple ring:** one ring in the accent colour, percentage inside the ring.
    - **E · Segments:** one segment per daily list in the list colour, length by number of to-dos, round caps (may slightly overlap visually or not join perfectly), no legend – the mapping comes from the list colours below.
    - **F · Nested rings:** like the Fitness activity rings, only the first 3 daily lists (by `sortOrder`), starting from the outside. The percentage is then shown in the text instead of the ring.
  - No progress (0) → hide the fill (round caps would otherwise draw a dot).
- **Below:** all active lists as rows:
  - emoji in a coloured circle, name, recurrence info
  - **Uniform recurrence info:** `rhythm · detail · time`, e.g. `Täglich · 06:30`, `Alle 2 Wochen · Do · 09:00`, `Monatlich · am 30.`, `Einmalig`. Detail only for weekly (weekday), monthly (day), yearly (date); time only with a start time. Shortened step by step when space is tight (`ViewThatFits`): first without detail, then rhythm only.
  - progress bar in the list colour (completed / total in the current period)
- **At the very bottom: "Geplant (n)"** (planned), collapsible (collapsed by default), only if present: lists whose start day lies in the future, sorted by start date (next first). Instead of a progress bar: "Startet am 26. Okt." (starts on 26 Oct). On the start day the list moves to the active lists automatically.
- Toolbar (iPad/Mac only, `HomeView`): **gear on the left** (`gearshape`) → general settings; **"+" on the right** to create a new list. For the iPhone see 7.0a.
- iPad/Mac: `NavigationSplitView` (lists on the left, detail on the right). iPhone: `NavigationStack`.

### 7.2 List detail
- Title with emoji, list colour as accent.
- Open to-dos at the top, each with a **round toggle on the right** (empty circle).
- Checking off → the toggle fills, and the to-do moves with an animation into the collapsed section **"Erledigt (n)"** (done) at the end (expandable, collapsed by default).
- Tapping a filled toggle again → the to-do becomes open again and moves back up.
- **Swipe left** → "Löschen" (delete) → `confirmationDialog`: "Nur heute löschen" (delete only today) / "Alle zukünftigen löschen" (delete all future) / "Abbrechen" (cancel).
- **Period strip (paging)** for recurring lists, below the title:
  - Daily 7 days (Mon–Sun), weekly 7 weeks, monthly 5 months, yearly 5 years; swiping sideways pages a whole strip. For "every n" only real occurrences. Not before the list's start.
  - Heading: current period "Heute" / "Diese Woche" / "Diesen Monat" / "Dieses Jahr" (today / this week / this month / this year), otherwise "Do 23.10.2026", "KW 50 2026" (calendar week), "Jan 2026", "2027". Weeks, months and years are named after the unit in which the period **mostly** lies (middle of the period). Below it the exact period, e.g. "Do 22.10. – Mi 28.10.".
  - Chips: daily weekday/day, weekly "KW"/number, monthly year/month, yearly anchor date/year. Selected = filled with the list colour, current period lightly tinted.
  - Dots: green = past, everything done; grey = past, something left open; orange = future, one-off task planned.
  - Past periods: view and check off retroactively; new tasks added there are always one-off.
  - Future periods: preview ("Vorschau · Abhaken ab … möglich" / preview · can be checked off from …), not checkable, plan tasks ahead ("Einmalig" / one-off preselected).
  - Away from the current period: a "Heute" / "Diese Woche" … button jumps back.
  - Permanent to-dos only appear from the period in which they were created.
- At the end of the list: **"+ Aufgabe hinzufügen"** (add task) → input row styled like a to-do (same height, empty circle on the right), below it the choice **"Immer / Einmalig"** (always / one-off), **without buttons**, like in the Reminders app: Return inserts the to-do at exactly this position without a sliding animation and opens the next empty row below; tapping outside the field or scrolling takes over the typed text and closes the input; an empty field simply closes.
- **Editing a to-do:** tapping the title turns it into a text field. Return or tapping outside saves. Empty title: the old text is kept.
- Order can be changed via drag & drop (`sortOrder`).
- **Top right: pencil** ("Liste bearbeiten" / edit list) → list settings.

### 7.3 List settings (sheet)
- Name
- Emoji (text field limited to one emoji + grid with suggestions; SwiftUI has no native emoji picker)
- Colour (preset palette like Reminders)
- Recurrence: none / daily / weekly (+ weekday) / monthly / yearly, each with a stepper "every n …" (hidden for "none")
- Start day (DatePicker)
- Start time on/off + time
- Notification on/off
- Live Activity on/off (only visible on iOS)
- Delete list (with confirmation)

### 7.4 New list
Same form as the settings, as a sheet from the home screen.

### 7.5 General settings
- **Access:** gear icon (SF Symbol `gearshape`) on the home screen, opens a sheet with a standard `Form`. On the Mac additionally via the app menu or ⌘, (SwiftUI `Settings` scene).
- **Home screen:**
  - **Ring style:** simple ring / segments / nested rings (picker with a small preview). Default: segments.
  - **Lists in the ring:** below it all selectable lists (daily and every n days, with rhythm info) with checkmarks for the chosen style, hint "x von max. 5 ausgewählt" (x of max. 5 selected); further checkmarks are disabled once the maximum is reached.
  - Stored as `ringSelection: [RingStyle: [UUID]]` (list IDs) in `AppSettings`.
- **Appearance:** system / light / dark (segmented control, default: system), implemented via `preferredColorScheme`. Also applied inside the settings sheet so it switches immediately.
- **Accent colour:** same colour picker as for lists (default: blue), implemented via `.tint()`. Applies to the simple ring, the "+", the navigation, toggles and buttons. Views use `.tint` instead of `Color.accentColor`.
- **Candidates for later:** defaults for new lists (colour, recurrence), notifications on/off globally, statistics, about the app.
- **Storage:** `AppSettings` (`@Observable`) in `RoutineKit`, stored in the App Group's `UserDefaults` (so the widget/Live Activity can read the ring style). From phase 6 optionally synced between devices via the iCloud key-value store.
- Settings do **not** belong in SwiftData: they are device-specific, small and need no history.

---

## 8. Notifications & Live Activity

### Trigger time
List with a start time: triggers **on the first day of each period at the start time** (daily every day; weekly on the weekday; monthly on the anchor day, etc.; for "none" once on the start day). The state is kept until the next period; there are no further triggers in between. (decided)

### Local notification (fallback & Mac/iPad)
- `UNUserNotificationCenter`, no push infrastructure needed.
- Daily/weekly with n = 1: repeating `UNCalendarNotificationTrigger`.
- Interval n > 1, monthly (because of clamping), yearly, no recurrence: schedule the next dates individually; iOS allows max. 64 pending notifications → reschedule on a rolling basis at every app launch.
- Tapping the notification opens the list.

### Live Activity (iOS)
- **Timing:** only built once the app is stable (phase 5). Design open until then.
- **Placeholder layout:** a box in the standard system style (Liquid Glass): emoji + list name at the top, below it the current to-do with a round toggle on the right. Checking off → the next to-do appears.
- **Scheduled start** via `Activity.request(…, start: Date)` (iOS 26+). The system starts it at the scheduled time, even if the app is in the background.
- The app schedules the **next** date per list on: app launch, return to the foreground, change of the list, end of an activity.
- If the app hasn't been opened for a long time, the notification serves as a fallback (both can be enabled in parallel).
- **Content:** list name, emoji, colour, progress (e.g. 2/6), **the next open to-do** with a check-off button.
- **Checking off:** the button triggers `CompleteTaskIntent` (`LiveActivityIntent`) → writes a `TaskRecord` to the shared store → updates the activity with the next open to-do.
- Additionally an "end" button (`EndActivityIntent`).
- **Ends:**
  1. when all to-dos are done (short "done" display, then `dismissalPolicy: .after(…)`),
  2. after 8 hours (also the system limit),
  3. when the list's period ends,
  4. when ended manually.
- **Technical note on 3.:** The app usually isn't running when the period changes. Solution: set `staleDate = periodEnd` (the activity shows "expired") and end it at the next app launch or the next intent. At the latest, the 8-hour limit applies.
- If the list is changed in the app while an activity is running, the activity is updated.
- Dynamic Island: compact = emoji + progress; expanded = next to-do + check-off button.
- With macOS 26, iPhone Live Activities also appear in the menu bar of a paired Mac.

---

## 9. Synchronisation (Phase 6)

- SwiftData with CloudKit (`cloudKitDatabase: .private(...)`), the user's private database.
- Local-first: the app works fully offline; sync runs in the background.
- Requirements: paid developer account, iCloud capability (CloudKit container), background mode "Remote notifications".
- Conflicts: hardly relevant thanks to the record model (records are only created/deleted). Duplicates are tolerated in queries, optionally cleaned up periodically.
- Optional addition: iCloud key-value store for small settings.

---

## 10. Implementation Phases

| Phase | Content | Result |
|---|---|---|
| 0 | Xcode project (multiplatform), `RoutineKit` package, widget extension, App Group | builds on all platforms |
| 1 | `RecurrenceEngine` + models + `RoutineStore` + unit tests | core logic verified |
| 2 | UI: home screen, list detail, settings, adding/deleting | app usable locally |
| 3 | Local notifications | reminder at the start time |
| 4 | Everyday testing, refine features, design revision via `Theme`, polish iPad/Mac | stable app |
| 5 | Live Activity (placeholder layout first, see 8), scheduled start, interactive checking off | core feature done = MVP |
| 6 | iCloud sync (paid account) | cross-device |
| 7 | Widgets, statistics, Siri/Shortcuts, SF Symbols | expansion |

---

## 11. Open Points / Assumptions (please confirm)

- [x] Monthly: the anchor day is kept after clamping (30 Jan → 28 Feb → 30 Mar) (decided)
- [x] Progress ring: only counts daily lists (decided)
- [x] Ring style: all three (D, E, F), selectable in the general settings (decided)
- [x] Lists in the ring: selection per style, maximum D unlimited / E 5 / F 3, numbers only from the selection (decided)
- [x] The start time triggers on the first day of each period (decided)
- [x] Lists without recurrence are possible (decided)
- [x] Interval n for days, weeks, months and years (decided)
- [x] App name "Routines", bundle ID `de.laurasiedenhans.Routines` (decided)
- [ ] Reordering (drag & drop) on the iPhone: may need an edit mode
- [ ] If the recurrence or start day of an existing list changes, old completed records may no longer match the new periods (currently accepted)

---

## 12. Testing

| Level | Where | How |
|---|---|---|
| Unit tests | `RoutineKit/Tests` (Swift Testing) | Scheme "RoutineKit", destination "My Mac", ⌘U. Fixed time zone Europe/Berlin. Covered: recurrence logic (month anchor, leap year, daylight saving time, intervals, period index, naming by majority), ring selection, visibility, emoji input. |
| Previews | every view | `previewEnvironment()` with in-memory sample data |
| Simulator with sample data | Scheme "Routines (Testdaten)" | Launch argument `-sampleData`: fresh in-memory database + separate settings on every launch, real data untouched |
| Developer section | Settings (debug only) | Time travel (+1 h, +1 day, 23:59, reset), add sample data, delete all data |

**Sample data set (`SampleData`)**, generated relative to the current date:

| List | Recurrence | Tests |
|---|---|---|
| ☀️ Morgenroutine | daily, 06:30, notification + Live Activity | partly done, one-off to-do "Paket abholen", history of the last 6 days |
| 🌙 Abendroutine | daily, 21:30 | nothing done, "Lesen" skipped today, "Tagebuch" deleted for all future (with history) |
| 🏃 Training | every 2 days, due today | ring with an n-days list |
| 🧘 Meditation | every 2 days, not due today | missing from the ring, nothing moves up |
| 💊 Vitamine | daily | 100 %, done section |
| 🧺 Haushalt | weekly, period started 2 days ago | not in the ring |
| 🪴 Pflanzen gießen | every 2 weeks, new period today | interval for weeks |
| 💳 Finanzen | monthly from 30 Jan | month anchor |
| 📊 Quartalsbericht | every 3 months | interval for months |
| 🦷 Zahnarzt | yearly from 29 Feb 2024 | leap year |
| 📦 Umzug | no recurrence | one-off list, deleting without confirmation |
| 🇪🇸 Spanischkurs | daily, starts in 5 days | "Startet am …", not checkable |

---

## 13. Conventions for AI Assistants

- Language in code: English (types, variables, comments). UI texts: German via String Catalog. Project docs: English.
- Swift 6, strict concurrency; SwiftUI + SwiftData + Observation (`@Observable`), no Combine where avoidable.
- No third-party dependencies without consultation.
- Logic belongs in `RoutineKit`, not in views. New logic always comes with unit tests (Swift Testing).
- Never violate the CloudKit rules from section 5.
- Calculate dates/times only via `RecurrenceEngine` and the injected time provider, never `Date()` directly in views.
- No hard-coded colours, spacing, radii or sizes in views – always via `Theme` (see 7.0).
- Every view gets a `#Preview` with an in-memory container and sample data.
- Update this file whenever the architecture or requirements change.

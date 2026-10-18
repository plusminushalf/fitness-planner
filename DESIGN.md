---
name: Fitness Planner
description: A personal in-gym logbook: Hevy's set-table language, rendered natively in SwiftUI.
colors:
  hevy-blue: "#1F6FEB"
  hevy-blue-dark: "#3D8BFF"
  done-green: "#34C759"
  done-row-wash: "#34C75929"
  record-gold: "#FF9500"
  warmup-orange: "#FF9500"
  drop-purple: "#AF52DE"
  failure-red: "#FF3B30"
  screen-grouped: "#F2F2F7"
  card-surface: "#FFFFFF"
  field-fill: "#7676801F"
  label-primary: "#000000"
  label-secondary: "#3C3C4399"
  hairline: "#3C3C434A"
typography:
  display:
    fontFamily: "SF Pro Display, -apple-system, system-ui"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: "41px"
  headline:
    fontFamily: "SF Pro Display, -apple-system, system-ui"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: "28px"
  title:
    fontFamily: "SF Pro Display, -apple-system, system-ui"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: "25px"
  exercise-name:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: "22px"
  set-figure:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: "22px"
    fontFeature: "tnum"
  body:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: "20px"
  stat-value:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: "20px"
    fontFeature: "tnum"
  caption:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: "16px"
  label:
    fontFamily: "SF Pro Text, -apple-system, system-ui"
    fontSize: "11px"
    fontWeight: 600
    lineHeight: "13px"
    letterSpacing: "0.6px"
rounded:
  cell: "6px"
  button: "10px"
  card: "12px"
  capsule: "9999px"
spacing:
  hair: "2px"
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.hevy-blue}"
    textColor: "{colors.card-surface}"
    typography: "{typography.exercise-name}"
    rounded: "{rounded.button}"
    padding: "0 16px"
    height: "48px"
  button-secondary:
    backgroundColor: "{colors.field-fill}"
    textColor: "{colors.label-primary}"
    typography: "{typography.stat-value}"
    rounded: "{rounded.button}"
    padding: "0 12px"
    height: "44px"
  card:
    backgroundColor: "{colors.card-surface}"
    rounded: "{rounded.card}"
    padding: "16px"
  set-cell:
    backgroundColor: "{colors.field-fill}"
    textColor: "{colors.label-primary}"
    typography: "{typography.set-figure}"
    rounded: "{rounded.cell}"
    height: "32px"
  set-cell-completed:
    textColor: "{colors.label-primary}"
    typography: "{typography.set-figure}"
    height: "32px"
  set-check:
    backgroundColor: "{colors.field-fill}"
    textColor: "{colors.label-secondary}"
    rounded: "{rounded.cell}"
    size: "32px"
  set-check-done:
    backgroundColor: "{colors.done-green}"
    textColor: "{colors.card-surface}"
    rounded: "{rounded.cell}"
    size: "32px"
  set-row-done:
    backgroundColor: "{colors.done-row-wash}"
    height: "44px"
  chip:
    backgroundColor: "{colors.field-fill}"
    textColor: "{colors.label-primary}"
    typography: "{typography.stat-value}"
    rounded: "{rounded.capsule}"
    padding: "0 14px"
    height: "34px"
  chip-selected:
    backgroundColor: "{colors.hevy-blue}"
    textColor: "{colors.card-surface}"
    rounded: "{rounded.capsule}"
  day-pill:
    textColor: "{colors.label-primary}"
    rounded: "{rounded.card}"
    width: "46px"
    height: "64px"
  day-pill-selected:
    backgroundColor: "{colors.hevy-blue}"
    textColor: "{colors.card-surface}"
    rounded: "{rounded.card}"
---

# Design System: Fitness Planner

## Overview

**Creative North Star: "The Ledger, Not the Wizard"**

Fitness Planner speaks Hevy's language with native iOS grammar. Every set of every exercise lives in one scrolling table, read at a glance between sets with a thumb and a short look. Grouped system backgrounds, rounded white cards on the home and history screens, and a flat, edge-to-edge set table during the workout itself. Density comes from columns and hairlines, not from boxes.

Colour is restrained: neutrals from the iOS system palette plus one Hevy-blue tint for everything interactive. The only other hues mean set state: green for done, orange for warm-up and records, purple for drop sets, red for failure. Type is SF Pro at Dynamic Type sizes, with tabular figures anywhere a number is compared against another number. Imagery is limited to YouTube thumbnails a plan provides; otherwise exercises are shown as initials.

**Key Characteristics:**
- One tint (Hevy blue) for every tappable thing, including exercise names.
- The set table: SET · PREVIOUS · KG · REPS · ✓, tracked uppercase caption headers, hairline separators, completed rows washed green.
- Tabular (monospaced) digits on every figure.
- 32pt visual controls inside 44pt hit frames.
- SF Pro and SF Symbols only; system materials and grouped backgrounds.
- Light and dark appearance both supported through system colours plus the two-value tint asset.

## Colors

A neutral iOS grouped palette carrying a single blue tint, with four state hues that mean something.

### Primary
- **Hevy Blue** (light `hevy-blue`, dark `hevy-blue-dark`; the `AccentColor` asset, applied app-wide as `.tint`): primary button fills, exercise names, navigation and toolbar actions, today/selected day pills, rest-timer progress, chart marks, the "In progress" badge (at 14% opacity fill). Deepened from Hevy's #2B7FFF so white labels clear 4.5:1 in light mode.

### Secondary (state hues)
- **Done Green** (system green): the completed ✓ cell fill, done badges, the completed indicator on day pills, the timed-set countdown bar. Its row form is the **Done Row Wash** (green at 16% opacity), the full-bleed background of a completed set row.
- **Record Gold** (system orange): personal-record trophies, record stat values, and the finish-screen seal when a PR was hit.
- **Set-type letters**: Warm-up Orange (W), Drop Purple (D), Failure Red (F), all system colours. Normal sets show their number in the primary label colour.

### Neutral
- **Screen Grouped** (`systemGroupedBackground`): the screen canvas behind cards.
- **Card Surface** (`secondarySystemGroupedBackground`): cards; white in light mode.
- **Field Fill** (`tertiarySystemFill`): input cells, unchecked ✓ cells, secondary buttons, unselected chips, avatar backgrounds, the alternating rows of the history set list (at 50%).
- **Label / Secondary Label**: system label colours; secondary carries PREVIOUS values, captions, column headers, stat labels.
- **Hairline** (`separator`): the rules between set rows.

### Named Rules
**The One Tint Rule.** Hevy Blue is the only interactive colour. If it is tappable and not a state, it is blue; if it is blue, it is tappable or it marks today/selection.

**The State-Only Hues Rule.** Green, orange, purple and red never decorate. Each one names a set state (done, warm-up/record, drop, failure) and appears only where that state is true.

## Typography

**Display Font:** SF Pro (system), via Dynamic Type text styles
**Body Font:** SF Pro (system)
**Label/Mono Font:** SF Pro with `monospacedDigit()`; no separate mono family.

**Character:** Pure system type, weighted for glanceability: bold titles, semibold figures, regular secondary text. The voice comes from tabular numbers and tracked uppercase column heads, not from a typeface.

### Hierarchy
- **Display** (`largeTitle`, bold): navigation large titles ("Workout", "History", "Exercises") and the finish-screen headline.
- **Headline** (`title2`, bold): screen-level section heads such as "Routines", workout detail titles, the countdown clock (tabular).
- **Title** (`title3`, bold): session card titles, day-pill dates and summary figures (tabular).
- **Exercise Name** (`headline`, semibold): exercise names, always in Hevy Blue; also primary-button labels.
- **Set Figure** (`body`, semibold, tabular): kg, reps and time values in the set table.
- **Body** (`subheadline`): notes, list rows, PREVIOUS values (tabular, secondary colour).
- **Stat Value** (`subheadline`, semibold, tabular) over a **Caption** (`caption`, secondary) label: the StatPair ("Duration / 20:53").
- **Label** (`caption2`, semibold, 0.6pt tracking, uppercase, secondary): set-table column headers and list section labels (WARMUP / EXERCISES / COOLDOWN, RECENT / ALL EXERCISES).

### Named Rules
**The Tabular Figures Rule.** Every number that can be compared to another (weights, reps, clocks, volumes, dates in the strip) uses monospaced digits so columns hold still as values change.

**The Dynamic Type Rule.** Use text styles, not fixed point sizes. Sizes in the frontmatter are the default (Large) content size; the app scales with the user's setting.

## Layout

Native stacks and lists on a grouped canvas. Home and History are scrolling stacks of cards with 16pt horizontal margins; the active workout is a plain list whose set rows run full-bleed (12pt leading / 8pt trailing inset) with no card around them. Spacing steps in the build are 2, 4, 8, 12, 16 and 24pt; 12pt is the default stack gap, 2pt binds a label to its value.

Set-table columns are fixed widths shared by header and rows so everything lines up: SET 36pt, PREVIOUS flexible, KG 70pt, REPS 58pt (or TIME 84pt + 44pt timer), ✓ 44pt, with 8pt gutters. Rows have a 44pt minimum height. The rest/countdown bar pins to the bottom in the system bar material. The tab bar (Workout, History, Exercises) hides during an active workout.

**The Ledger Rule.** Sets are rows in a table separated by hairlines, never cards. One exercise is a header, its notes and rest row, the column header, its set rows, and an Add Set button, in one continuous list.

## Elevation & Depth

Flat by default. Depth comes from tonal layering: white cards on the grey grouped canvas, grey field fills on white. Shadows appear only on transient floating chrome over content: the toast capsule (`regularMaterial`, black 12%, radius 8, y 3) and the processing overlay panel (black 15%, radius 12, y 4). Bottom bars use the system bar material.

**The Flat Ledger Rule.** Cards, rows, buttons and cells carry no shadow; only something that floats temporarily above the content may.

## Shapes

Continuous (squircle) rounded rectangles throughout. Four radii: 6pt for set cells and the ✓ cell, 10pt for full-width buttons and the embedded video, 12pt for cards and day pills, capsule for chips, badges and toasts. Avatars are circles. Today's unselected day pill is outlined with a 1.5pt Hevy Blue stroke; otherwise there are no borders.

**The 44 Rule.** Visual controls may be smaller than 44pt (32pt cells, 34pt chips) but their hit frame never is.

## Components

### Buttons
Full-width, quiet, one primary per screen.
- **Shape:** gently rounded continuous rectangle (`rounded.button`).
- **Primary:** Hevy Blue fill, white headline label, 48pt minimum height. Pressed: 80% opacity. Disabled: 40% opacity. Used for Start/Resume Workout and Skip/Done in the countdown bar.
- **Secondary:** Field Fill, subheadline semibold label in primary colour (or tint, as in "Start Empty Workout"), 44pt minimum height. Pressed: fill at 60%. Used for Add Set, ±15s, Start Empty Workout.
- **Toolbar / inline:** plain tint-coloured text or SF Symbol actions ("New Routine"). The nav-bar Finish is a small system bordered-prominent tint button (8pt radius, subheadline bold).

### Chips
- **Style:** capsule, subheadline semibold, 34pt visual inside a 44pt hit frame. Unselected: Field Fill with primary label. Selected: Hevy Blue with white label. Used for the Exercises muscle filter.
- **Status badge:** capsule, caption semibold, tint or done green at 14% fill with matching text ("In progress", "Done").

### Cards / Containers
- **Corner Style:** `rounded.card`, continuous.
- **Background:** Card Surface on Screen Grouped.
- **Shadow Strategy:** none (see Elevation).
- **Border:** none.
- **Internal Padding:** 16pt.
- Never nest cards. Cards hold sessions, routines, history entries, progress charts and summary blocks, never individual sets.

### Inputs / Fields
- **Set cell:** a 32pt Field Fill pill (`rounded.cell`) inside a 44pt hit frame, centered semibold tabular figure, decimal or number pad. The placeholder shows the value ✓ would log (previous, else target) at 60% primary so it stays legible. When the set is completed the fill clears and the figure sits on the green row wash.
- **Time cell:** same pill at 84pt, opens the duration editor.
- **Forms** (routine editor, add exercise): native `Form` with system fields.

### Navigation
- Tab bar with three tabs (Workout, History, Exercises), SF Symbols, tint for the selected tab.
- Large titles on root screens; inline titles with a tint back button on pushed screens.
- **Date strip:** horizontally scrolling day pills (46 × 64pt, `rounded.card`): caption2 weekday over a title3 bold tabular date over an 8pt indicator row (tint dot = planned, green check = completed). Selected: tint fill, white text. Today: tint stroke and tint date.

### Set Table (signature)
The heart of the app. Header row of tracked uppercase captions (SET · PREVIOUS · KG · REPS · ✓). Each row: set label (number, or W/D/F in its type colour; tap for a menu to change type or delete), PREVIOUS in secondary tabular text (tap to copy into the row), kg and reps cells, and a 32pt ✓ cell that turns Done Green with a white check, washes the full row green, fires a light impact haptic and starts the rest timer. Rows are separated by full-width hairlines and swipe to delete.

### Stat Pair
A caption label in secondary over a semibold tabular value, laid out three across (Duration / Volume / Sets). The value may take the tint (live duration) or Record Gold (record counts).

### Exercise Avatar
A circle (40pt, 44pt in the workout header) showing the plan's YouTube thumbnail, or bold rounded initials on Field Fill. A small tint play badge marks a playable form video. Never shows invented exercise imagery.

### Countdown Bar
Pinned to the bottom in bar material: a tint (rest) or green (timed set) linear progress bar, then −15s / clock / +15s / Skip. The clock is title2 bold tabular with a counting-down numeric transition.

### Toast
A top-anchored capsule in regular material with a subheadline semibold message, slides in from the top, auto-dismisses after 2.2s.

## Do's and Don'ts

### Do:
- **Do** use Hevy Blue for every interactive element and every exercise name, and nothing else outside selection/today.
- **Do** put sets in hairline-separated full-bleed rows with fixed shared column widths (SET 36, KG 70, REPS 58, ✓ 44, 8pt gutters).
- **Do** use monospaced digits for every weight, rep count, clock and volume.
- **Do** draw 32pt cells inside 44pt hit frames, and keep 44pt minimum row heights.
- **Do** show the previous performance on the set row itself, in secondary tabular text.
- **Do** use system colours, grouped backgrounds and Dynamic Type text styles so light and dark mode follow the system.
- **Do** use continuous corners at the four radii (6, 10, 12, capsule).

### Don't:
- **Don't** wrap individual sets or set tables in cards, and never nest cards.
- **Don't** use green, orange, purple or red for decoration; they mean done, warm-up/record, drop and failure.
- **Don't** introduce a second tint or a gradient fill.
- **Don't** use custom fonts or non-SF icon sets.
- **Don't** put shadows on cards, rows or buttons; shadows belong only to transient floating chrome (toast, overlay).
- **Don't** show exercise imagery or muscle diagrams the app doesn't ship; fall back to initials.

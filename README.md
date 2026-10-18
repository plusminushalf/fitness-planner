# Fitness Planner

A tiny iOS app that turns a CSV of weekly workouts into an in-gym companion: open it on lift day, see today's session, watch a YouTube form-check, log weight + reps per set, then export the week's data as CSV at the end.

Personal-use, sideload-friendly. No accounts, no servers, no third-party SDKs.

## Build & run

Prereqs: macOS, Xcode 17+, [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open FitnessPlanner.xcodeproj
```

Then in Xcode:
- Pick a destination (your phone, or an iOS Simulator if a matching runtime is installed).
- Cmd+R to run.

The first time you sideload to a real device with a free Apple ID, Xcode will set up signing automatically. The signing cert expires after 7 days — to skip the manual re-sign, look at [AltStore](https://altstore.io) or [SideStore](https://sidestore.io).

## CSV import format

UTF-8, comma-separated, one row per exercise. Header row required.

| column             | required          | notes                                                                 |
|--------------------|-------------------|-----------------------------------------------------------------------|
| `date`             | yes               | `yyyy-MM-dd`. Rows with the same value group into one day.            |
| `exercise`         | yes               | Display name.                                                         |
| `sets`             | weight-based rows | Positive integer.                                                     |
| `target_reps`      | weight-based rows | Free text — `8-10`, `5`, `AMRAP`, etc.                                |
| `target_weight`    | no                | Number in kg. Leave blank for bodyweight or rep-only exercises.       |
| `duration_seconds` | time-based rows   | Positive integer. Flips the row to time-based (warmups, holds, stretches). When set, `sets`/`target_reps`/`target_weight` must be blank. |
| `rest_seconds`     | no                | Positive integer. Countdown shown after each set / after the exercise.|
| `video_url`        | no                | YouTube link (`youtu.be/…`, `youtube.com/watch?v=…`, `/shorts/…`, `/embed/…`). |
| `notes`            | no                | Free text. Quote with `"…"` if it contains commas.                    |

Lines starting with `#` are directives: `# warmup`, `# exercises` (or `# workout` / `# main`), and `# cooldown` set the section for the rows that follow (persists across day boundaries until the next header). Any other `#` line is a comment and ignored.

Importing a CSV **replaces the previously imported plan** — including any logged sets. Export first if you care about that data.

A working example lives at [`sample-plans/sample-week.csv`](sample-plans/sample-week.csv). For the full authoring spec (row-shape rules, accepted YouTube URL shapes, quoting, common mistakes), see [`docs/CSV_FORMAT.md`](docs/CSV_FORMAT.md).

## Using the app

Three tabs, laid out after [Hevy](https://www.hevy.com):

- **Workout.** A date strip across the plan's span (top-left menu jumps months). The selected day's session is a card listing its exercises with **Start / Resume / View Workout**. Days with nothing planned offer **Start Empty Workout**. Below that are your **Routines**: build one, or save any workout as one, then **Start Routine** on the selected day.
- **History.** A 12-week chart (volume, sets, workouts or time) with your weekly streak, then every logged workout with its time, volume, sets, PRs and best set per exercise. Tap a workout for the full breakdown, to edit it, or to save it as a routine.
- **Exercises.** Everything you've logged plus a built-in library, filterable by muscle group. Each exercise has a progress chart (heaviest weight, estimated 1RM, best set volume, session volume), personal records, its form video and full history.

### Logging a set

The live workout is one scrolling table per exercise: `SET · PREVIOUS · KG · REPS · ✓`.

- **PREVIOUS** shows what you did last time for that set. The kg/reps fields use it (or the plan's target) as their placeholder; tap ✓ on an untouched row to log exactly that, or tap PREVIOUS to copy it in.
- Ticking ✓ turns the row green and starts the exercise's rest timer in the bottom bar (−15s / +15s / Skip). It keeps counting with the phone locked and sends a notification when rest is over.
- Tap the set number to mark it as a warm-up (W), drop set (D) or failure set (F), or to delete it. Swipe left also deletes. Warm-ups don't count toward records.
- Timed exercises (holds, mobility) have a ▶︎ countdown per set; stopping early records the time you actually held. Tap the time to edit it.
- Beating a previous best shows a record toast. **Finish** freezes the duration and shows a summary with any PRs.
- The ⋯ menu on an exercise opens its history, shows the form video, reorders it, or removes it. **+ Add Exercise** picks from the library or creates a custom one.

## CSV export

When at least one set in the current plan is marked complete, the ⋯ menu on the Workout tab offers **Copy progress** and **Share progress CSV…**. It produces a file named `fitness-export-<YYYY-MM-DD>.csv` with one row per completed set:

```
date,section,exercise,set_number,target_reps,target_weight,duration_seconds,rest_seconds,actual_weight,actual_reps,actual_duration_seconds,notes
```

Share to Files / iCloud / mail / wherever. Imports and analysis happen elsewhere (spreadsheet, LLM, etc.) — the app's job ends at export.

## What's not in here (deliberately)

- RPE field
- iCloud sync, accounts, social feed
- Settings (unit toggle, etc.): kg only
- App Store distribution

All easy to add later if the use case justifies it. Today this is the smallest thing that's useful.

## Simulator demo data (debug builds)

On an empty store, launch with `-seedDemo YES` to load the sample week starting today plus six weeks of synthetic completed sessions and one routine. `-demoTab 1|2` opens History or Exercises; `-demoOpenToday YES` opens today's workout with a couple of sets logged. None of this is compiled into release builds.

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
| `video_url`        | no                | YouTube link (`youtu.be/…`, `youtube.com/watch?v=…`, `/shorts/…`, `/embed/…`). |
| `notes`            | no                | Free text. Quote with `"…"` if it contains commas.                    |

Lines starting with `#` are directives: `# warmup`, `# exercises` (or `# workout` / `# main`), and `# cooldown` set the section for the rows that follow (persists across day boundaries until the next header). Any other `#` line is a comment and ignored.

Importing a CSV **replaces the previously imported plan** — including any logged sets. Export first if you care about that data.

A working example lives at [`sample-plans/sample-week.csv`](sample-plans/sample-week.csv). For the full authoring spec (row-shape rules, accepted YouTube URL shapes, quoting, common mistakes), see [`docs/CSV_FORMAT.md`](docs/CSV_FORMAT.md).

## Logging a session

- The app opens to the day whose name matches the current weekday. Use the day picker (top-left) to override.
- Tap an exercise to see the embedded video (if any) and a row per planned set.
- Type weight and reps into each row. The checkmark button marks the set as completed (this is what export uses to decide what to include).
- `+ Add set` appends extras beyond the plan if you go off-script.

## CSV export

When at least one set is marked complete, an export button appears top-right. It produces a file named `fitness-export-<YYYY-MM-DD>.csv` with one row per completed set:

```
day,date,exercise,set_number,target_reps,target_weight,actual_weight,actual_reps,notes
```

Share to Files / iCloud / mail / wherever. Imports and analysis happen elsewhere (spreadsheet, LLM, etc.) — the app's job ends at export.

## What's not in here (deliberately)

- RPE field
- Multiple stored plans / history
- iCloud sync
- Settings (unit toggle, etc.)
- App Store distribution

All easy to add later if the use case justifies it. Today this is the smallest thing that's useful.

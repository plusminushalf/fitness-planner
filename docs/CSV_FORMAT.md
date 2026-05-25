# Fitness Planner — CSV authoring guide

This document is the source of truth for hand-writing (or AI-generating) a workout-plan CSV that the Fitness Planner iOS app can import. It reflects the **actual importer behavior** (`FitnessPlanner/CSV/CSVImporter.swift` and `CSVParser.swift`), not the brief table in the top-level README.

If anything here disagrees with the README, this file wins.

---

## 1. Lifecycle

1. You author a CSV that lays out one or more days of workouts (typically one week).
2. The user opens the app and imports the file. **Importing replaces the previously imported plan, including any logged sets** — there is no merge.
3. During the week the user logs weight/reps per set against the plan inside the app.
4. The app exports a *different* CSV (one row per completed set) for analysis elsewhere. That export format is **not** what this document is about — do not try to author one of those.

---

## 2. File requirements

- **Encoding:** UTF-8. A leading BOM is tolerated but not required.
- **Delimiter:** comma. There is no option to change this.
- **Line endings:** `\n` or `\r\n` both work.
- **Header row:** required. Column names are matched case-insensitively after trimming whitespace.
- **At least one data row.** A file with only a header (or only comments) is rejected with "CSV contained no exercises."
- **No file-size limit** in practice — a normal week is ~30–60 data rows.

---

## 3. Columns

Put these on the header row, in any order. Lowercase is conventional; the parser lowercases the header anyway.

| column             | required?                    | type / format             | meaning                                                                 |
|--------------------|------------------------------|---------------------------|-------------------------------------------------------------------------|
| `date`             | **yes**                      | `yyyy-MM-dd` (UTC parsed) | Groups rows into a day. Same date string = same day.                    |
| `exercise`         | **yes**                      | non-empty string          | Display name shown in the app.                                          |
| `sets`             | yes for weight-based rows    | positive integer          | Number of working sets. Omit for time-based rows (see §4).              |
| `target_reps`      | yes for weight-based rows    | free text                 | `8-10`, `5`, `AMRAP`, `5+`, etc. Stored verbatim.                       |
| `target_weight`    | optional                     | number, kilograms         | Leave blank for bodyweight / rep-only work. Decimals allowed (`22.5`).  |
| `duration_seconds` | yes for time-based rows      | positive integer          | Presence of any value flips the row to time-based (see §4).             |
| `rest_seconds`     | optional                     | positive integer          | Break shown as a countdown after each set and after the exercise.       |
| `video_url`        | optional                     | YouTube URL               | Must be parseable as a YouTube link (see §7). Whole import fails if not.|
| `notes`            | optional                     | free text                 | Quote with `"…"` if it contains a comma or a double-quote.              |

Only `date` and `exercise` are checked as "required columns" at the header level. The other constraints kick in per-row based on which shape (§4) the row uses.

---

## 4. Row shapes — weight-based vs time-based

Every data row is one of two shapes. **The importer rejects mixing the two.**

### Weight-based (default — strength work)

Used for any exercise where the user logs sets × reps.

- `sets` — required, positive integer.
- `target_reps` — required, free text.
- `target_weight` — optional. Blank = bodyweight or rep-only.
- `duration_seconds` — **must be blank.**

Example rows (header omitted for brevity):

```
2026-05-25,Bench Press,4,6-8,80,,120,https://www.youtube.com/watch?v=dQw4w9WgXcQ,Pause briefly at chest
2026-05-26,Pull-up,4,5-8,,,120,https://youtu.be/dQw4w9WgXcQ,Bodyweight — add weight when all sets hit 8
```

### Time-based (warmups, cooldowns, holds, mobility)

Used for anything timed rather than counted. The importer creates a single set initialized to the planned duration.

- `duration_seconds` — required, positive integer.
- `sets`, `target_reps`, `target_weight` — **all three must be blank.** If any are populated the row is rejected with "time-based exercise must leave sets/target_reps/target_weight empty".

Example rows:

```
2026-05-25,Arm Circles,,,,45,15,https://www.youtube.com/watch?v=dQw4w9WgXcQ,Each direction
2026-05-25,Child's Pose,,,,90,,https://youtu.be/dQw4w9WgXcQ,
```

### Cheat-sheet: which columns are populated

| shape         | sets | target_reps | target_weight | duration_seconds | rest_seconds |
|---------------|:----:|:-----------:|:-------------:|:----------------:|:------------:|
| weight-based  |  ✅  |     ✅      |   optional    |       blank      |   optional   |
| time-based    | blank|    blank    |     blank     |        ✅        |   optional   |

### Rest between sets and exercises

`rest_seconds` is the break to take after each completed set and after the exercise itself. When set, the app shows a fullscreen countdown when the user taps **Add set** or **Complete & Next** and auto-advances when it reaches zero (user can skip). Leave blank for no rest.

---

## 5. Section headers (`# warmup` / `# exercises` / `# cooldown`)

The parser treats any line whose first non-whitespace character is `#` as a directive line, not a data row.

**Recognized section headers** (case-insensitive, hyphens and spaces accepted):

| line                | section set      |
|---------------------|------------------|
| `# warmup`          | warmup           |
| `# warm-up`         | warmup           |
| `# warm up`         | warmup           |
| `# exercise`        | exercise (main)  |
| `# exercises`       | exercise (main)  |
| `# workout`         | exercise (main)  |
| `# main`            | exercise (main)  |
| `# cooldown`        | cooldown         |
| `# cool-down`       | cooldown         |
| `# cool down`       | cooldown         |

Anything else starting with `#` (e.g. `# notes from coach`) is treated as a **comment and silently dropped** — useful for in-file annotations.

Rules:

- The current section **persists until the next section header**, even across day boundaries — so put a `# warmup` at the top of every day's block.
- The default section before any header is `exercise` (main).
- Section is purely a UI grouping in the app. It does not change the row-shape rules — a weight-based row in a `# warmup` block is still a weight-based row and must populate `sets`/`target_reps`.

**Recommended layout per day:** `# warmup` → time-based mobility → `# exercises` → weight-based lifts → `# cooldown` → time-based stretches.

---

## 6. Day grouping & ordering

- Two rows with the same `date` string land in the same day. There is no separate "day name" — the date is the identity.
- Within a day, exercises appear in the **order the rows appear in the file**. There is no `orderIndex` column to set; just write rows in the order you want them displayed.
- Days do not need to be contiguous or sorted in the file, but writing them in chronological order is conventional and makes the file easy to review.

The app picks "today" by matching the device's current weekday name (`EEE`) against day display names, but the actual storage key is the `date` value.

---

## 7. Video URLs

If `video_url` is non-empty, it **must** parse to a YouTube video ID, or the entire import fails with "video_url is not a recognizable YouTube link" pointing at that row. Leaving the column blank is fine.

Accepted shapes (and one example each — all of these resolve to video ID `dQw4w9WgXcQ`):

| shape                                        | example                                                   |
|----------------------------------------------|-----------------------------------------------------------|
| `youtu.be/{id}`                              | `https://youtu.be/dQw4w9WgXcQ`                            |
| `youtube.com/watch?v={id}`                   | `https://www.youtube.com/watch?v=dQw4w9WgXcQ`             |
| `youtube.com/embed/{id}`                     | `https://www.youtube.com/embed/dQw4w9WgXcQ`               |
| `youtube.com/shorts/{id}`                    | `https://www.youtube.com/shorts/dQw4w9WgXcQ`              |
| `youtube.com/v/{id}`                         | `https://www.youtube.com/v/dQw4w9WgXcQ`                   |
| `www.` / `m.` subdomains, `youtube-nocookie` | `https://m.youtube.com/watch?v=dQw4w9WgXcQ`               |

Extra query params (`?t=30`, `&list=…`, etc.) on `watch?v=` URLs are fine — they're ignored. Non-YouTube hosts (Vimeo, Instagram, raw `.mp4` links) are rejected; don't use them.

---

## 8. Quoting & escaping

Standard CSV rules:

- A field that contains a comma, a double-quote, or a newline **must** be wrapped in double-quotes.
- Inside a quoted field, escape `"` by doubling it: `She said ""hi""`.
- Don't quote things that don't need quoting — it's not wrong, just noisy.

In practice the only column that regularly needs quoting is `notes`:

```
2026-05-27,Romanian Deadlift,3,8-10,90,,120,https://youtu.be/dQw4w9WgXcQ,"Pause at bottom, controlled"
```

---

## 9. Common authoring mistakes

- **Wrong date format.** `05/25/2026`, `2026/05/25`, `25-05-2026`, and `Monday` are all rejected. Use `yyyy-MM-dd`.
- **Free-text day names.** This format has no `day` column. Use the date itself; the app renders the weekday.
- **Mixing shapes.** Putting `45` in `duration_seconds` *and* `3` in `sets` on the same row → import error. Pick one.
- **Forgetting `sets` or `target_reps` on a weight row.** Both are required when `duration_seconds` is blank.
- **Non-YouTube video links.** Vimeo, raw video files, Instagram reels — none of these import. Either use a YouTube link or leave `video_url` blank.
- **Unquoted commas in notes.** `Pause at bottom, controlled` without quotes will silently split into two fields and shift all later columns. Quote it.
- **Stale section header.** If you write `# warmup` and then forget to write `# exercises` before the heavy lifts, every lift below ends up in the warmup section in the app. Always reset the section explicitly per block.
- **Reusing a date you didn't mean to.** Two `# exercises` blocks under the same date will merge into one day. Usually fine — but a copy-paste mistake here is easy to miss.

---

## 10. Minimal full example

Single day, exercising every feature this guide covers. Save as `monday.csv` (or anything), import via the app.

```csv
date,exercise,sets,target_reps,target_weight,duration_seconds,rest_seconds,video_url,notes
# warmup
2026-05-25,Arm Circles,,,,45,15,https://www.youtube.com/watch?v=dQw4w9WgXcQ,Each direction
2026-05-25,Shoulder Dislocates,,,,60,30,https://youtu.be/dQw4w9WgXcQ,Band or PVC
# exercises
2026-05-25,Bench Press,4,6-8,80,,120,https://www.youtube.com/watch?v=dQw4w9WgXcQ,"Pause at chest, controlled"
2026-05-25,Pull-up,4,5-8,,,120,https://youtu.be/dQw4w9WgXcQ,Bodyweight; add load when all sets hit 8
# cooldown
2026-05-25,Child's Pose,,,,90,,https://youtu.be/dQw4w9WgXcQ,
```

What this demonstrates: header row, all three section headers, a time-based warmup with `duration_seconds`, a weight-based lift with notes containing a comma (quoted), a bodyweight lift with `target_weight` left blank, and a time-based cooldown.

---

## 11. Canonical sample

A full working week lives at [`sample-plans/sample-week.csv`](../sample-plans/sample-week.csv). Mirror its style when in doubt.

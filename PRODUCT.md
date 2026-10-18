# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
One person: the developer, lifting in a gym with a phone in hand between sets. Sideloaded, personal use. No onboarding, no accounts, kg only.

## Product Purpose
An in-gym companion that turns a written training plan into a fast logging surface. Open it on lift day, see today's session, check form on a video, log every set, and look back at how lifts are progressing. Success means logging never slows a session down and progress is legible at a glance.

## Positioning
Plans arrive as CSV, authored elsewhere (on a Mac, often by an LLM), scheduled by date. The app is the execution and record layer for that plan, not a social network or a plan generator. Hevy is the reference for logging ergonomics and progress views; the CSV-scheduled plan is what Hevy does not do.

## Operating Context
- Used mid-workout: sweaty hands, short glances, one thumb, between sets with rest timers running.
- Plans are pasted from the clipboard or imported as a file; pasting merges by date, file import replaces.
- Progress leaves the app as CSV (copy or share) for analysis in a spreadsheet or LLM.
- Exercises can carry a YouTube form-check video, notes, rest seconds, and a section (warmup / exercises / cooldown).
- Exercises are either weight × reps or time-based (holds, mobility, stretches with a countdown).

## Capabilities and Constraints
- SwiftUI + SwiftData, iOS 17+, built with xcodegen. No third-party SDKs, no servers.
- CSV import/export stays the primary plan source; its format is specified in docs/CSV_FORMAT.md and must keep working.
- Rewrite scope (confirmed 2026-10-18):
  - Hevy-style set table replaces the stepped weight→reps flow: every set visible, previous-session values, inline kg/reps, per-set ✓, set types (warmup / drop / failure), rest timer that starts on ✓. Timed exercises keep their countdown.
  - History & progress: past workouts, per-exercise charts (best set, estimated 1RM, volume), personal records, weekly summary.
  - Routines & free workouts: start an empty workout any day, save a workout as a reusable routine, exercise library with muscle groups.
- Out of scope: social feed, accounts, sync, lb units, onboarding, App Store distribution.
- Schema changes must be additive so existing logged sets survive (the app drops the store on migration failure).

## Brand Commitments
- Name: Fitness Planner.
- Explicit reference from the user: Hevy (hevy.com, iOS app) for both features and design.

## Evidence on Hand
- sample-plans/sample-week.csv: a real weekly plan.
- No exercise images or muscle diagrams ship with the app; don't invent them. YouTube thumbnails exist only where a plan provides a video_url.

## Product Principles
1. Logging speed beats everything: the fewest taps from rest to the next set.
2. The plan is authored outside; the app executes it faithfully and never loses logged data.
3. Show the previous performance where the decision is made (on the set row), not on another screen.
4. Progress should be visible without exporting.

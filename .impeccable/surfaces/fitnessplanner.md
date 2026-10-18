---
version: 1
slug: "fitnessplanner"
primary_target: "FitnessPlanner"
related_targets: []
---

## Scope
Whole app redesign (native iOS, SwiftUI). Mode: Operate. Surfaces: Workout tab (date strip, scheduled session, quick start, routines), Active workout (set table), History tab, Exercises tab (library + per-exercise progress), routine editor, finish summary.

## Audience & job
One lifter, mid-session, phone in one hand. Job: log each set in two taps, see last time's numbers on the row, see progress without exporting.

## Direction contract
THESIS: The workout is a ledger, not a wizard. Every set of every exercise sits in one scrolling table you can read at a glance, the way Hevy does; it refuses the current one-number-at-a-time stepped flow and the card-stack "fitness app" home screen.
OWN-WORLD: Hevy's language, rendered natively. Grouped system backgrounds, one Hevy-blue tint (#1F6FEB light, deepened from Hevy's #2B7FFF so white button labels clear 4.5:1 / #3D8BFF dark), exercise names in tint, set tables with tracked uppercase caption headers (SET · PREVIOUS · KG · REPS · ✓), monospaced figures, completed rows washed green, set-type letters coloured (W orange, D purple, F red). SF Pro and SF Symbols only. Restrained colour strategy: neutrals plus tint, with green/orange/purple/red reserved for set state.
STORY: Open the app and today's planned session is already there with its exercises listed. One tap starts it. Each row shows the previous numbers; tap ✓ and the rest timer starts at the bottom. Finishing shows volume, duration and any PRs. History and Exercises show how lifts are trending.
FIRST VIEWPORT: Large title "Workout". Date strip of day pills directly under it. Below, the selected day's session card: weekday title, plan name, exercise list (sets × name), full-width tint "Start Workout" button. Under that, a "Start Empty Workout" row and the "Routines" header with New Routine.
FORM: Pinned by the user (Hevy, the brief's own reference), which beats the roll. Raise from the declined Japanese high-density challenger: the set table packs columns edge to edge with hairline rhythm instead of padded cards. Seed key 7f99fa82.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Unresolved
None blocking. No image generation available: code-led build.

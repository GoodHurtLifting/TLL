# App Flow

## Purpose

Defines the intended navigation and state flow of the app.

This file exists to prevent:

- screen responsibility overlap
- temporary test routing from becoming permanent
- navigation logic drifting into the wrong screen
- Codex changing flow without understanding the intended user path

---

## Core Rule

App flow should be:

- predictable
- local-first
- driven by app state
- thin at the widget level

Widgets should navigate.
Services should determine data/state.

---

## Launch Flow

### Entry

App starts in:

`main.dart`

Responsibilities:

- initialize Flutter bindings
- open local database
- run seed logic
- launch `TllApp`

`main.dart` should not:

- create block instances directly
- route directly to workouts
- contain feature-specific logic

---

## App Shell Flow

### Screen

`AppShell`

Responsibilities:

- call app launch logic
- get or create the current starter block instance
- show loading state
- show launch error state
- hand off to `BlockDashboardScreen`

`AppShell` should not:

- load workout data
- calculate totals
- contain summary logic
- contain badge logic

---

## Dashboard Flow

### Screen

`BlockDashboardScreen`

Responsibilities:

- load block dashboard data for one `blockInstanceId`
- display:
    - block title
    - run number
    - block totals
    - workout list
- open selected workout
- refresh when returning from a workout

`BlockDashboardScreen` should not:

- generate block instances
- calculate workout totals in UI
- contain summary logic
- evaluate badges

---

## Workout Flow

### Screen

`WorkoutLogScreen`

Responsibilities:

- load one workout instance
- display ordered lifts
- allow reps/weight entry
- save set data
- show lift totals
- show workout totals
- finish workout
- show workout-end badge popups
- continue navigation after finish

`WorkoutLogScreen` should not:

- calculate scoring in widgets
- own badge evaluation logic
- own block summary logic
- query unrelated block/dashboard data

---

## Finish Workout Flow

### Trigger

User taps:

`Finish Workout`

### Expected sequence

1. ensure workout is started
2. finish workout
3. evaluate post-finish badge popup conditions
4. show earned badge popup(s), if any
5. determine whether block is complete
6. navigate:
    - if block complete -> `BlockSummaryScreen`
    - else -> return to dashboard

### Notes

Workout-end popups happen before final navigation.

Current popup flow:
- Lunch Lady
- Meat Wagon

If both exist, they are shown sequentially.

---

## Summary Flow

### Screen

`BlockSummaryScreen`

Responsibilities:

- load block summary data
- display:
    - block identity
    - overview
    - plan adherence
    - improvements
    - milestones / badges
    - workout details

`BlockSummaryScreen` should not:

- evaluate badges
- calculate scoring in UI
- mutate workout/block state

It is read-only.

---

## Badge Flow

### Trigger Types

Badges may be awarded from:

- set logging
- workout completion
- block progress
- future social events

### Current display locations

- workout-end popup
- block summary

### Rule

Badge evaluation happens in services.
Badge display happens in widgets.

---

## Query Flow

### Query services shape screen data

Examples:

- `BlockQueryService`
- `WorkoutQueryService`
- `BlockSummaryQueryService`

Responsibilities:

- read DB state
- shape data for one screen
- return maps/models needed by UI

Query services should not:

- mutate unrelated state
- trigger navigation
- calculate UI formatting unnecessarily

---

## Evaluation Flow

### Domain services update state

Examples:

- `LiftLoggingService`
- `WorkoutCompletionService`
- `BadgeEvaluationService`

Responsibilities:

- update DB state
- evaluate rules
- write totals
- write awards

Evaluation services should not:

- render UI
- navigate
- depend on widget state

---

## Temporary Testing Flow

Temporary testing through `AppShell` is allowed.

Examples:
- open `BlockSummaryScreen` directly
- open one `WorkoutLogScreen` directly

### Rule

Temporary test routing must be removed after verification.

Do not let test routing become permanent app flow.

---

## Current Intended User Path

Normal path:

1. launch app
2. app shell resolves current block
3. open dashboard
4. select workout
5. log workout
6. finish workout
7. see badge popup(s) if earned
8. return to dashboard
9. after final workout -> open summary

---

## Constraints

Do not:

- route directly from `main.dart` to feature screens
- let dashboard and summary responsibilities mix
- put startup creation logic inside screens
- recalculate totals in widgets
- evaluate badges in UI
- use hot reload as validation for DB/schema changes

---

## Testing Notes

For changes involving:

- database schema
- seed logic
- query services
- startup flow
- badge persistence

prefer:

- full stop
- reinstall / app data reset if needed
- full run

Do not rely on hot reload for DB-related validation.
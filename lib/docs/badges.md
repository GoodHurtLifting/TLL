# Badges

## Purpose

Badges are a repeatable achievement system that reinforces:

- consistency
- progress
- engagement
- future social interaction

Badges are not rare collectibles. They are earned frequently and accumulate.

---

## Core Rules

### Repeatable

Badges are repeatable unless explicitly stated otherwise.

Examples:
- Meat Wagon → every 100,000 lbs
- Lunch Lady → every new PR

---

### Event Driven

Badges are awarded from events:

- set logged
- workout completed
- block completed
- (future) social interaction

Badges are never calculated inside widgets.

---

### Append Only

Badge awards are never updated or deleted.

Each award = one row in `badge_awards`.

---

### Source-Based Uniqueness

Each badge is tied to:

- source_type
- source_id

This prevents duplicate awards for the same event.

---

### Local First

Badges are currently:

- computed locally
- stored in SQLite

Future:
- synced to Firestore
- used for leaderboards and social features

---

## Storage Model

### Table: badge_awards

Fields:

- id
- badge_key
- user_id
- awarded_at
- source_type
- source_id
- block_instance_id (optional)
- metadata_json (optional)

---

## Definitions

Defined in:

badge_definitions.dart

Each badge includes:

- key
- title
- description
- isRepeatable

---

## Current Badges

### Lunch Lady

- key: lunch_lady
- repeatable: true

Trigger:
- new all-time heaviest set

Valid lifts:
- squat
- bench_press
- deadlift

Event:
- set logging

Metadata:
- lift_key (optional)

---

### Meat Wagon

- key: meat_wagon
- repeatable: true

Trigger:
- every +100,000 lbs lifetime workload

Event:
- workout completion or totals update

---

### Punch Card

- key: punch_card
- repeatable: true

Trigger:
- 3+ workouts per week
- for 4 consecutive weeks

Event:
- workout completion

Notes:
- uses week grouping
- supports rolling windows

---

## Planned Badges

### Hype Man

Trigger:
- like 5 check-ins from Training Circle

---

### Daily Rider

Trigger:
- adherence to scheduled workouts

---

## Evaluation

Handled by:

BadgeEvaluationService

Responsibilities:

- detect qualifying events
- insert badge_awards rows
- prevent duplicates per source

---

## Display Locations

### Workout End

- shown immediately after finishing workout
- shows newly earned badges
- currently single badge
- future: carousel

---

### Block Summary

- shows badges earned during block
- simple list

---

### Future

- user profile
- leaderboard
- training circle feed

---

## Display Rules

- use badge title, not key
- metadata shown if available
- timestamps optional
- keep UI simple for now

---

## Constraints

Do not:

- calculate badges in widgets
- overwrite badge rows
- add multiple badge types at once
- introduce complex UI early
- depend on Firebase yet

---

## Build Order

1. Lunch Lady logic (complete)
2. Persist badge_awards (complete)
3. Display in summary (complete)
4. Workout-end popup (in progress)
5. Add Meat Wagon
6. Expand UI (carousel later)
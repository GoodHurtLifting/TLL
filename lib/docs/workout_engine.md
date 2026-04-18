# Workout Engine

## Purpose

Defines how training blocks are translated into runtime workouts.

This includes:
- schedule behavior
- block duration
- workout distribution
- instance generation rules

---

## Core Principle

Stock and custom blocks use the SAME pipeline:

catalog → block_templates → workout_templates → workout_template_lifts → block_instances → workout_instances → lift_instances

There are no separate tables for stock vs custom content.

---

## Block Types

### Stock Blocks
- `is_custom = 0`
- seeded with the app
- fixed structure
- fixed duration (typically 4 weeks)

### Custom Blocks
- `is_custom = 1`
- created by users
- flexible duration (2–6 weeks)
- flexible workout structure

---

## Block Template Fields (Required)

- `block_key`
- `title`
- `category`
- `duration_weeks`
- `schedule_type`
- `workouts_per_week`
- `total_workout_slots`
- `is_custom`
- `owner_user_id`

---

## Schedule Types

Each block must define a `schedule_type`.

This determines how workout templates are distributed across the block.

---

### 1. three_day_standard

Used for:
- Push Pull Legs
- most standard programs

#### Rules
- 3 workouts per week
- 4 weeks → 12 total slots

#### Distribution
Even rotation through workout templates:

Example with 3 workouts:
Week 1: A B C
Week 2: A B C
Week 3: A B C
Week 4: A B C


---

### 2. two_workout_alternating

Used for:
- Upper / Lower
- A/B style programs

#### Rules
- 3 workouts per week
- 4 weeks → 12 total slots

#### Distribution
Alternating pattern:
Week 1: A B A
Week 2: B A B
Week 3: A B A
Week 4: B A B

---

### 3. ppl_plus_condensed

Used for:
- condensed Push/Pull/Legs

#### Rules
- 3 workouts repeating continuously
- 21 total slots
- ignores standard weekly grouping

#### Distribution
Continuous rotation:
A B C A B C A B C ...


---

### 4. texas_method

Used for:
- Texas Method structure

#### Rules
- 3 workouts per week
- 6 workout templates exist
- only 3 used per week

#### Distribution
Defined mapping per week (not simple rotation)

---

## Runtime Generation

### Step 1 — Create Block Instance

Insert into `block_instances`:

- `user_id`
- `block_template_id`
- `run_number`
- `title_snapshot`
- `schedule_type_snapshot`
- `duration_weeks_snapshot`
- `status = active`
- timestamps

---

### Step 2 — Generate Workout Instances

For each slot in the block:

#### Determine:
- `week_index`
- `week_number`
- `slot_number_in_block`
- `slot_index_in_week`
- which workout_template to use

#### Insert into `workout_instances`:

- `block_instance_id`
- `workout_template_id`
- `sequence_index`
- `week_index`
- `week_number`
- `slot_number_in_block`
- `slot_index_in_week`
- `workout_key`
- `title_snapshot`
- `status = not_started`

---

### Step 3 — Generate Lift Instances

For each workout_instance:

- load `workout_template_lifts`
- preserve order via `sequence_index`

#### Insert into `lift_instances`:

- `workout_instance_id`
- `workout_template_lift_id`
- `sequence_index`

#### Snapshot fields:
- `lift_name_snapshot`
- `rep_scheme_snapshot`
- `lift_info_snapshot`
- `score_type_snapshot`
- `score_multiplier_snapshot`
- `input_mode_snapshot`

#### Prescription snapshot:
- `reference_source_snapshot`
- `reference_lift_key_snapshot`
- `percent_value_snapshot`

---

## % of Previous Lift Logic

### Supported
- `reference_source = previous_instance_average`

### Rule

1. Find most recent prior instance of `reference_lift_key`
2. Pull all `lift_logs` rows for that instance
3. Compute:  average_weight = sum(weight) / number_of_sets
4. Apply percentage:  recommended_weight = average_weight * percent_value
5. Round: round to nearest 5 lb


---

## Important Rules

### Rule 1
Templates define structure. Instances define execution.

### Rule 2
All runtime data must be SNAPSHOT from templates.

Templates can change later. Instances must not.

### Rule 3
Schedule logic must be deterministic.

Given the same template + run_number, generation must always produce the same structure.

### Rule 4
Do not store calculated recommendation weights in the database.

Store inputs only. Calculate in logic layer.

### Rule 5
Stock and custom blocks must NEVER diverge structurally.

Only data changes — not schema.

---

## Future Extensions

- deload weeks
- variable week lengths
- auto progression rules
- dynamic % adjustments
- fatigue tracking

These must layer on top of the same pipeline.
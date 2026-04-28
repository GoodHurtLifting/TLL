# Database Schema

## Core Principle
SQLite is the runtime source of truth for training execution.
Firestore is for identity, sync targets, social features, and selected aggregates.

## Core Pipeline
catalog -> templates -> instances -> logs -> totals

## Table Definitions

---

## Table Groups

### 1) Catalog Tables
These define the global lift library.

- lift_catalog
- muscle_groups
- lift_catalog_muscle_groups

### 2) Template Tables
These define reusable workout structures.
Both stock and custom templates should follow the same shape.

- block_templates
- workout_templates
- workout_template_lifts

### 3) Runtime Instance Tables
These define a user's actual runs.

- block_instances
- workout_instances
- lift_instances

### 4) Logging Tables
These store what the user actually entered.

- lift_logs

### 5) Totals Tables
These store computed results and are the source of truth for display.

- lift_totals
- workout_totals
- block_totals

### 6) Stats / Derived Tables
Optional cached or materialized data for faster reads.

- user_stats_cache
- lift_weight_pr_cache

### 7) Sync Metadata Tables
These help manage cloud sync safely later.

- sync_queue
- sync_state

### lift_catalog
Master definition for every lift in the system.

Columns:
- id INTEGER PRIMARY KEY
- lift_key TEXT NOT NULL UNIQUE
- name TEXT NOT NULL
- video_url TEXT
- lift_info TEXT
- score_type TEXT NOT NULL
- input_mode TEXT
- created_at TEXT
- updated_at TEXT

Notes:
- `lift_key` is the stable app-wide identifier.
- `score_type` must be one of `multiplier` or `bodyweight`.
- `score_type` defines the lift’s default scoring family only.
- `score_multiplier` does not belong in `lift_catalog` because multipliers vary by rep scheme, block, workout, and custom prescription.
- `input_mode` must be one of `standard` or `per_side` (entered weight/reps are per side and must be doubled in calculations).

---

### muscle_groups
Master list of available muscle groups.

Columns:
- id INTEGER PRIMARY KEY
- muscle_key TEXT NOT NULL UNIQUE
- name TEXT NOT NULL
- sort_order INTEGER NOT NULL DEFAULT 0
- created_at TEXT
- updated_at TEXT

Notes:
- `muscle_key` is the stable app-wide identifier.
- examples: `chest`, `front_delts`, `triceps`, `lats`, `quads`

---

### lift_catalog_muscle_groups
Join table connecting lifts to muscle groups with an assigned role.

Columns:
- id INTEGER PRIMARY KEY
- lift_catalog_id INTEGER NOT NULL
- muscle_group_id INTEGER NOT NULL
- role TEXT NOT NULL
- sort_order INTEGER NOT NULL DEFAULT 0
- created_at TEXT
- updated_at TEXT

Foreign Keys:
- lift_catalog_id -> lift_catalog.id
- muscle_group_id -> muscle_groups.id

Notes:
- `role` must be one of:
    - `primary`
    - `secondary`
- a lift may have multiple primary and secondary muscle groups

---

### block_templates
Reusable block definitions for both stock and custom blocks.

Columns:
- id INTEGER PRIMARY KEY
- block_key TEXT NOT NULL UNIQUE
- title TEXT NOT NULL
- description TEXT
- category TEXT NOT NULL
- difficulty TEXT
- num_weeks INTEGER NOT NULL
- schedule_type TEXT NOT NULL
- workouts_per_week INTEGER
- total_workout_slots INTEGER
- is_custom INTEGER NOT NULL DEFAULT 0
- owner_user_id TEXT
- is_active INTEGER NOT NULL DEFAULT 1
- created_at TEXT
- updated_at TEXT

Notes:
- stock blocks: `is_custom = 0`
- custom blocks: `is_custom = 1`
- `owner_user_id` is null for stock blocks

---

### workout_templates
Defines workouts that belong to a block template.

Columns:
- id INTEGER PRIMARY KEY
- workout_key TEXT NOT NULL UNIQUE
- block_template_id INTEGER NOT NULL
- title TEXT NOT NULL
- workout_type TEXT
- sequence_index INTEGER NOT NULL
- is_active INTEGER NOT NULL DEFAULT 1
- created_at TEXT
- updated_at TEXT

Foreign Keys:
- block_template_id -> block_templates.id

Notes:
- one row per reusable workout template
- example: Push A, Pull A, Legs A, Upper A, Lower A

---

### workout_template_lifts
Defines which lifts appear in a workout template and in what order.

Columns:
- id INTEGER PRIMARY KEY
- workout_template_id INTEGER NOT NULL
- lift_catalog_id INTEGER NOT NULL
- sequence_index INTEGER NOT NULL
- rep_scheme TEXT NOT NULL
- lift_info TEXT
- score_type TEXT
- score_multiplier REAL
- score_multiplier_mode TEXT
- input_mode TEXT
- reference_source TEXT
- reference_lift_key TEXT
- percent_value REAL
- created_at TEXT
- updated_at TEXT

Foreign Keys:
- workout_template_id -> workout_templates.id
- lift_catalog_id -> lift_catalog.id

Notes:
- This table stores the lift prescription for a workout template.
- `rep_scheme`, `score_type`, `score_multiplier`, and `input_mode` describe how the lift is scored/logged in this workout.
- For stock blocks, `score_multiplier_mode = fixed` and `score_multiplier` should be prefilled.
- For custom blocks, `score_multiplier_mode` may be `predictive`, and `score_multiplier` may start as null until enough user logging data exists to calculate it.
- `score_multiplier_mode` must be one of:
  - `fixed`
  - `predictive`
  - `manual`
- A multiplier lift must eventually have a `score_multiplier` before official scoring can be finalized.
- Bodyweight lifts may have `score_multiplier` null.
- `reference_source` must be one of:
    - `none`
    - `previous_instance_average`
- when `reference_source = previous_instance_average`, `reference_lift_key` and `percent_value` should be populated
- `%` prescriptions should use the average weight across all logged sets from the previous instance of the reference lift
- recommended weight should be rounded to the nearest 5 lb in the calculation layer, not stored as a DB field

---

### block_instances
A user's actual run of a block template.

Columns:
- id INTEGER PRIMARY KEY
- user_id TEXT NOT NULL
- block_template_id INTEGER NOT NULL
- run_number INTEGER NOT NULL
- title_snapshot TEXT NOT NULL
- started_at TEXT
- completed_at TEXT
- status TEXT NOT NULL
- created_at TEXT
- updated_at TEXT

Foreign Keys:
- block_template_id -> block_templates.id

Notes:
- `status` should support at least `not_started`, `active`, `completed`, `archived`
- `title_snapshot` preserves the displayed block name even if template content changes later

---

### workout_instances
A scheduled workout slot inside a block instance.

Columns:
- id INTEGER PRIMARY KEY
- block_instance_id INTEGER NOT NULL
- workout_template_id INTEGER NOT NULL
- workout_slot_index INTEGER NOT NULL
- week_index INTEGER NOT NULL
- day_label TEXT
- title_snapshot TEXT NOT NULL
- started_at TEXT
- completed_at TEXT
- status TEXT NOT NULL
- created_at TEXT
- updated_at TEXT

Foreign Keys:
- block_instance_id -> block_instances.id
- workout_template_id -> workout_templates.id

Notes:
- this table handles repeated workout distribution across a block run
- `workout_slot_index` is the absolute slot inside the run

---

### lift_instances
The actual lift rows shown to the user for a workout instance.

Columns:
- id INTEGER PRIMARY KEY
- workout_instance_id INTEGER NOT NULL
- workout_template_lift_id INTEGER NOT NULL
- sequence_index INTEGER NOT NULL
- lift_name_snapshot TEXT NOT NULL
- rep_scheme_snapshot TEXT NOT NULL
- lift_info_snapshot TEXT
- score_type_snapshot TEXT NOT NULL
- score_multiplier_snapshot REAL
- score_multiplier_mode_snapshot TEXT
- input_mode_snapshot TEXT NOT NULL DEFAULT 'standard'
- reference_source_snapshot TEXT
- reference_lift_key_snapshot TEXT
- percent_value_snapshot REAL
- created_at TEXT
- updated_at TEXT

Foreign Keys:
- workout_instance_id -> workout_instances.id
- workout_template_lift_id -> workout_template_lifts.id

Notes:
- runtime snapshots protect historical integrity while still allowing template evolution going forward
- `score_type_snapshot` must be one of `multiplier` or `bodyweight`.
- `input_mode_snapshot` must be one of `standard` or `per_side`.
- `reference_source_snapshot` must be one of `none` or `previous_instance_average`.
- `score_multiplier_mode_snapshot` preserves whether the multiplier was fixed, predictive, or manual when the lift instance was created/scored.
---

### lift_logs
Raw set entry data entered by the user.

Columns:
- id INTEGER PRIMARY KEY
- lift_instance_id INTEGER NOT NULL
- set_index INTEGER NOT NULL
- reps INTEGER
- weight REAL
- created_at TEXT
- updated_at TEXT

Foreign Keys:
- lift_instance_id -> lift_instances.id

Notes:
- one row per set
- this is the raw input table

---

### lift_totals
Computed totals for one lift instance.

Columns:
- id INTEGER PRIMARY KEY
- lift_instance_id INTEGER NOT NULL UNIQUE
- total_reps INTEGER NOT NULL DEFAULT 0
- total_workload REAL NOT NULL DEFAULT 0
- total_score REAL NOT NULL DEFAULT 0
- updated_at TEXT

Foreign Keys:
- lift_instance_id -> lift_instances.id

Notes:
- single source of truth for lift display totals

---

### workout_totals
Computed totals for one workout instance.

Columns:
- id INTEGER PRIMARY KEY
- workout_instance_id INTEGER NOT NULL UNIQUE
- total_workload REAL NOT NULL DEFAULT 0
- workout_score REAL NOT NULL DEFAULT 0
- completed_lift_count INTEGER NOT NULL DEFAULT 0
- total_lift_count INTEGER NOT NULL DEFAULT 0
- updated_at TEXT

Foreign Keys:
- workout_instance_id -> workout_instances.id

Notes:
- workout score should come from your defined averaging rule, not be recomputed in the widget tree

---

### block_totals
Computed totals for one block instance.

Columns:
- id INTEGER PRIMARY KEY
- block_instance_id INTEGER NOT NULL UNIQUE
- total_workload REAL NOT NULL DEFAULT 0
- block_score REAL NOT NULL DEFAULT 0
- completed_workout_count INTEGER NOT NULL DEFAULT 0
- total_workout_count INTEGER NOT NULL DEFAULT 0
- training_days INTEGER NOT NULL DEFAULT 0
- updated_at TEXT

Foreign Keys:
- block_instance_id -> block_instances.id

Notes:
- this supports block dashboard and block summary reads cleanly

---

### user_stats_cache
Optional cached aggregate stats for fast dashboard loading.

Columns:
- id INTEGER PRIMARY KEY
- user_id TEXT NOT NULL UNIQUE
- total_blocks_completed INTEGER NOT NULL DEFAULT 0
- total_workouts_completed INTEGER NOT NULL DEFAULT 0
- total_lbs_lifted REAL NOT NULL DEFAULT 0
- updated_at TEXT

---

### lift_weight_pr_cache
Optional cached PR-like best values by user and lift.

Columns:
- id INTEGER PRIMARY KEY
- user_id TEXT NOT NULL
- lift_key TEXT NOT NULL
- heaviest_weight REAL NOT NULL DEFAULT 0
- updated_at TEXT

Notes:
- add a unique composite index later on `user_id + lift_key`

---

### sync_queue
Pending records or events to sync to cloud later.

Columns:
- id INTEGER PRIMARY KEY
- entity_type TEXT NOT NULL
- entity_id TEXT NOT NULL
- action TEXT NOT NULL
- payload_json TEXT
- status TEXT NOT NULL
- created_at TEXT
- updated_at TEXT

---

### sync_state
Stores local sync checkpoints.

Columns:
- id INTEGER PRIMARY KEY
- key TEXT NOT NULL UNIQUE
- value TEXT
- updated_at TEXT

## Database Rules

### Rule 1
Widgets never calculate official totals.

### Rule 2
`lift_totals`, `workout_totals`, and `block_totals` are the source of truth for official totals shown in the app.

### Rule 3
Stock and custom content must use the same template and instance tables.

### Rule 4
Catalog data is global and describes lift identity. Template rows define the workout-specific prescription and scoring setup. Runtime instances snapshot what the user actually ran.

### Rule 5
Raw user input belongs in `lift_logs`. Derived values belong in totals tables.

### Rule 6
Do not store the same meaning in multiple places unless one is explicitly a snapshot or cache.

### Rule 7
Any future Firebase sync should sync selected aggregates, profiles, and social data first—not raw lift log history.

### Rule 8
Prescription metadata and scoring metadata are separate concerns. Scoring determines how a lift earns a score. Prescription determines how a recommended working weight is derived.

### Rule 9
When a lift uses `% of previous lift`, the recommendation must be based on the average weight across all logged sets from the most recent prior instance of the reference lift, then rounded to the nearest 5 lb in the calculation layer.

### Rule 10
Score multipliers belong to workout/template lift prescriptions, not the global lift catalog. Stock block multipliers are fixed and predefined. Custom block multipliers may be predictive and assigned after the user logs enough baseline data.
# Scoring Rules

## Definitions

### Set Weight
The raw weight entered by the user for a given set.

### Workload
Workload is calculated per set using the effective rep value for the lift's input mode.

- For `input_mode = standard`:
    - set_workload = weight * reps

- For `input_mode = per_side`:
    - set_workload = weight * (reps * 2)

Lift workload is the sum of all set workloads.

### Weight Sum
Weight sum is the sum of the raw weights entered across all sets.

This is used in the multiplier-based scoring formula and is not the same as workload.

### Effective Total Reps
Effective total reps means the final rep total after applying input mode rules.

- For `input_mode = standard`, this is the same as logged reps.
- For `input_mode = per_side`, reps are doubled before summing.

## Multiplier Score Formula

For lifts with `score_type = multiplier`:
- `score_type = multiplier` uses the standard POSS multiplier equation

score = sum_of_set_weights * effective_total_reps * score_multiplier

## Example

For a 4x6 lift with 130 lbs used for each set:

- set weights = 130, 130, 130, 130
- sum_of_set_weights = 520
- effective total reps = 24
- workload = 3120

If multiplier = 0.007:

score = 520 * 24 * 0.007 = 87.36

## For lifts using percentage-based recommendation logic:

- previous set values are displayed per set
- recommended weight is calculated from the average weight across all sets of the most recent prior comparable lift instance
- the average weight itself is not displayed to the user

## Per-Side Input Rule

For lifts with `input_mode = per_side`:

- entered set weight is treated as per-side weight
- total reps are doubled
- workload is doubled
- score weight sum is NOT doubled

### Formula behavior

For each set:

- effective_reps = entered_reps * 2
- effective_workload = entered_weight * entered_reps * 2
- score_weight_contribution = entered_weight

Multiplier score remains:

score = sum_of_set_weights * effective_total_reps * score_multiplier

## Per-Side Example

For a per-side lift with 3 sets of 10 reps at 40 lbs per side:

- entered set weights = 40, 40, 40
- sum_of_set_weights = 120
- effective total reps = 60
- workload = 2400

If multiplier = 0.007:

score = 120 * 60 * 0.007 = 50.4

## Bodyweight Score Formula

For lifts with `score_type = bodyweight`:
- `score_type = bodyweight` is the bodyweight-movement formula and does not use the user's actual bodyweight as an input

score = effective_total_reps + (sum_of_set_weights * 0.5)

### Notes

- This formula is used for primarily bodyweight movements.
- The user's actual bodyweight is NOT part of the equation.
- `effective_total_reps` follows input mode rules.
- `sum_of_set_weights` is the sum of the raw entered weights across all sets.
- Added weight acts as a bonus and is multiplied by 0.5.

### Example

For weighted crunches (4x25) using a 25 lb plate:

- effective total reps = 100
- sum_of_set_weights = 100

score = 100 + (100 * 0.5) = 150

## Workout Score

Workout score is the average of all lift scores within a workout.

score = sum(lift_scores) / total_lift_count

### Notes

- All lifts in the workout are included in the denominator
- Unlogged lifts contribute a score of 0
- This ensures workouts cannot be artificially inflated by skipping lifts

## Workout Workload

Workout workload is the sum of all lift workloads within a workout.

workload = sum(lift_workloads)

## Workout Completion

A workout is considered complete when the user explicitly finishes it.

### Notes

- Completion is not inferred from score or workload alone
- `completed_at` is set when the workout is finished
- `training_days` is based on unique workout completion dates

## Lift Completion Rule

A lift is considered completed if:

total_reps > 0

### Notes

- Used for tracking completed lifts in a workout
- Does not affect score calculation directly

## Block Score

Block score is based on the best completed instances of each workout within the block.

For each unique workout template:
- select the best workout score from all instances
- average those best scores

score = average(best_workout_scores)

## Block Workload

Block workload is the sum of all workout workloads within the block.

workload = sum(workout_workloads)

## Block Completion Rule

A block is considered complete when all required workout slots have been completed.

### Notes

- Completion is based on workout completion, not score
- Used for badges, stats, and progression tracking
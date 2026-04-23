# UI Principles

## Purpose

Defines the visual and structural rules for The Lift League UI.

This file exists to prevent:

- generic fitness-app layouts
- UI logic creeping into widgets
- overdesigned screens too early
- loss of the specific TLL feel

---

## Core Philosophy

The Lift League UI should feel:

- structured
- deliberate
- performance-focused
- readable under fatigue
- more like a training tool than social media

The app should not feel noisy, trendy, or overly gamified.

---

## Primary UI Goal

The interface should help users:

- know what to do
- log it quickly
- see meaningful feedback
- stay motivated
- understand progress over time

---

## General Rules

### Utility First

UI should prioritize usefulness over decoration.

If a visual element does not improve:

- clarity
- speed
- motivation
- hierarchy

it probably does not belong yet.

---

### Data Should Feel Organized

The app contains a lot of structured training data.

Screens should present data in a way that feels:

- aligned
- intentional
- easy to scan

This is especially important in:

- workout log
- block summary
- dashboard
- stats

---

### Avoid Generic App Patterns

Do not default to:

- oversized empty cards
- excessive whitespace
- social-feed style layouts
- trendy rounded UI just because it looks modern

The Lift League should feel like a training platform, not a lifestyle app.

---

## Workout Log Principles

### Highest Priority Screen

The workout log is the most important screen in the app.

It is the core product surface.

Changes to this screen should be conservative and intentional.

---

### Table-First Layout

Workout logging should feel like a structured training sheet.

Preferred traits:

- stable column alignment
- predictable row structure
- current and previous data visible together
- totals integrated into the lift block

Do not drift toward a loose stacked-form layout.

---

### Current vs Previous Context

Users should be able to compare:

- current set input
- previous set data
- recommended values
- totals

without leaving the screen.

This is a key differentiator.

---

### Logging Must Be Fast

Entering reps and weight should require minimal friction.

Avoid:

- unnecessary taps
- hidden context
- oversized controls
- verbose modal flows during logging

---

### Totals Must Feel Integrated

Lift totals and workout totals should feel like part of the training workflow, not disconnected stats.

Lift-level totals belong near the lift.

Workout totals belong in a clear footer area.

---

## Block Dashboard Principles

### Clear Overview, Not Clutter

The dashboard should quickly answer:

- what block am I in
- what run is this
- what workouts are coming up
- what have I completed
- how am I doing overall

It should not try to be the stats screen.

---

### Workout Access Must Be Immediate

The dashboard is a launch point into training.

The workout list should stay simple and tappable.

Avoid overloading workout rows with too much detail.

---

## Block Summary Principles

### Summary Should Feel Earned

The summary is not just a list of completed workouts.

It should answer:

- what did I accomplish
- did I stick to the plan
- where did I improve
- what did I earn

---

### Block-Level Story First

The summary should emphasize:

- overview
- adherence
- improvements
- badges / milestones

Detailed workout rows belong lower on the screen.

---

### Accomplishment Over Raw Archive

The screen should feel like:

- a recap
- a reward
- a performance summary

not a recycled dashboard or workout list.

---

## Badge UI Principles

### Reward, Don’t Interrupt Excessively

Badges should feel motivating, not annoying.

Workout-end badge popups are appropriate.
Too many repeated interruptions are not.

---

### Keep Badge UI Simple Early

Early badge UI should be:

- clear
- readable
- stable

Avoid early overbuild such as:

- complex carousels
- heavy animation
- asset-dependent designs

Those can come later.

---

### Badge Display Hierarchy

Badge title is primary.

Optional metadata is secondary.

Example:
- Lunch Lady
- Lift: Bench Press

---

## Stats and Progress Principles

### Show Progress That Matters

The app should emphasize:

- consistency
- improvement
- accumulated work
- repeated effort

Not just max-performance vanity stats.

---

### Comparison Should Be Purposeful

Where comparisons are shown, they should help answer:

- am I getting better
- am I more consistent
- how does this run compare to the last one

---

## Visual Tone

### Strong, Clean, Functional

The visual tone should feel:

- gym-adjacent
- confident
- not cartoonish
- not corporate-soft

---

### Minimal Noise

Avoid:

- excessive color usage
- too many competing highlights
- decorative elements without meaning

Use emphasis intentionally.

---

## Component Rules

### Widgets Should Stay Dumb

Widgets render.
Services/query layers provide meaning.

Widgets should not:

- calculate scores
- calculate totals
- evaluate badges
- infer business rules

---

### Reuse Should Preserve Identity

Reusable components are good, but should not flatten the app into generic sameness.

Shared components must still support TLL’s structure and tone.

---

## Temporary UI Rule

Temporary testing UI is allowed.

Examples:
- direct screen launch
- placeholder dialogs
- placeholder badge displays

But temporary UI should not become permanent design by accident.

---

## Constraints

Do not:

- redesign the workout log casually
- replace structured layouts with generic cards/forms
- move logic into widgets for convenience
- over-polish low-priority screens before core screens are stable
- let placeholder layouts define final design direction

---

## Current Priorities

1. workout log usability
2. summary hierarchy
3. badge feedback moments
4. dashboard clarity
5. stats polish later

---

## Future Notes

Later visual improvements may include:

- badge art
- stronger visual identity
- refined typography hierarchy
- reusable TLL-styled dialog/panel components

But those should sit on top of a stable, useful interface.
# The Lift League UI Style Guide

## Core Look
- Use black backgrounds by default.
- Use white text by default.
- Use bold text for primary stats, scores, titles, and important actions.
- Avoid floating card-heavy layouts unless there is a clear reason.
- Prefer flat sections separated by spacing, dividers, or typography.

## Colors
- Screen background: black
- Primary text: white
- Secondary text: white70
- Muted text: white54
- Divider lines: white24 or white12
- Input background: dark green `0xFF2E4F40`
- Total cells: dark gray `0xFF3A3A3A`
- Score cells: blue `0xFF1565C0`
- Previous score cells: darker blue `0xFF0D47A1`
- Links: blue
- Warning/emphasis: redAccent

## Typography
- Screen titles: 20–24, bold
- Section titles: 18–20, bold
- Primary stats: 18, bold
- Normal text: 13–14
- Small labels: 11–12

## Workout Log
- Preserve the spreadsheet-style table layout.
- Reps and weight input cells should use dark green.
- Totals rows should use dark gray.
- Score rows should use blue.
- Previous data should be visually quieter than current data.
- Lift names should look like links: blue, underlined, bold.
- Footer should stay compact.
- Workout Score should be larger than Previous Score and Total Workload.

## Buttons
- Use simple rectangular buttons with rounded corners.
- Avoid bright filled buttons unless the action is important.
- Prefer dark button backgrounds with white text.
- Icons should be filled, not thin outline, when used for keypad/navigation.

## Keypad
- Use a black keypad background.
- Keys should be dark gray rounded rectangles.
- Number text should be large and bold.
- Function keys should use filled Material icons where possible.
- Avoid outlined button styling for keypad keys.

## Block Dashboard
- Keep sections flat and readable.
- Use dividers or spacing instead of card stacks.
- Make the active/current workout visually clear.
- Leaderboard/score areas should feel integrated, not like separate floating boxes.

## Block Summary
- Should feel like a finish screen, not a form.
- Use strong title hierarchy.
- Highlight the block score and total workload.
- Badges should be visually important but not cluttered.
- Avoid too many separate cards.

## General Rules for Codex
- Do not introduce new themes or colors unless asked.
- Do not convert flat layouts into card-heavy layouts.
- Do not refactor working logic during visual cleanup.
- Make visual changes surgically.
- Keep files modular when adding reusable widgets.

## App Bars
- App bars should use black background.
- App bar text/icons should be white.
- App bar navigation should be white left pointing arrow to go back, placed on the left side of bar.
- Avoid default Material light app bars.
- Use elevation: 0 unless a shadow is intentionally needed.
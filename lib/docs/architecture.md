# The Lift League Architecture

## Product Goal
The Lift League is a platform built around:
- training execution
- progress tracking
- motivation
- social accountability

## Core Technical Principle
The app is data-first, not UI-first.

## Layers
- UI
- Application
- Domain
- Data

## Rules
- No calculation logic in widgets
- No direct SQLite calls from screens
- No Firestore writes from widgets
- Totals tables are the single source of truth
- Stock and custom blocks must use the same pipeline

## Data Pipeline
Catalog -> Template -> Instance -> Log -> Totals -> Stats -> Sync
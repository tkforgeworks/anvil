# Anvil — Claude Code Project Instructions

## Project Overview

Anvil is a desktop RPG data management tool built with Electron + React + TypeScript + SQLite. It provides structured editors for six first-class game data domains (Character Classes, Abilities, Items, Crafting Recipes, NPCs, Loot Tables) and a Nunjucks-based export engine.

**Current status:** Pre-implementation — planning and architecture phase. No source code exists yet.

---

## Key Documents

| Document | Purpose |
| :---- | :---- |
| `archive/Anvil_PRD_v1_4.md` | **Source of truth** for all requirements and feature scope. Always consult this for what the product must do. |
| `Anvil_Implementation_Design_v1_0.md` | High-level architecture and implementation strategy. Derived from the PRD. Starting point for epics and implementation work. |
| `archive/Anvil_Architecture_and_Schema_Design.md` | Prior design document — **superseded and not aligned with PRD v1.4**. Do not use as a reference for implementation decisions. |

---

## Architecture Decisions (Do Not Reverse Without Discussion)

These are decisions already made and documented in the Implementation Design. Raise a question before deviating from any of them.

- **Electron main/renderer strict split.** The renderer never accesses SQLite or Node.js APIs directly. All data flows through typed IPC channels via `contextBridge`.
- **SQLite via `better-sqlite3`, raw SQL, no ORM.** Explicit control over migrations and transactions is required.
- **Three-part record identity.** Every domain record has: an immutable internal ID (UUID or auto-increment, used in all FK relationships, never shown to the user), a display name (editable, shown in UI), and an export key (editable, written to export output). These three fields are always separate — they must never be conflated.
- **Soft-delete by default.** All domain record deletions are soft (`deleted_at` column). Hard delete is only available from archive views and the recycle bin. The `deleted_at` column must exist on every domain table from the initial migration.
- **Custom fields are scalar/enum only.** Custom field types are `text`, `integer`, `decimal`, `boolean`, and `enum`. No cross-domain reference field types. This is an explicit PRD constraint (§4.1.2).
- **Formula engine runs in main process.** Formula evaluation is main-process-only, debounced, and cached. The renderer sends formula strings and variable bindings via IPC and receives computed results.
- **Loot table drop weights are integers.** Weights are whole numbers normalized to percentages at display time. They are not stored as floating-point probabilities.
- **Abilities and Loot Tables are first-class domains.** They have their own tables, IPC channels, list views, and editors. Abilities are not sub-records of classes.
- **Export presets are Nested JSON, Flat JSON, and CSV.** Not "Godot Resource JSON" — that was a prior doc error.
- **Nunjucks for export templates.** Runs sandboxed in the main process.

---

## Domain Model Summary

Six first-class data domains, each with full CRUD, soft-delete, custom fields (where applicable), and export context participation:

1. **Character Classes** — stat growth curves, derived stat formulas, ability references
2. **Abilities** — reusable records assignable to both classes and NPCs
3. **Items** — categorized, rarity-tiered, with per-category custom fields
4. **Crafting Recipes** — ingredient + output item resolution, station and specialization references
5. **NPCs** — typed (per NPC type custom fields), class-based stat inheritance (additive, multi-class), loot table and ability references
6. **Loot Tables** — standalone drop tables with integer weight entries referencing items

---

## Development Conventions

- **Constructor injection over field injection** (when applicable in any DI patterns used)
- **Explicit over magic** — avoid framework features that obscure what's actually happening
- **Tests test behavior, not implementation** — if tests are written, they should verify outcomes, not internal call sequences
- **IPC channels follow the pattern `domain:operation`** — e.g., `classes:list`, `abilities:create`, `loot-tables:get`
- **Migrations are sequential and non-destructive** — each migration file has a version number; upgrading a project file creates a copy of the original before applying changes
- **No half-finished commits** — each commit must leave the codebase in a working state

---

## Phase Plan

**Phase 1 — Foundation**
Character Classes, Abilities, Items, Crafting Recipes; project lifecycle (create/open/save/auto-save/lock); formula engine; validation system (inline + panel); custom fields; all six domain tables (including NPC and Loot Table stubs with soft-delete columns, even though their editors come in Phase 2).

**Phase 2 — Full Domains & Export**
NPC editor, Loot Table editor, export system (templates + presets + selective export), soft-delete archive views and recycle bin, bulk operations, undo/redo, theme customization, multi-class comparison view.

---

## CLAUDE.md Self-Update Rule

**Before completing any `git commit`, check whether this file needs updating.**

Specifically, review whether any of the following have changed in this session and are not yet reflected here:

- New architectural decisions made or existing ones changed
- New documents added to the repo or existing docs superseded
- Phase plan adjustments or scope changes
- New development conventions established
- Project status changes (e.g., bootstrapping started, first epic begun)

If updates are needed, make them before creating the commit. The commit that introduces a change should also update CLAUDE.md if that change affects future Claude sessions.

This check is also enforced via a pre-commit hook reminder in `.claude/settings.json`.

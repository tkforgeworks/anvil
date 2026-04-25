# Anvil — Claude Code Project Instructions

## Project Overview

Anvil is a desktop RPG data management tool built with Electron + React + TypeScript + SQLite. It provides structured editors for six first-class game data domains (Character Classes, Abilities, Items, Crafting Recipes, NPCs, Loot Tables) and a Nunjucks-based export engine.

**Current status:** ANV-4 (Project Bootstrap & Application Shell), ANV-30 (domain repositories + IPC handlers), ANV-57 (repository integration test suite, 80 tests), ANV-6 (data model & schema foundation, with bug-fix child tickets ANV-58/59/60), ANV-7 (custom fields system), ANV-33 (class list view + CRUD), ANV-34 (stat growth editor with Recharts chart), ANV-35 (derived stat definitions, custom recursive-descent formula engine, per-class formula overrides, class metadata fields), ANV-37 (ability assignment panel in the class editor — add/remove/reorder with soft-delete warning and click-through to ability editor), ANV-64 (migration 004: resource_type column on abilities; duplicate() and getUsedBy() on ability repository; ABILITIES_DUPLICATE and ABILITIES_GET_USED_BY IPC channels), ANV-39 (full Abilities list view and AbilityEditorPage with Details, Stat Modifiers, and Used By tabs), ANV-42 (validation engine in `src/main/validation/engine.ts` — broken/soft-deleted reference checks across all domain FKs and junctions, required-custom-field empty checks, derived-stat formula syntax/runtime/cycle checks with per-class override awareness; wired through `VALIDATION_RUN`/`VALIDATION_GET_ISSUES` IPC), ANV-43 (inline validation display — `useRecordValidation` hook, `ValidationBanner` component, `fieldValidationProps` helper; all six editor pages show per-record validation after save; dashboard shows project-wide validation summary on refresh), ANV-44 (global validation panel — issues grouped by domain and severity with click-to-navigate to affected record editors; sidebar badge showing error+warning count), and ANV-50 (export engine — context assembler gathers all 6 domains with junction data and custom fields; Nunjucks renderer with 3 built-in presets: Nested JSON, Flat JSON, CSV; export page with scope selection, preview panel, file write via OS dialog; validation gate blocks export on errors) implemented. Application shell compiles and runs with full IPC bridge, SQLite layer, React Router, MUI theme, and Zustand stores in place.

---

## Key Documents

| Document | Purpose |
| :---- | :---- |
| `archive/Anvil_PRD_v1_4.md` | **Source of truth** for all requirements and feature scope. Always consult this for what the product must do. |
| `design_notes/Anvil_Implementation_Design_v1_0.md` | High-level architecture and implementation strategy. Derived from the PRD. Starting point for epics and implementation work. |
| `archive/Anvil_Architecture_and_Schema_Design.md` | Prior design document — **superseded and not aligned with PRD v1.4**. Do not use as a reference for implementation decisions. |
| `docs/testing.md` | How to run the repository integration test suite; WAL mode explanation; ABI workflow for native module. |

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

## Known Technical Debt

**better-sqlite3 ABI — test vs. Electron binary**
`npm run rebuild` compiles `better-sqlite3` against Electron's ABI. Running `npm test` after that will fail with `NODE_MODULE_VERSION` mismatch. Fix by running `npm rebuild better-sqlite3` first, then `npm run rebuild` after tests to restore the Electron binary. See `docs/testing.md` for details.

**npm audit — devDependency toolchain vulnerabilities (accepted)**
`npm audit --omit=dev` reports zero production vulnerabilities. The ~27 remaining findings are all in devDependencies: `@electron-forge/*` → `@electron/rebuild` → `@electron/node-gyp` → `tar`/`cacache`, and `@electron-forge/cli` → `@inquirer/prompts` → `tmp`. These have "No fix available" because they are bound to electron-forge 7.x depending on a pre-stable `@electron/rebuild`. They will resolve when electron-forge 8.x exits alpha. None of these packages ship in the packaged application. Do not spend time re-investigating or attempting to force-fix these.

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

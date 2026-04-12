# Anvil — Implementation Design

RPG Resource Management Tool

*High-Level Architecture & Implementation Strategy*

| Field | Value |
| :---- | :---- |
| Version | 1.0 |
| Status | Draft |
| Date | April 2026 |
| Based On | PRD v1.4 |

---

## Table of Contents

1. [Document Purpose](#1-document-purpose)
2. [Technology Stack](#2-technology-stack)
3. [Application Architecture](#3-application-architecture)
4. [Project File & Data Architecture](#4-project-file--data-architecture)
5. [Domain Model](#5-domain-model)
6. [Identity & Reference Model](#6-identity--reference-model)
7. [Custom Fields System](#7-custom-fields-system)
8. [Formula Engine](#8-formula-engine)
9. [Validation System](#9-validation-system)
10. [Soft-Delete & Record Lifecycle](#10-soft-delete--record-lifecycle)
11. [Export System](#11-export-system)
12. [UI Architecture](#12-ui-architecture)
13. [State Management](#13-state-management)
14. [Project File Lifecycle](#14-project-file-lifecycle)
15. [Non-Functional Requirements Mapping](#15-non-functional-requirements-mapping)
16. [Phase Alignment](#16-phase-alignment)

---

## 1. Document Purpose

This document defines the high-level implementation architecture for Anvil. It is designed to be complete enough to decompose into epics and feature builds, but intentionally avoids low-level implementation detail (specific SQL schemas, component APIs, algorithm code). Every architectural decision here is derived from and traceable to PRD v1.4.

This document supersedes the earlier `Anvil_Architecture_and_Schema_Design.md`, which was found to have significant divergence from the PRD.

---

## 2. Technology Stack

### 2.1 Runtime & Packaging

| Layer | Choice | Rationale |
| :---- | :---- | :---- |
| Desktop runtime | **Electron** | Required by PRD §2.1; provides cross-platform native file I/O and single-file project model |
| UI framework | **React** | Industry standard for component-based UI; good ecosystem for MUI |
| UI component library | **MUI (Material UI)** | Consistent design system; supports dark/light theme switching out of the box |
| Language | **TypeScript** | Throughout main and renderer processes; enforces type safety across IPC boundary |

### 2.2 Data Layer

| Layer | Choice | Rationale |
| :---- | :---- | :---- |
| Embedded database | **SQLite** (via `better-sqlite3`) | Self-contained; no server; maps directly to the `.anvil` single-file requirement (PRD §2.2) |
| Query access | **Raw SQL via `better-sqlite3`** | Avoids ORM magic; keeps explicit control over transactions and migration steps |
| Migration runner | **Custom TypeScript migration runner** | Versioned sequential migration files; non-destructive (PRD §8.6) |

### 2.3 Renderer Layer

| Layer | Choice | Rationale |
| :---- | :---- | :---- |
| State management | **Zustand** | Lightweight; supports per-slice stores; easy to model per-record undo history (Phase 2) |
| Routing | **React Router (hash mode)** | Works cleanly within Electron renderer without a server |
| Charting | **Recharts** | Stat growth curve visualization (F-CL-02); lightweight and React-native |
| Formula evaluation | **Custom interpreted evaluator** | See §8; evaluated in main process for isolation; debounced and cached |

### 2.4 Export System

| Layer | Choice | Rationale |
| :---- | :---- | :---- |
| Template engine | **Nunjucks** | Recommended by PRD; supports loops, conditionals, filters, and nested data; sandboxed in main process |

### 2.5 Build & Distribution

| Layer | Choice | Rationale |
| :---- | :---- | :---- |
| Bundler | **Vite** | Fast HMR for renderer development; integrates well with Electron via `electron-vite` |
| Packager | **Electron Forge** or **electron-builder** | Cross-platform builds for Windows, macOS, Linux (PRD §2.3) |

---

## 3. Application Architecture

### 3.1 Process Model

Anvil follows Electron's standard main/renderer split with a strict context bridge. No Node.js APIs are exposed directly to the renderer.

```
┌─────────────────────────────────────────────────────────┐
│  Renderer Process (React / MUI / Zustand)               │
│  - UI rendering, user interaction, state management      │
│  - Communicates via IPC only (no direct DB access)       │
└────────────────────────┬────────────────────────────────┘
                         │  IPC (context bridge)
┌────────────────────────┴────────────────────────────────┐
│  Main Process (Node.js / TypeScript)                    │
│  - SQLite database access                               │
│  - File I/O (open, save, save-as, auto-save)            │
│  - Formula evaluation                                   │
│  - Export rendering (Nunjucks)                          │
│  - Validation computation                               │
│  - Migration runner                                     │
│  - File lock management (PRD §2.5)                      │
└─────────────────────────────────────────────────────────┘
```

All data reads and writes pass through defined IPC channels. The renderer never holds a database connection.

### 3.2 IPC Channel Organization

Channels are grouped by domain. Each channel follows the pattern `domain:operation`. The full channel surface is defined during epic breakdown, but the functional groups are:

- `project:*` — open, create, save, auto-save, close, recovery
- `classes:*` — CRUD, stat growth, derived stat formulas
- `abilities:*` — CRUD, assignments
- `items:*` — CRUD, category management
- `recipes:*` — CRUD, ingredient management
- `npcs:*` — CRUD, class inheritance, loot table assignment, ability assignment
- `loot-tables:*` — CRUD, entry management
- `validation:*` — run validation, get current errors, get severity config
- `export:*` — render preview, execute export, manage templates
- `settings:*` — read/write project settings, read/write app settings

### 3.3 File Locking

On project open, the main process acquires an exclusive lock on the `.anvil` file (PRD §2.5). A second Anvil instance attempting to open the same file is blocked with a user-readable error. The lock is released on project close or application exit.

---

## 4. Project File & Data Architecture

### 4.1 File Format

The project file uses a `.anvil` extension and is a SQLite database internally. It is self-contained and portable — all project data, settings, schema definitions, and template overrides live inside the single file. No companion files or folders are required (PRD §2.2).

### 4.2 Schema Organization

The database schema is organized into four logical layers:

**Layer 1 — Project Metadata**
Single-row configuration: project name, game title, schema version, created/updated timestamps, max level, and project-level settings (e.g., soft-delete reference severity).

**Layer 2 — Meta-Layer (Project Schema Definitions)**
The configurable lists that define the project's vocabulary: stat definitions, rarity tiers, affinities, item categories, NPC types, crafting stations, crafting specializations, derived stat definitions. These are the rows that populate dropdowns and drive validation.

**Layer 3 — Custom Field Definitions**
Per-category and per-NPC-type field schema (EAV definitions): field name, type, default value, required flag, searchable flag. Stored separately from domain records so they can be managed independently.

**Layer 4 — Domain Records**
The actual game data: classes, abilities, items, crafting recipes, NPCs, loot tables, and all their sub-tables (stat growth entries, ability assignments, recipe ingredients, loot table entries, etc.).

### 4.3 Schema Versioning & Migration

Every `.anvil` file carries a `schema_version` integer in the project metadata table. On open, the main process compares the file's version against the application's expected version. If the file is older, a migration is offered. Migration is non-destructive: a copy of the original file is created and preserved before the upgrade is applied to the copy (PRD §8.6). The migrated copy becomes the active project.

---

## 5. Domain Model

Anvil has six first-class data domains. Each domain has its own list view, editor, and full CRUD lifecycle. All six contribute records to the export system.

### 5.1 Character Classes (F-CL-01)

The definition of playable character archetypes. Each class carries:
- Core identity fields: name, display name, export key, description
- Primary stat block: per-stat growth curves across the project's configured level range
- Derived stat definitions with formulas (see §8)
- Ability references: links to Ability domain records (via immutable ID)
- Custom fields: category-specific EAV fields defined in the project schema
- Class-level metadata: resource multipliers and other scalar fields usable as formula variables

### 5.2 Abilities (F-AB-01)

Standalone, reusable game ability definitions. Abilities are **first-class project-level records**, not sub-records of classes. Each ability carries:
- Core identity fields
- Typed fields: ability type, resource cost, cooldown, stat modifiers, description
- Assignable to: Character Classes (F-CL-03) and NPCs (F-NP-04) via junction tables
- Custom fields

The key constraint: ability records exist independently of any class or NPC. Assigning an ability to a class or NPC creates a reference; deleting an ability triggers a validation error on all records that reference it (F-AB-03).

### 5.3 Items (F-IT-01)

Collectible and equippable objects. Each item carries:
- Core identity fields
- Category (from project's item category list, which includes the "Blueprint" category for learnable recipe items)
- Rarity tier reference
- Custom fields per category (EAV)

Items are referenced by: Crafting Recipe ingredients, Crafting Recipe outputs, and Loot Table entries.

### 5.4 Crafting Recipes (F-CR-01)

Defines item production logic. Each recipe carries:
- Core identity fields
- Output item reference + quantity
- Ingredient list: item references + quantities
- Crafting station reference
- Crafting specialization reference (optional)

All item references use immutable IDs. Ingredient resolution validates that all referenced items are active records (F-CR-02).

### 5.5 NPCs (F-NP-01)

Enemy and non-combat characters. NPC records are typed (each type has a custom field schema). Each NPC carries:
- Core identity fields
- NPC type (from project's NPC type list)
- Combat stats (direct entry or inherited, see below)
- Class inheritance: zero or more class references at a specified level (F-NP-02)
- Loot table reference (F-NP-03)
- Ability references (F-NP-04)
- Custom fields per NPC type (EAV)

**Class-based stat inheritance** is additive: stats from multiple classes at their respective levels are summed. The NPC editor shows inherited stat values with visual distinction from manually overridden values.

### 5.6 Loot Tables (F-LT-01)

Standalone drop probability definitions. Loot tables are **first-class project-level records**, not sub-records of NPCs. Each loot table carries:
- Core identity fields
- A list of loot entries, each containing:
  - Item reference (immutable ID)
  - Integer drop weight (not a float probability — weights are normalized to percentages at display time per F-LT-02)
  - Min/max quantity
  - Optional conditional flags

Loot tables are assigned to NPCs by reference. A loot table can be assigned to multiple NPCs. The NPC editor shows a summary of the assigned loot table inline.

---

## 6. Identity & Reference Model

This model is the foundation of all cross-domain references. It maps directly to PRD §4.2.

### 6.1 Three-Part Identity

Every domain record has exactly three identity fields:

| Field | Purpose | Editable? |
| :---- | :---- | :---- |
| **Internal ID** | System-generated, globally unique (UUID or auto-increment). Used in all foreign key relationships. Never shown to the user. | Never |
| **Display Name** | Human-readable label shown in the UI. | Yes |
| **Export Key** | User-facing identifier written into export output. Defaults to a slugified form of the display name on creation; editable by the user. | Yes |

### 6.2 Reference Storage

Cross-domain references always store the internal ID. They never store display names or export keys. This means:
- Renaming a record never breaks any reference
- Soft-deleting a record does not remove references — they are flagged by the validation system instead
- Export templates can choose to resolve to either the internal ID or the export key (F-EX-06)

### 6.3 Reference Display

The UI resolves internal IDs to display names at render time via a preloaded lookup cache. If a referenced record is soft-deleted, the display shows the name with a visual indicator (e.g., strikethrough or warning badge).

### 6.4 Record Metadata

All domain records carry:
- `created_at` timestamp
- `updated_at` timestamp (updated on every save, supports last-modified display per PRD §4.2.5)
- `deleted_at` timestamp (null = active; non-null = soft-deleted, see §10)

---

## 7. Custom Fields System

Maps to PRD §4.1. Custom fields allow each project to extend the default schema of items (per category) and NPCs (per type) without code changes.

### 7.1 Field Schema Definition

Custom field schemas are defined at the project level, keyed by item category or NPC type. Each field definition specifies:

- **Field name** (label shown in UI)
- **Field type**: `text`, `integer`, `decimal`, `boolean`, `enum`
- **Default value** (optional)
- **Required flag**: whether the field must be non-empty to pass validation
- **Searchable/filterable flag**: controls whether the field participates in list view filtering

**Constraint:** Field types may not be changed after creation. Enum options may not be removed if any record currently uses that value. These rules are enforced at the application layer.

**Constraint:** Custom fields do **not** support cross-domain reference types. All fields are scalar or enum values only. (This resolves the contradiction in the prior architecture document, which introduced `stat_ref`/`affinity_ref`/`rarity_ref` field types that contradict PRD §4.1.2.)

### 7.2 Field Value Storage

Field values are stored using an EAV (Entity-Attribute-Value) pattern: a separate table holds one row per (record, field) pair. At read time, the main process assembles field values into a flat object alongside the core record fields before handing data to the renderer.

### 7.3 Export Availability

All custom field values are automatically available in export templates. The export context includes the flattened field values as a property map on each record object.

---

## 8. Formula Engine

Maps to PRD F-CL-01a and F-CL-01b.

### 8.1 Purpose

The formula engine allows users to define derived stats (e.g., Max HP, Attack Power, Mana) as expressions over primary stats and other derived stats. Formulas are defined at the project level (which derived stats exist and their default formulas) and may be overridden per class.

### 8.2 Formula Language

- **Operators:** `+`, `-`, `*`, `/`, parentheses
- **Math functions:** `min`, `max`, `floor`, `ceil` (extensible; documented if extended)
- **Variable scope:** primary stats (by name), other derived stats (no cycles), class-level metadata fields (e.g., resource multipliers)
- **Cyclic dependencies** between derived stats are invalid and are caught at save time

### 8.3 Execution Model

- **Where it runs:** Main process. The renderer sends formula strings and variable bindings via IPC; the main process evaluates and returns results. This isolates evaluation from the renderer and allows sandboxing.
- **Debounced:** Formula evaluation is triggered by user input with a short debounce delay to avoid evaluating on every keystroke.
- **Cached:** Evaluation results are cached by (formula, variable hash). Cache is invalidated when the formula or any variable changes.
- **Interpreted:** Not compiled. Formulas are parsed and walked at evaluation time.

### 8.4 Error Handling

- **Syntax errors** (malformed expression): block save of the record containing the formula. Error surfaced inline in the formula field.
- **Runtime errors** (e.g., divide-by-zero): do not block save; block export. Surfaced by the validation system as an Error severity issue.

### 8.5 Output Configuration

Each derived stat definition specifies:
- **Output type:** `integer` or `float`
- **Rounding mode:** `floor`, `round`, or `none` (only applicable when output type is integer)

---

## 9. Validation System

Maps to PRD §5.8.

### 9.1 Design Approach

Validation is computed on-demand (not persisted in a separate table). The main process runs the full validation pass when:
- A record is saved
- Export is initiated
- The user explicitly opens the Validation Panel

The result is a list of validation issues, each carrying: domain, record ID, display name, field (optional), severity, and message.

### 9.2 Validation Checks

The validation pass covers:

| Check | Trigger |
| :---- | :---- |
| Broken cross-domain references | A referenced record's internal ID no longer exists |
| References to soft-deleted records | A referenced record is soft-deleted (severity: project-configurable) |
| Required custom field empty | A required EAV field has no value |
| Formula syntax error | A derived stat formula is malformed |
| Formula runtime error | A derived stat formula produces a runtime error (e.g., divide-by-zero) |
| Cyclic derived stat dependency | Two or more derived stats reference each other in a loop |
| Enum value in use before removal | Attempt to remove an enum option that a record currently uses |

### 9.3 Severity Levels

Three severity levels (PRD F-VL-05):

| Severity | Blocks Save? | Blocks Export? |
| :---- | :---- | :---- |
| **Error** | Only for syntax errors | Yes |
| **Warning** | No | No |
| **Info** | No | No |

References to soft-deleted records use a configurable severity (Error or Warning, set at project level).

### 9.4 Validation Panel (F-VL-02)

A global panel (accessible from any view) lists all current validation issues grouped by domain. Each issue links to the affected record. The panel reflects the most recent validation pass result.

### 9.5 Export Gate (F-VL-03)

Export cannot proceed if any active Error-severity issues exist. The export flow checks validation before rendering templates and surfaces a summary of blocking errors if the gate fails.

### 9.6 Inline Error Display

Record editors show field-level and record-level validation indicators. Broken reference fields show the referenced record's name with a visual error state.

---

## 10. Soft-Delete & Record Lifecycle

Maps to PRD F-VL-04.

### 10.1 Default Delete Behavior

All domain record deletions are soft by default. A soft-deleted record has a non-null `deleted_at` timestamp. It is excluded from all normal list views and cross-domain selection dropdowns, but its data is preserved in the database.

Hard delete (permanent removal) is only available from archive views and the global recycle bin.

### 10.2 Archive Views

Each domain list view has an "Archived" toggle or tab that shows soft-deleted records for that domain only. From the archive view, users can:
- **Restore** a record (clears `deleted_at`)
- **Permanently delete** a record (hard delete from database)

### 10.3 Global Recycle Bin

A single cross-domain view shows all soft-deleted records from all domains. Actions:
- **Restore** individual records
- **Permanently delete** individual records
- **Empty Trash** (permanently delete all soft-deleted records across all domains, with confirmation)

### 10.4 Reference Behavior on Soft-Delete

When a record is soft-deleted, existing references to it are not removed. Instead, the validation system surfaces an issue with the configurable severity (Error or Warning). The UI shows the reference as a warning state in the editor.

### 10.5 Bulk Delete Impact Summary (PRD v1.4)

When a user initiates a bulk soft-delete, the application computes and displays an impact summary before confirmation: how many records will be soft-deleted and how many existing references will be affected. The user must explicitly confirm after reviewing the summary.

---

## 11. Export System

Maps to PRD §5.9.

### 11.1 Template Engine

Export uses **Nunjucks** as its template language. Templates support: variable interpolation, loops, conditionals, custom filters, and nested data access. Template rendering runs in the main process.

### 11.2 Export Context

Each export operation assembles a context object containing all active (non-soft-deleted) records from all six domains, plus project meta-layer data. The context structure:

```
{
  project: { name, game_title, max_level, ... },
  meta: { stats, rarities, affinities, item_categories, npc_types, crafting_stations, ... },
  classes: [ { id, display_name, export_key, stats, derived_stats, abilities, custom_fields }, ... ],
  abilities: [ { ... }, ... ],
  items: [ { ... }, ... ],
  recipes: [ { ... }, ... ],
  npcs: [ { ... }, ... ],
  loot_tables: [ { ... }, ... ]
}
```

Custom fields for each record are flattened into a `custom_fields` property map.

### 11.3 Identifier Selection (F-EX-06)

Export templates choose per-reference whether to output the internal ID or the export key. A built-in Nunjucks filter (e.g., `| export_key`) resolves a stored internal ID to the record's current export key. The default (unfiltered) reference outputs the export key; the internal ID is available as a separate field on each record object.

### 11.4 Built-In Presets (F-EX-02)

Three built-in non-editable presets:

| Preset | Output Format |
| :---- | :---- |
| **Nested JSON** | Hierarchical JSON with nested sub-objects for referenced records |
| **Flat JSON** | Flat JSON with all reference fields resolved to export keys |
| **CSV** | One file per domain, references resolved to export keys |

Users may also create, edit, and save custom templates.

### 11.5 Selective Export (F-EX-03)

Export scope can be:
- **Full project** — all active records across all domains
- **Single domain** — all active records from one domain
- **Record selection** — a user-selected subset of records from one domain

### 11.6 Dependency Resolution (F-EX-05)

When exporting a record selection or single domain, the export system automatically includes direct (depth-1) dependencies: records referenced by the selected records that live in other domains. Dependencies are included in the export context but not necessarily in the top-level output unless the template accesses them.

### 11.7 Export Preview (F-EX-04)

Before writing to disk, the user can preview the rendered export output in a read-only text view. Preview uses the same rendering path as the actual export.

### 11.8 Template Error Handling (F-EX-07)

If a Nunjucks template contains a rendering error, the export is blocked. The error view shows the template name, the error message, and a stack trace. The error does not crash the application.

---

## 12. UI Architecture

### 12.1 Application Shell

The application shell consists of:
- **Title bar** with project name and save status indicator
- **Sidebar navigation** with entries for each of the six domain editors, plus Dashboard, Validation Panel, Recycle Bin, Export, and Settings
- **Main content area** which renders the active page
- **Global notification area** for auto-save confirmations, validation warnings, and export status

### 12.2 Page Types

| Page Type | Examples |
| :---- | :---- |
| **Domain List View** | Classes, Abilities, Items, Recipes, NPCs, Loot Tables |
| **Domain Editor** | Class Editor, Ability Editor, Item Editor, etc. |
| **Settings Page** | Project Settings, Application Settings |
| **Utility Pages** | Dashboard, Validation Panel, Recycle Bin, Export |

### 12.3 Editing Mode

The application supports two editing modes, configurable as an application-level preference (PRD §5.10 v1.4):

- **Modal-first (default):** clicking a record in a list view opens it in a modal dialog overlay
- **Full-page:** clicking a record navigates to a dedicated full-page editor view

Both modes use the same underlying editor component.

### 12.4 Domain List Views

All six domain list views share common capabilities (PRD §4.3):
- Searchable by display name (and any field flagged as searchable in custom field schema)
- Filterable by relevant type/category/rarity fields
- Sortable columns
- Multi-select for bulk operations (Phase 2)
- Archive toggle to show soft-deleted records

### 12.5 Theme System

Three theme options (PRD §5.10 v1.1): Dark (default), Light, and Custom. Custom theme is loaded from a user-provided JSON file specifying hex color values (with optional opacity). Theme changes take effect on manual refresh or application restart. Theme selection is an application-level (not project-level) preference.

### 12.6 Stat Growth Visualization (F-CL-02)

The Class Editor includes a chart view of primary stat growth curves across the full project level range. The chart is rendered using Recharts and updates in real time as the user edits growth values. Derived stat breakpoint display (F-CL-02a) shows computed derived stat values at key levels.

---

## 13. State Management

### 13.1 Store Organization

Zustand stores are split by concern:

| Store | Responsibility |
| :---- | :---- |
| `project.store` | Active project identity, save state, dirty flag |
| `domain.store` (per domain) | Loaded list records and active editor record for each domain |
| `validation.store` | Current validation issue list, last-validated timestamp |
| `ui.store` | Sidebar state, editing mode preference, theme preference, modal open/close state |
| `export.store` | Active template selection, export scope, preview output |
| `settings.store` | Application-level settings (loaded on startup, persisted to OS config) |

### 13.2 Data Flow

1. User action in renderer triggers IPC call to main process
2. Main process executes database operation
3. Main process returns result to renderer via IPC response
4. Renderer updates Zustand store with new data
5. React components re-render from store

Domain stores do not hold the full database — they hold the currently loaded page of records and the active editor record. List views load their record set on mount.

### 13.3 Undo / Redo (Phase 2, F-PM-06)

Undo/redo operates at **per-record editor scope**. The `domain.store` for each domain maintains a history stack of record state snapshots. Rapid edits are batched via debounce before a snapshot is committed. History is session-scoped (not persisted to the database). Undo/redo does not apply across records or globally.

---

## 14. Project File Lifecycle

### 14.1 Create New Project

User provides a project name, game title, and save location. A new `.anvil` SQLite file is created at that path with the initial schema applied and default meta-layer data seeded (default rarity tiers, default item categories, etc.). Optionally, a project template populates initial stat definitions, level range, and other defaults.

### 14.2 Open Project

The main process opens the SQLite file, checks `schema_version`, offers migration if needed, acquires the file lock, and notifies the renderer that a project is active.

### 14.3 Auto-Save (F-PM-04)

The main process runs an interval-based timer (default: every few seconds, configurable in application settings). If the project has unsaved changes (dirty flag is set), it performs a save. Save uses atomic write semantics: changes are written to SQLite's WAL and then committed, preventing partial writes on crash. The save status indicator in the title bar reflects the current state.

### 14.4 Manual Save & Save-As

Manual save commits all pending changes. Save-as copies the current `.anvil` file to a new location and switches the active file to the copy.

### 14.5 Recovery Mode (PRD v1.4)

If the application detects a corrupted `.anvil` file on open (SQLite integrity check fails), it enters recovery mode: it attempts to read as much data as possible and presents the user with a partial recovery option.

### 14.6 Close & Lock Release

On project close or application exit, the file lock is released. If there are unsaved changes, the user is prompted to save before close.

---

## 15. Non-Functional Requirements Mapping

| NFR | PRD Reference | Implementation Approach |
| :---- | :---- | :---- |
| Performance: load ≤500ms, operations ≤100ms for up to 1,000 records/domain | §8.1 | SQLite indexes on frequently queried columns; list views load paginated subsets |
| Reliability: atomic saves, no data loss on crash | §8.2 | SQLite WAL mode; auto-save; atomic commit pattern |
| Single-instance file locking | §2.5 | OS-level file lock held by main process; enforced on open |
| Cross-platform: Windows, macOS, Linux | §2.3 | Electron + Electron Forge cross-platform build targets |
| Offline-first | §2.4 | No network calls at runtime; all data in local `.anvil` file |
| Open file format (internal: SQLite) | §2.2 | SQLite is an open, well-documented, widely supported format |
| Accessibility: keyboard navigability, WCAG AA contrast | §8.4 | MUI components with proper ARIA labels; keyboard focus management |
| Portability: project file usable across platforms | §8.5 | SQLite files are cross-platform binary compatible |
| File versioning & non-destructive migration | §8.6 | schema_version field; migration copies original before upgrading |

---

## 16. Phase Alignment

The PRD defines two delivery phases. This section maps each phase's deliverables to the architectural components above.

### Phase 1 — Foundation

**Goal:** A working single-project tool covering Classes, Abilities, Items, and Crafting Recipes with basic validation and auto-save.

Key architecture components required for Phase 1:
- Full application shell, navigation, and project lifecycle (§3, §14)
- SQLite schema with migration runner (§4)
- Identity & reference model for all records (§6)
- Class domain: CRUD, primary stat growth, derived stat formulas, ability references (§5.1, §8)
- Ability domain: full CRUD, reusable across classes (§5.2)
- Item domain: CRUD, rarity, custom fields per category (§5.3)
- Crafting Recipe domain: CRUD, ingredient resolution (§5.4)
- Custom fields system: field definition, EAV storage, searchable flag (§7)
- Formula engine: parse, evaluate, debounce, cache, syntax error handling (§8)
- Validation system: referential integrity, required fields, formula errors, inline display, validation panel (§9)
- Auto-save with atomic writes (§14.3)
- Soft-delete infrastructure: `deleted_at` column on all domain tables (§10) — archive views are Phase 2, but the column must exist from the start

**Explicitly deferred to Phase 2 from this list:**
- NPC and Loot Table domains
- Soft-delete archive views and recycle bin
- Bulk operations
- Undo/redo
- Export system
- Multi-class comparison view
- Theme customization

### Phase 2 — Full Domains & Export

**Goal:** Complete all six domains; add export, archive/recycle bin, bulk operations, undo/redo, and full validation lifecycle.

Key architecture components added in Phase 2:
- NPC domain: CRUD, NPC types, class-based stat inheritance (additive), loot table assignment, ability assignment (§5.5)
- Loot Table domain: CRUD, integer weight system, drop percentage visualization, item resolution (§5.6)
- Export system: template engine, built-in presets, selective export, dependency resolution, identifier selection, preview, export gate (§11)
- Soft-delete archive views per domain and global recycle bin (§10.2, §10.3)
- Bulk operations: multi-select, bulk soft-delete with impact summary, bulk restore (§10.5)
- Undo/redo: per-record history in domain stores (§13.3)
- Theme customization: custom JSON theme loading (§12.5)
- Multi-class comparison view (F-CL-04)
- Application settings page with all configurable options

---

*End of Document*

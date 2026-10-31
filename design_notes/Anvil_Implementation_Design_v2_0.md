# Anvil — Implementation Design

*Flutter rewrite (0.2.0)*

| Field | Value |
| :---- | :---- |
| Version | 2.0 |
| Status | Current |
| Date | 2026-10-31 |
| Supersedes | `Anvil_Implementation_Design_v1_0.md` (Electron). It stays the porting reference until cutover (ANVL-169). |
| Ticket | ANVL-155 |
| Jira epics | ANVL-146, ANVL-147, ANVL-148, ANVL-149, ANVL-150, ANVL-157 |

---

## Table of Contents

1. [Document purpose](#1-document-purpose)
2. [Product constraints](#2-product-constraints)
3. [Technology stack](#3-technology-stack)
4. [Application architecture](#4-application-architecture)
5. [Project file and SQLite access](#5-project-file-and-sqlite-access)
6. [Repository boundary](#6-repository-boundary)
7. [Domain model and record rules](#7-domain-model-and-record-rules)
8. [State management and the save model](#8-state-management-and-the-save-model)
9. [Formula engine](#9-formula-engine)
10. [Validation](#10-validation)
11. [Export engine](#11-export-engine)
12. [Project lifecycle](#12-project-lifecycle)
13. [Application shell and UI](#13-application-shell-and-ui)
14. [Settings and logging](#14-settings-and-logging)
15. [Packaging and release](#15-packaging-and-release)
16. [Testing strategy](#16-testing-strategy)
17. [Future cloud](#17-future-cloud)
18. [Electron-era decisions](#18-electron-era-decisions)
19. [Proposed ticket breakdown](#19-proposed-ticket-breakdown)

---

## 1. Document purpose

This document defines the architecture of the Flutter rewrite of Anvil, released as 0.2.0, and records the reason for each choice. It is complete enough to decompose into tickets, but it avoids low-level API: it names the interfaces, rules and contracts that tickets build to, not the method bodies.

**Source of truth.** The Electron code base at 0.1.6 is the functional source of truth: what the product does is what 0.1.6 does. The PRD (`archive/Anvil_PRD_v1_4.md`) is disregarded. A features-and-functions document will be written closer to 1.0.0. Where this document states a behavior, it is the 0.1.6 behavior unless §2.1 lists it as a change.

**Inputs.** The decisions draw on two spikes, each with a `FINDINGS.md` on its branch: ANVL-151 (export template engine, `v0.2.0/ANVL-151-template-engine-spike`) and ANVL-158 (record save prototype, `v0.2.0/ANVL-158-save-model-prototype`), and on the state management and save model decisions of ANVL-118 and ANVL-157.

**Conventions.** "The core" is the pure-Dart package `packages/anvil_core`; "the app" is the Flutter package `anvil` at the repository root. A point marked "(derived from `<file>`)" was taken from the Electron code rather than from a recorded decision, so it can be checked against that file.

---

## 2. Product constraints

| Constraint | Detail |
| :---- | :---- |
| Repository | Same repo. The rewrite accumulates on `v0.2.0/main` (cut from `main` on 2026-10-31); topic branches PR into it. |
| Project files | Same `.anvil` SQLite files. The schema and the seven migrations are kept, and a file created by any 0.1.x release opens unchanged (§5.7). |
| Platforms | Windows and Linux only. |
| Electron line | 0.1.6 (shipped 2026-10-11) is the final Electron release; no new Electron feature work. `src/`, `package.json` and the Electron tooling stay untouched as the porting reference until cutover (ANVL-169), then they are removed. |

### 2.1 Behavior changes from 0.1.6

0.2.0 ports 0.1.6 behavior. These are the only intended differences; each is explained in the section named.

| Change | Section |
| :---- | :---- |
| Each record saves on its own, in one transaction; project-level save, the dirty flag, auto-save and its dashboard countdown are gone. | §8.5 |
| The class editor saves stat growth, derived stat overrides, metadata and ability assignments with the class (one Save) instead of per panel. Ability and class assignments on classes and NPCs become undoable. | §8.2 |
| Custom templates that use Nunjucks features outside the supported subset are disabled until edited; they are never rewritten. | §11.5 |
| The custom-template sandbox escape of 0.1.6 is closed. | §11.7 |
| Export and project-wide validation see saved records only; unsaved drafts are not included. | §10, §11.9 |
| Native OS window frame instead of the frameless custom title bar. | §13.3 |
| Build-time telemetry is not ported. | §13.8 |

---

## 3. Technology stack

| Layer | Choice | Rationale |
| :---- | :---- | :---- |
| SDK | **Flutter 3.47.5** (Dart 3.13), pinned in `.fvmrc` | Same pin as the org CI and `forge_ui`, so local and CI builds match. |
| UI toolkit | **Flutter Material 3 + `forge_ui`** (git dependency pinned to a tag, `v0.2.1` today) | Org theme, tokens, bundled fonts and shared widgets (§13.1). |
| State management | **`flutter_riverpod` ^3.4**, no code generation | Notifier families fit one draft per record; explicit providers, no `build_runner` (§8.1). |
| Routing | **`go_router` ^18** | A shell route for sidebar and app bar, one route per page (§13.2). |
| Database | **`sqlite3` ^3.8**, SQLite bundled by its build hooks, raw SQL | Inherited schema must stay byte-compatible; no ORM, no codegen (§5). |
| Charts | **`fl_chart` ^1.3** | Replaces Recharts for the stat growth chart (§13.6). |
| File dialogs | **`file_selector`** (Flutter team plugin, Linux and Windows) | Open, save and folder dialogs that Electron's `dialog` module provided (derived from `project-service.ts`, `export.handlers.ts`). |
| App directories | **`path_provider`** | Application support directory for settings, recent projects and logs. |
| Links and folders | **`url_launcher`** | Replaces `shell.openExternal` and `shell.openPath` (derived from `ipc-channels.ts`). |
| Template engine | **Purpose-built, in the core** | Nunjucks-compatible subset, safe by construction (§11). |
| Formula engine | **Ported, in the core** | Same grammar and messages as 0.1.6 (§9). |
| Packaging | **Org `release-flutter.yml`** plus an installer script (ANVL-167) and a Linux workflow (ANVL-168) | §15. |

Not used, on purpose: Drift (§5.3), `sqlite3_flutter_libs` (end-of-life), `window_manager` (§13.3), `google_fonts` (fonts come from `forge_ui`), an embedded JavaScript runtime (§11.1), and code generation of any kind. `path_provider`, `file_selector` and `url_launcher` are Flutter plugins, so they live in the app. The core receives the paths it needs (settings file, log directory, recent-projects file) as arguments, which follows from the core/UI rule in §4.3.

---

## 4. Application architecture

### 4.1 One process

Electron 0.1.6 split the app into a React renderer and a Node main process joined by 156 typed IPC channels in 18 groups (derived from `src/shared/ipc-channels.ts`). Flutter runs one process and one Dart program, so that split has nothing left to protect. The main-process responsibilities (database, files, migrations, project lock, formula evaluation, validation, export, settings files, logging) become the core package, which the app calls directly as Dart APIs. There is no serialization boundary and no channel names; the `domain:operation` channel groups become methods on repository and service interfaces (§6). Where Electron relied on the process boundary to keep long or untrusted work off the UI, 0.2.0 uses isolates (§4.4).

```
┌──────────────────────────────────────────────────────────────┐
│ App: Flutter package `anvil` (repo root)                     │
│  lib/app        shell, routing, theme, menu, settings        │
│  lib/features   list pages, editors, editor notifiers        │
│  Riverpod providers, root overrides in lib/app/providers     │
└───────────────────────────────┬──────────────────────────────┘
                                │ Dart calls on interfaces (Futures)
┌───────────────────────────────┴──────────────────────────────┐
│ Core: pure Dart `packages/anvil_core`                        │
│  repositories (interfaces + sqlite_* implementations)        │
│  project lifecycle, formula, validation, export, settings,   │
│  logging, drafts and DraftHistory                            │
│  ProjectDatabase ── sqlite3 ── <project>.anvil (WAL)         │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 Repository layout

```
pubspec.yaml             workspace root; app package `anvil`; test/, linux/, windows/ beside lib/
lib/main.dart            error zones, logging hooks, ProviderScope
lib/app/                 providers.dart (root overrides), shell/, routing/, theme/ (exists),
                         settings/ (app and project settings dialogs), menu/ (menu, shortcuts)
lib/features/            classes/ abilities/ items/ recipes/ npcs/ loot_tables/
                         dashboard/ validation/ recycle_bin/ export/ project/
packages/anvil_core/
  lib/anvil_core.dart    the only public entry point
  lib/src/db/            ProjectDatabase, pragmas, migration runner, migrations 001 to 007
  lib/src/domain/        records, drafts, meta, custom field and settings types, DraftHistory
  lib/src/repositories/  interfaces and sqlite_* implementations
  lib/src/project/       create, open, close, lock, recents, folder structure, backup, history
  lib/src/formula/       parser, evaluator, cycle detection
  lib/src/validation/    check families, project and record runners
  lib/src/export/        js_compat, presets, template renderer, context assembler, service
  lib/src/settings/      app settings model, custom theme parser (exists)
  lib/src/logging/       file logger and rotation
  test/, test/fixtures/
```

Each feature folder holds its list page, editor page, editor notifier and the providers that serve them. App-side providers live beside the feature they serve; only the root overrides live in `lib/app/providers.dart`.

### 4.3 Boundary rules

- The core never imports `package:flutter`, and it does not use Riverpod either. Its `pubspec.yaml` declares neither, so such an import fails analysis. Everything in the core runs under plain `dart test`.
- The app depends on the core, never the reverse.
- The core's public API is `lib/anvil_core.dart` only. The app never imports `package:anvil_core/src/...`; the `implementation_imports` lint flags it.
- SQL and `sqlite3` types stay inside the core's `db`, `repositories`, `project`, `validation` and `export` libraries. The public API exports interfaces, domain types, drafts and services, never a database handle.
- `DraftHistory<T>`, the draft types and the save-blocking rules live in the core. The `AsyncNotifier`s that hold drafts live in the app.

### 4.4 Isolates

`sqlite3` handles cannot be sent between isolates, so a background isolate that needs data opens its own read-only connection to the same file. WAL mode lets those readers run while the UI isolate writes.

| Work | Where | Why |
| :---- | :---- | :---- |
| Draft edits, single formula evaluations, record saves | UI isolate | Synchronous and fast (microseconds to low milliseconds). |
| Integrity check and migrations on open | Background isolate, before the UI isolate opens its connection | `PRAGMA integrity_check` on a large file would block frames (derived from `project-service.ts`, which ran it synchronously in the main process). |
| Formula batches above 2,000 evaluations | `Isolate.run` on a snapshot of the inputs | §9.2. |
| Project-wide validation | Background isolate | §10.2. |
| Export: gate, context assembly, render | Background isolate | Untrusted templates and large outputs stay off the UI isolate (§11.4). |

---

## 5. Project file and SQLite access

### 5.1 Choice

**`sqlite3` ^3.8** (3.8.0 on pub.dev, 2026-10) with its native build hooks, which compile SQLite and bundle it into `dart test`, `flutter test` and `flutter build` output on Linux and Windows. ANVL-158 confirmed this on Linux: `bundle/lib/libsqlite3.so` (1.8 MB) with no system dependency. There is no system `libsqlite3` requirement (Fedora ships `libsqlite3.so.0` without the unversioned name unless the -devel package is installed, so the hook's `source: system` mode would fail to load) and no `sqlite3_flutter_libs`, which is end-of-life (`0.6.0+eol`: "Not used anymore, update to version 3.x of package:sqlite3"). The acceptance criterion's "sqlite3 + sqlite3_flutter_libs" option therefore reduces to `sqlite3` alone. Access is raw SQL with prepared statements, with no ORM and no code generation.

### 5.2 Criteria

| Criterion | `sqlite3`, raw SQL | Drift |
| :---- | :---- | :---- |
| (a) One-for-one port of the 7 migrations | SQL strings copied verbatim into Dart files: same statements, same order, one transaction per migration. | Possible through `customStatement`, but Drift models the schema as generated tables; hand-written migrations fight that model. |
| (b) Existing `.anvil` files open unchanged | The runner reads and writes `schema_migrations` exactly as Electron does. | Possible, but the generated table classes would have to be reverse-engineered to match the inherited schema, and Drift's `schemaVersion` and `MigrationStrategy` (on `PRAGMA user_version`) duplicate the `schema_migrations` table Electron already keeps. |
| (c) Testable without Flutter | Pure Dart under `dart test`, no generated code. | Pure Dart through `NativeDatabase`, but generated code must be kept current. |
| (d) Cloud path | Neither avoids SQLite on the device. Lock-in is controlled by the repository boundary (§6) and by keeping the project file self-contained, so typed queries buy nothing here. | Same; its stream queries do not make a remote backend easier to add behind the interfaces. |
| (e) Toolchain weight | None beyond the package. | `build_runner` and `drift_dev` on every core change, plus generated files in every review. |
| (f) Org precedent | None needed. | Cheesy Scribe uses Drift for a greenfield schema it owns. Anvil's schema is inherited and must stay byte-compatible, so the precedent does not transfer. |

### 5.3 Drift: considered and rejected

Drift loses on (a), (b) and (e), ties on (c) and (d), and its precedent (f) does not apply. The decision would be reopened for a greenfield schema (a new product, or a clean-slate project format in a later major version) or for a sync layer that wants Drift's stream queries and change tracking.

### 5.4 Connections, pragmas and values

- Every connection runs `PRAGMA journal_mode = WAL` and `PRAGMA foreign_keys = ON` on open, as `src/main/db/connection.ts` does. WAL persists in the file; `foreign_keys` is per connection, so background read connections set it too.
- One read-write connection per open project, on the UI isolate, owned by `ProjectDatabase` (§6.4). Background isolates open read-only connections.
- Timestamps are still produced by SQLite (`datetime('now')`, UTC text `YYYY-MM-DD HH:MM:SS`) inside the SQL, never formatted in Dart, so rows written by 0.2.0 match rows written by 0.1.x (derived from `src/main/repositories/*.ts`).
- REAL columns read back as Dart `double`, which matters for export output (§11.3).

### 5.5 Copies and backups

A plain file copy of an open WAL database can miss committed pages that are still in the `-wal` file (ANVL-158 finding 9). Every copy goes through `ProjectDatabase.snapshot(path)`, which runs `VACUUM INTO` (the SQLite backup API is the alternative where a page-level copy is wanted). This covers user backups, Save As, the upgrade copy on open and any future cloud backup. 0.1.6's `backupProject` copied the open file with `copyFileSync` and no checkpoint (derived from `project-service.ts`); the port does not carry that over.

### 5.6 Synchronous driver, asynchronous interface

`sqlite3` is synchronous, and a query on a project of 1,000 records per domain completes in microseconds to low milliseconds. Repository methods still return `Future`s, so moving storage to a background isolate or adding a remote backend later does not change editor code (ANVL-158 finding 11). Edits are ignored while a save is in flight; `DraftHistory.rebase` already keeps a draft that changed during a save, should saves ever become slow.

### 5.7 Migration compatibility contract

| Migration | Creates or changes (derived from `src/main/db/migrations/`) |
| :---- | :---- |
| `001_init` | `project_info` (single row, `id = 1`); meta tables `stats`, `rarities`, `affinities`, `item_categories`, `npc_types`, `crafting_stations`, `crafting_specializations`, `derived_stat_definitions`; domain tables `classes`, `abilities`, `items`, `recipes`, `npcs`, `loot_tables`, each with `created_at`, `updated_at` and `deleted_at`; junctions `class_stat_growth`, `class_ability_assignments`, `recipe_ingredients`, `loot_table_entries`, `npc_class_assignments`, `npc_ability_assignments`; `custom_field_definitions`, `custom_field_values`; `deleted_at` indexes on the six domain tables and a record index on `custom_field_values`. Copies a legacy `project_meta` row when one exists. |
| `002_seed_meta_layer` | Re-runs 001 idempotently, upserts `project_info` (max level 50, soft-delete reference severity `Warning`) and seeds, by fixed id, 7 stats, 5 rarities, 7 item categories, 3 NPC types, 4 crafting stations, 4 crafting specializations and 3 derived stats. |
| `003_class_overrides_and_metadata` | `class_derived_stat_overrides`, `class_metadata_fields`. |
| `004_ability_resource_type` | `ALTER TABLE abilities ADD COLUMN resource_type`. |
| `005_custom_templates` | `custom_templates`. |
| `006_stat_growth_formulas` | `class_stat_growth_formulas`. |
| `007_save_history` | `save_history` (`INTEGER PRIMARY KEY AUTOINCREMENT`, which also creates `sqlite_sequence`). |

The contract the Dart runner keeps:

- `schema_migrations(filename TEXT PRIMARY KEY, applied_at TEXT NOT NULL)` is created if absent, with the same seven filenames, `001_init` to `007_save_history`. `applied_at` is ISO 8601 UTC truncated to milliseconds, matching JavaScript `toISOString()` (Dart's `toIso8601String` would otherwise print microseconds) (derived from `runner.ts`).
- Each pending migration runs in its own transaction together with its `schema_migrations` insert; a failure rolls back and raises `MigrationFailed(filename)`.
- `CURRENT_SCHEMA_VERSION = 7`, the number of migrations. After any migration ran, `project_info.schema_version` is set to 7 with `updated_at = datetime('now')`, as Electron does.
- The SQL is the Electron SQL verbatim, including the `IF NOT EXISTS` clauses, the legacy `project_meta` copy and 002's re-run of 001, and keeps its formatting so the text stored in `sqlite_master` matches.
- Upgrades are non-destructive: a file below version 7 is upgraded as a copy and the original is left unchanged (§12.3).
- 0.2.0 adds no migration. Files written by 0.2.0 therefore stay openable by 0.1.6, and both lines respect each other's lock (§12.5). A migration 008 is a decision for its own ticket, because it ends that two-way compatibility (derived from `project-service.ts`, where 0.1.6 opens any file at version 7 or above without migrating).

### 5.8 Compatibility tests

1. **The 0.1.6 fixture opens unchanged.** `sample-0.1.6.anvil`, generated by the Electron 0.1.6 migrations and repositories through `build-fixture.test.ts` in `~/projects/anvil-spike-fixtures`, is checked into `packages/anvil_core/test/fixtures/` together with its generator and README. It opens with zero pending migrations, and its rows read back through every repository match the known contents and `context-full.json`.
2. **A fresh project has the Electron schema.** A project created by the Dart runner has the same `sqlite_master` (type, name, table name and SQL with whitespace normalized) as the Electron-created `schema-sqlite-master.json`, and the same 002 seed rows.
3. **Each migration matches step by step.** Each migration applied to the previous state matches Electron's state after that migration. This needs the generator extended to dump `sqlite_master` after each of the seven steps; today only the step-7 snapshot exists (derived from the fixture README).

Every test opens a fresh temporary copy of the fixture and checks in `tearDown` that the fixture's bytes are unchanged (the ANVL-158 `FixtureCopy` pattern).

---

## 6. Repository boundary

### 6.1 Rule

Editors, list pages and the draft layer (ANVL-159) depend on repository interfaces only, obtained from providers that are overridden at the root. No SQL, no `sqlite3` type and no database handle crosses the boundary. Methods return `Future`s and take and return domain types and drafts. The transaction and the save history row stay inside the implementation. A cloud backend, a backup hook or a sync layer wraps or replaces the implementation without touching editors.

### 6.2 Interfaces

Each of the six domain repositories has the common operations, which replace the per-domain CRUD channels: `list({mode})` (active, archived or all, ordered by display name, case-insensitive), `countActive()`, `load(id)` returning the draft, `create(input)`, `save(draft)` returning the read-back draft, `duplicate(id)`, `softDelete(id)`, `restore(id)` and `hardDelete(id)`. Get/set channels for junction data collapse into `load` and `save`, because the junction data is part of the draft (§8.2).

| Interface | Replaces (IPC group, channel count) | Domain-specific surface |
| :---- | :---- | :---- |
| `ClassRepository` | `classes:*` (19) | `usedBy(id)` (NPCs). The draft carries stat growth entries, stat growth formulas, ability assignments, derived stat overrides and metadata fields. |
| `AbilityRepository` | `abilities:*` (9) | `usedBy(id)` (classes, NPCs). Stat modifiers are in the draft. |
| `ItemRepository` | `items:*` (9), item side of `custom-fields:get-values`/`set-values` | `usedBy(id)` (recipes, loot tables). Category-scoped custom field values are in the draft. |
| `RecipeRepository` | `recipes:*` (10) | Ingredients are in the draft. |
| `NpcRepository` | `npcs:*` (12), NPC side of custom field values | Class assignments, ability assignments, combat stat overrides and custom field values are in the draft. |
| `LootTableRepository` | `loot-tables:*` (11) | `usedBy(id)` (NPCs). Entries are in the draft. |
| `MetaRepository` | `meta:*` (38) | For each of stats, rarities, item categories, NPC types, crafting stations, crafting specializations and derived stat definitions: `list`, `add`, `update`, `delete` (refused while in use) and `reorder`; `checkInUse(kind, id)`; `loadProjectSettings()` and `saveProjectSettings(draft)`, which commits the scalar settings and the buffered meta lists (ANVL-121) in one transaction (derived from `meta.handlers.ts`). |
| `CustomFieldRepository` | `custom-fields:*` definition channels (4) | `listDefinitions(scope)`, `createDefinition`, `updateDefinition` (field type immutable; enum options in use cannot be removed), `deleteDefinition`, `valueCount`, `usedEnumValues` (derived from `custom-field-definition.repository.ts`). |
| `TemplateRepository` | `export:create-template`, `update-template`, `delete-template`, `list-custom-templates` (4) | `list`, `get`, `create`, `update`, `delete` on `custom_templates`. |
| `SaveHistoryRepository` | `project:get-save-history` | `recent({limit = 50})`, newest first. Rows are written only by `saveTransaction`. |
| `LifecycleRepository` | `lifecycle:*` (6), `project:get-weekly-deltas` | `countDeleted()` per domain, `bulkSoftDelete(domain, ids)`, `bulkRestore`, `bulkHardDelete`, `emptyTrash()`, `computeDeleteImpact(domain, ids)` (port of `src/main/lifecycle/impact.ts`), `weeklyDeltas()`. |

The remaining groups map to services rather than repositories: the rest of `project:*` to `ProjectService` (§12), except `project:get-auto-save-info`, which goes with auto-save; `validation:*` to `ValidationService` (§10), `formulas:*` to the formula functions (§9), `export:preview`, `export:execute` and `export:get-templates` to `ExportService` (§11), and `settings:get-app`/`set-app` to `AppSettingsStore` (§14). `settings:select-folder`, `settings:select-theme-file`, `shell:*` and `app:get-log-path` become app-side plugin calls. `window:*` (3) and `telemetry:flush` are dropped (§13.3, §13.8), and `settings:get-project`/`set-project` were stubs returning nothing in 0.1.6 (derived from `settings.handlers.ts`). The 156 channels are all accounted for.

### 6.3 Interface sketch

```dart
abstract interface class RecipeRepository {
  Future<List<RecipeRecord>> list({RecordListMode mode = RecordListMode.active});
  Future<int> countActive();
  Future<RecipeDraft> load(String id);            // RecordNotFound
  Future<RecipeDraft> create(RecipeCreate input);
  Future<RecipeDraft> save(RecipeDraft draft);    // SaveBlocked, RecordNotFound, DuplicateExportKey
  Future<RecipeDraft> duplicate(String id);
  Future<void> softDelete(String id);
  Future<void> restore(String id);
  Future<void> hardDelete(String id);
}
```

`XRecord` is the read model for list rows; `XDraft` is the editable value (§8.2). Lookups an editor needs (the item list for ingredient pickers, stations, rarities) come from the other repositories' `list` methods and `MetaRepository`, assembled by an app-side provider per editor.

### 6.4 ProjectDatabase and the save transaction

The `Sqlite*Repository` implementations share one `ProjectDatabase` per open project, injected through their constructors. It owns the `sqlite3` handle privately and offers `open`, `openReadOnly`, `close`, `integrityCheck`, `snapshot(path)`, `checkpoint(mode)`, `read(body)` (a read transaction for consistent multi-query reads) and `saveTransaction(description, body)` (ANVL-158 recommendation 4):

```dart
Future<T> saveTransaction<T>(String description, T Function(SaveScope tx) body) async {
  _db.execute('BEGIN IMMEDIATE');
  try {
    final result = body(SaveScope._(_db));   // domain writes, rule re-check, read-back
    _db.execute(
      "INSERT INTO save_history (saved_at, description, is_auto_save) "
      "VALUES (datetime('now'), ?, 0)",
      [description],
    );
    _trimSaveHistory(keep: 50);              // oldest rows by saved_at, as 0.1.6
    _db.execute('COMMIT');
    return result;
  } catch (_) {
    if (!_db.autocommit) _db.execute('ROLLBACK');
    rethrow;
  }
}
```

Inside the body a domain save updates the row, including `updated_at = datetime('now')`, with `WHERE id = ? AND deleted_at IS NULL` and requires exactly one updated row (otherwise `RecordNotFound`); deletes and re-inserts the junction rows with `sort_order` set to the list index; re-runs the save-blocking rules (§8.6); and reads the record back as the new baseline.

Every committed user change goes through `saveTransaction` and leaves one history row: record saves, creates, duplicates, soft deletes, restores, hard deletes, bulk operations, project settings, custom field definitions and custom templates. Descriptions keep the 0.1.6 vocabulary so the dashboard feed reads the same across old and new rows: `<name> - <Domain> changed`, `<name> - <Domain> created` (likewise `deleted`, `restored`, `duplicated`, `permanently deleted`), `<n> <domains> deleted` for bulk operations, `Project settings changed` and `Custom field definitions changed` (derived from `change-accumulator.ts`). 0.1.6 did not record template edits in history; 0.2.0 does, as `<name> - Template changed`.

### 6.5 Errors across the boundary

The core defines its own exception types, and `SqliteException` never escapes it: `RecordNotFound`, `SaveBlocked(blockers)`, `DuplicateExportKey` (mapped from the `UNIQUE` constraint on `export_key`, which 0.1.6 surfaced as a raw SQLite message; derived from `001_init.ts`), `MetaInUse(kind, counts)`, `ProjectLocked`, `MigrationFailed(filename)` and `IntegrityCheckFailed(message)`.

### 6.6 Providers

`ProjectService.open` returns a `ProjectSession` that holds the project metadata and one instance of each repository interface. The app exposes it through `projectSessionProvider`, and per-domain providers read from it (`recipeRepositoryProvider` returns `session.recipes`). Tests override the repository providers with fakes, or with a session opened on a fixture copy. The overrides live in `lib/app/providers.dart`. Opening another project replaces the session, which disposes every editor, as it should.

---

## 7. Domain model and record rules

The six first-class domains and their rules carry over unchanged.

| Domain | Owns | References |
| :---- | :---- | :---- |
| Classes | Stat growth (manual entries or a formula per stat), derived stat overrides, metadata fields, ability assignments | Abilities, stats, derived stat definitions |
| Abilities | Type, resource type, resource cost, cooldown, stat modifiers | Stats (by key in the modifiers map) |
| Items | Category, rarity, category-scoped custom field values | Item categories, rarities |
| Recipes | Output item and quantity, ingredients | Items, crafting station, crafting specialization |
| NPCs | Type, combat stat overrides, class assignments with level, ability assignments, type-scoped custom field values | NPC types, loot tables, classes, abilities |
| Loot tables | Entries with integer weight and quantity range | Items |

- **Three-part identity.** Every record has an immutable internal id (TEXT), a display name and an export key (`UNIQUE` per domain table). References store the internal id only. The three are never conflated.
- **Ids.** User-created rows get a version 4 UUID in the same lowercase hyphenated form as `crypto.randomUUID()`, generated in the core from `Random.secure()`. Seeded meta rows keep their fixed ids (`stat-strength`, `rarity-common`, ...) (derived from `src/main/repositories/*.ts`, `002_seed_meta_layer.ts`).
- **Duplicate.** The copy is named `<name> (Copy)`; its export key is the slug of that name plus `-` and the first 8 characters of a new UUID; junction data is copied (derived from `class.repository.ts`).
- **Soft delete.** Soft delete sets `deleted_at = COALESCE(deleted_at, datetime('now'))` and bumps `updated_at`; restore clears it; hard delete is offered only from archive views and the recycle bin, and owner foreign keys on junction tables cascade (derived from `domain-repository.ts`, `001_init.ts`).
- **Custom fields** are `text`, `integer`, `decimal`, `boolean` or `enum`, scoped to an item category or an NPC type. There are no cross-domain reference types.
- **Loot table weights** are integers of at least 1; drop percentages are computed for display. Entry rows get new ids on every save (derived from `loot-table.repository.ts`).
- **NPC stat block.** The inherited value of a stat is the sum, over the NPC's class assignments, of that class's stat growth at the assigned level; `combat_stats_json` holds per-stat overrides. The computation moves from the renderer into the core as a pure function (derived from `NpcStatBlockPanel.tsx`).
- **Derived stats** have an output type (`integer` or `float`) and a rounding mode (`floor`, `round`, `none`); classes may override a formula.
- The legacy `affinities` table stays in the schema with no repository and no UI, as in 0.1.6 (derived from `001_init.ts` and `ipc-channels.ts`).

---

## 8. State management and the save model

### 8.1 Riverpod 3 without code generation

State is held in `flutter_riverpod` ^3.4 (ANVL-158 used 3.4.3) with hand-written providers and no code generation. Families of `AsyncNotifier`s map directly onto "one draft per open record", `autoDispose` ties a draft's lifetime to its editor, and `ProviderContainer.test` makes notifiers unit-testable. Riverpod 3 retries failing providers by default, so tests turn retries off (`retry: (_, _) => null` on `ProviderScope` and `ProviderContainer.test`).

| State | Holder |
| :---- | :---- |
| Open project | `projectSessionProvider` (root override, §6.6) |
| App settings | Notifier over the core `AppSettingsStore` (§14.1) |
| List rows | `FutureProvider.autoDispose` per domain and list mode, invalidated after writes |
| Editor drafts | `AsyncNotifierProvider.autoDispose.family` keyed by record id (§8.4) |
| Validation issues | Notifier fed by the background pass (§10.2) |
| Save status | Provider aggregating the open editors' states (§8.5) |

### 8.2 Drafts

Each domain has one immutable `XDraft` with value equality: hand-written `==` and `hashCode`, covered by a test. A draft holds the user-editable fields and each junction list as an ordered list in which `sort_order` is the index; keyed collections (stat growth by stat and level, formulas by stat, overrides by derived stat) compare as maps. Drafts carry no timestamps. The baseline is the record as read back inside the save transaction, and `isDirty` is simply `draft != baseline`, so typing a value back or undoing to the baseline clears the marker without bookkeeping.

| Draft | Fields (derived from `src/shared/domain-types.ts`) | Ordered or keyed collections |
| :---- | :---- | :---- |
| `ClassDraft` | display name, export key, description, resource multiplier | stat growth entries, stat growth formulas, ability assignments, derived stat overrides, metadata fields |
| `AbilityDraft` | identity, ability type, resource type, resource cost, cooldown | stat modifiers (map) |
| `ItemDraft` | identity, item category, rarity | custom field values (map by definition) |
| `RecipeDraft` | identity, output item, output quantity, crafting station, crafting specialization | ingredients |
| `NpcDraft` | identity, NPC type, loot table | class assignments (class, level), ability assignments, combat stat overrides (map), custom field values |
| `LootTableDraft` | identity | entries (item, weight, quantity min and max, conditional flags) |

Ability assignments on classes and NPCs, and NPC class assignments, which 0.1.6 saved immediately and kept out of undo, become part of the draft: they are undoable and saved atomically with the record (ANVL-158 recommendation 1).

### 8.3 DraftHistory

`DraftHistory<T>` is a generic pure-Dart value in the core, ported from ANVL-158. Its rules: edits to the same field less than 500 ms apart coalesce into one step (matching 0.1.6's `useUndoRedo`); structural edits (add, remove, reorder) are one step each; an edit that lands on the previous snapshot counts as an undo, which stops a field's own Ctrl+Z from leaving no-op steps on the draft stack; the stack is capped at 200; after a save the baseline moves and the stack is kept; `rebase` keeps a draft that changed during a save. The clock is injected through a provider so coalescing is testable.

### 8.4 Editor controllers

Each editor's state lives in `AsyncNotifierProvider.autoDispose.family<XEditorController, XEditorState, String>(XEditorController.new)`, keyed by record id, with the family argument passed to the notifier's constructor (Riverpod 3 dropped `FamilyNotifier`). The state holds the baseline, the draft, the history, the current save blockers and the save status. The notifier exposes intent methods (`setDisplayName`, `addIngredient`, `moveIngredient`, `undo`, `redo`, `save`); widgets never touch the history. `autoDispose` drops the draft when the editor closes, so Discard is just leaving.

`build()` watches only stable providers (the project session and the repository) and reads anything volatile at call time with `ref.read` (ANVL-158 gotcha 6: a repository that watched a setting rebuilt the editor and reloaded the draft from disk). Project settings an editor displays, such as max level for the stat growth grid, are read once at load and watched by the widgets, never by `build()`. A test toggles settings mid-edit and asserts that the draft survives.

### 8.5 Record-level save

Record-level save replaces project-level save, the project dirty flag and the auto-save timer (ANVL-163). Each record save is one transaction that writes one `save_history` row (§6.4). The Electron change accumulator and its tiered descriptions are dropped, because one save now describes one record.

- **Save status** is shown in the shell's app bar, aggregated from the open editors: all saved, the number of records with unsaved changes, saving, or the last save failure with its message.
- **Checkpoint quietly.** 0.1.6 ran `wal_checkpoint(TRUNCATE)` on every save (derived from `project-service.ts`). 0.2.0 runs a `PASSIVE` checkpoint once the app has been idle for a few seconds after a save, and `TRUNCATE` when a project closes or the app exits.
- **`is_auto_save`.** The column stays. Every row 0.2.0 writes has 0, because every save is a user action. Rows written by 0.1.x keep their value, and the dashboard keeps labeling them. If a later feature saves drafts without a user action (an idle save, crash recovery), it writes 1; that is the decision point, and until such a feature is ticketed nothing writes 1.
- Create, duplicate, delete, restore and bulk operations are each their own transaction with their own history row.

### 8.6 Validation at save

Save-blocking rules are pure functions per domain in the core. They run in the notifier, which disables Save (Ctrl+S included) and shows the reason, and again inside the repository save, which refuses and writes nothing (ANVL-164). The blockers are (derived from `DerivedStatsEditor.tsx`, `001_init.ts` and ANVL-158):

- an export key already used in the domain (refused before SQLite's `UNIQUE` constraint would reject it);
- junction rows the schema would reject: duplicate keys in a junction list, quantities, weights or levels below 1, and a loot entry's maximum quantity below its minimum;
- a syntax error in a class's derived stat override formula, or a metadata field key that is not an identifier (`^[a-zA-Z_][a-zA-Z0-9_]*$`), as 0.1.6 blocks;
- a recipe whose output item is also one of its ingredients (ANVL-158 AC7).

Everything else stays a validation issue that blocks export, not save: broken or soft-deleted references, empty required custom fields, formula runtime errors and stat growth formula errors, which 0.1.6 also saved and flagged (derived from `StatGrowthEditor.tsx`).

### 8.7 Keyboard layering

Key events bubble from the focused node, so the editor's shortcuts see Ctrl+Z before the framework's text shortcuts at the app root. The layers are therefore (ANVL-158 recommendation 3):

1. The framework's `DefaultTextEditingShortcuts` own text-editing keys inside fields.
2. The app-shell `Shortcuts` and `Actions` hold the app-level intents (the ported ANVL-113 registry, §13.4). They never bind `UndoTextIntent` or `RedoTextIntent`: `EditableText` registers its undo with `Action.overridable`, so an ancestor binding would replace every field's own undo (ANVL-158 gotcha 2).
3. Each editor wraps its content in a `RecordEditorShortcuts` layer around an `autofocus` `FocusScope`, with `SaveRecordIntent` (Ctrl+S, which works with the cursor in a field) and `UndoDraftIntent`/`RedoDraftIntent` (Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y). The draft undo and redo actions report themselves disabled while an `EditableText` has focus, so the event continues to the field's native undo. The editor's own `FocusScope` takes focus on open and after a click outside a field, so editor shortcuts are always reachable.
4. Dialogs are separate routes and fall outside an editor's layer automatically.

Pickers inside editors avoid `DropdownMenu`, which contains an `EditableText` and would turn Ctrl+Z into a text undo; they use `DropdownButton` or menu anchors. Flutter's field undo misses the original text when typing starts within 500 ms of focusing a field (ANVL-158 gotcha 1); the draft undo still reaches it, which is acceptable.

### 8.8 Leaving, exiting and list actions

- **Leave guard** (ANVL-161). `PopScope(canPop: !isDirty)` with `onPopInvokedWithResult` asks Save / Discard / Cancel. Save is disabled while blocked, and a failing save keeps the user in the editor. The modal editing mode uses the same guard on its dialog route.
- **Exit, close and switch.** A registry of dirty editors is consulted by `AppLifecycleListener.onExitRequested` and by the close-project and open-project commands, offering Save all / Discard all / Cancel. Both runners must forward window close requests to the framework (ANVL-158 "Not covered"). 0.1.6 never asked, because auto-save had already written everything (derived from `src/main/index.ts`).
- **List actions** (ANVL-166). Soft delete, restore and duplicate from a list are instant and show an Undo snackbar that applies the inverse action. A bulk soft delete still shows the 0.1.6 impact summary before it runs, then offers the same Undo. Hard delete and Empty Trash keep their confirmations, because they cannot be undone.

---

## 9. Formula engine

### 9.1 Port

`src/main/formula/engine.ts` is ported to `anvil_core/lib/src/formula/` as pure Dart with the same grammar (`expr = term (('+'|'-') term)*`, `term = factor (('*'|'/') factor)*`, unary minus, numbers, identifiers, calls and parentheses), the same built-ins (`min`, `max`, `floor`, `ceil`) and the same public functions: `evaluateFormula(formula, bindings)` returning value, error and `isSyntaxError`; `validateFormula`; `extractVariableNames`. `FormulaSyntaxError` and `FormulaRuntimeError` keep their messages verbatim, for example `Unexpected character 'x' at position 3`, `Expected RPAREN but found '' at position 5`, `Unexpected end of formula`, `Unknown variable 'x'`, `Division by zero`, `Unknown function 'x'` and `Formula is empty`.

A naive port would differ on JavaScript number details, which the parity test must cover (derived from `engine.ts`): the lexer consumes `[0-9.]+` and `parseFloat` keeps the longest valid prefix, so `1.2.3` reads as 1.2 where Dart's `double.parse` throws; `min()` and `max()` with no arguments return infinities and `floor()` with none returns NaN; division by zero fails only on an exact zero; arithmetic is double-based. The parity test runs a case list through the Electron engine with a small node or vitest oracle, writes the expected results as JSON, and the Dart tests assert equal values, errors and syntax flags. As with the export corpus, the oracle is regenerated until cutover and then frozen.

### 9.2 Where it runs

There is no main process, so formulas run in-process.

| Use | Size (defaults) | Where |
| :---- | :---- | :---- |
| A formula field's live preview | 1 evaluation | Synchronously in the notifier |
| Stat growth formula across all levels | max level per formula stat (50) | Notifier, debounced 300 ms, as the 0.1.6 stat growth editor did |
| Derived stat breakpoints | derived stats × up to 6 levels, multi-pass in dependency order | Notifier, debounced 300 ms (derived from `DerivedStatsEditor.tsx`) |
| Any batch above 2,000 evaluations | for example 1,000 levels × several formula stats | `Isolate.run` on a snapshot of formulas and bindings |
| Project validation | all classes, overrides, growth formulas × levels | Validation isolate (§10.2) |
| Export | growth formulas resolved per level | Export isolate (§11.9) |

At a few microseconds per evaluation, 2,000 evaluations stay within a few milliseconds of a frame; above that, `Isolate.run`'s fixed cost is worth paying. The threshold is a constant measured by a benchmark in the port ticket.

Results are cached per (formula, bindings) in the notifier for the editor session, alongside a parse cache from formula text to syntax tree, since a batch evaluates one formula over many bindings. Both go with the notifier on dispose. 0.1.6 did not actually cache (the v1 design promised it, but `formula.handlers.ts` evaluates every request), so this is new and invisible to users.

Bindings stay as in 0.1.6: stat growth formulas see only `level` and `max_level`; derived stat formulas see the stats by export key at a level, the class's metadata fields by key, `resource_multiplier`, and other derived stats in dependency order with output type and rounding applied (derived from `validation/engine.ts` and `DerivedStatsEditor.tsx`). Cycle detection for derived stats (the base graph, then each class's graph with its overrides) is kept as in the validation engine, and the derived stats editor uses that same core function for its inline cycle marker instead of a renderer-side copy (derived from `DerivedStatsEditor.tsx`).

---

## 10. Validation

### 10.1 Port

`validateProject` and its check families move to `anvil_core/lib/src/validation/` with the 0.1.6 messages and severities (derived from `src/main/validation/engine.ts`). It is core code and reads with set-based SQL through `ProjectDatabase`, as 0.1.6 did, inside one read transaction so all checks see the same snapshot. An issue carries id, domain, record id, record display name, field, severity and message.

| Family | Checks | Severity |
| :---- | :---- | :---- |
| Direct references | items to item category and rarity; recipes to output item, crafting station and specialization; NPCs to NPC type and loot table | Broken: error. Soft-deleted target: the project's soft-delete reference severity (Warning or Error). |
| Junction references | class ability assignments, recipe ingredients, NPC class and ability assignments, loot table entries | As above |
| Required custom fields | Required definitions on active items of the category or NPCs of the type whose value is null or empty | Error |
| Derived stat syntax | Base definitions and per-class overrides | Error |
| Derived stat runtime | Each active class's effective formula at level 1 | Warning |
| Derived stat cycles | Base graph, then per class with overrides | Error |
| Stat growth formulas | Syntax; variables other than `level` and `max_level`; runtime failure at any level from 1 to max level (first failing level reported) | Error; unknown variables are a warning |

### 10.2 Where it runs

- **Project-wide.** `ValidationService` runs the full pass in a background isolate that opens its own read-only connection to the project file. It runs on project open, after saves (debounced by about a second), when the validation panel opens or refreshes, and as the export gate (§11.9). Results feed the global panel and the sidebar badge.
- **Record-level.** After a save commits, `validateRecord(domain, id)` runs the same families restricted to that record, in-process on the UI isolate's connection. Its issues feed the editor's banner and field indicators. 0.1.6 ran the whole pass and filtered it for the editor (derived from `useRecordValidation.ts`).

Both see saved data only. The soft-delete reference severity stays a project setting. Inline display, the global panel grouped by domain and severity with click-to-navigate, and the sidebar badge (error plus warning count) are kept and built under ANVL-148 and ANVL-149.

---

## 11. Export engine

### 11.1 Decision

Custom templates render through a **purpose-built renderer of a Nunjucks-compatible subset** in `anvil_core/lib/src/export/`, on top of a JavaScript-compatible value layer (`js_compat`) that the presets use as well (ANVL-151).

| Option | Result | Verdict |
| :---- | :---- | :---- |
| `jinja` package (jinja.dart 0.7.2) | Passes the 3 fixtures, but 105 of 149 corpus cases, 15 of them silently different output, including two documented features (string escapes, CRLF). The causes (truthiness, scoping, Python precedence, int64 arithmetic) sit in its core and could only be fixed by forking. Single-maintainer 0.x port marked "work in progress". CPU and memory unbounded; an isolate kill bounds time, not memory. | Rejected |
| Embedded JS runtime with Nunjucks (`flutter_js`, QuickJS) | Exact output, but a Flutter plugin (cannot live in the core, no `dart test`), opaque prebuilt native binaries, a fetch bridge on by default, no interrupt handler for runaway scripts, and it keeps the Nunjucks escape alive. | Rejected |
| Purpose-built subset renderer | 3 of 3 fixtures, 45 of 45 documented-feature cases, 32 of 32 edge cases, 129 of 149 overall, and no case with different output: the 20 misses are unsupported idioms rejected at parse time with a position. About 1,550 lines, no dependency, safe by construction. | **Chosen** |

### 11.2 Compatibility contract

For supported features, 0.2.0 produces 0.1.6 output byte for byte. The parity corpus (149 cases: 45 documented, 69 idiom, 32 edge, 3 host) and the fixtures (three templates with their outputs, the three presets including selection scope and all six CSV files, and the export contexts) are the specification. The oracle `tool/nunjucks_oracle.js` regenerates them against the Electron `node_modules` until cutover; ANVL-169 removes Electron and the JSON fixtures are frozen from then on.

### 11.3 JavaScript value semantics

JavaScript semantics leaked into 0.1.6 output and are part of the export contract: number formatting (`String(x)`), `JSON.stringify` layout and key order (integer-like keys first), `String()` of lists and objects, truthiness (`[]` and `{}` are truthy), loose `==`, JavaScript operator precedence (`not a == b` is `(!a) == b`; `1 ~ 2 + 3` is `"123"`), `undefined` distinct from `null`, and the output-time undefined check (outputting null or undefined throws; looking up a missing name does not). `ctx` remains an alias for the whole context, and string literals process only `\n`, `\t` and `\r`. The `json` filter is `JSON.stringify(value, null, indent ?? 2)`: `json(0)` is compact and indents are clamped to 10.

**Number rule.** The REAL columns (`classes.resource_multiplier`, `class_stat_growth.value`, `class_metadata_fields.value`, `abilities.resource_cost`, `abilities.cooldown`) arrive as Dart doubles. Every exporter prints integral doubles without `.0`, `-0.0` as `0`, and NaN or infinity as `null` in JSON. Template arithmetic is double-based, as in JavaScript.

### 11.4 Sandbox model

A template has no calls, globals, includes, macros or recursion; it can only read the export context and loop over finite values. The remaining costs are capped by `RenderLimits`:

| Limit | Default | Measured effect |
| :---- | :---- | :---- |
| Loop iterations per render | 5,000,000 | 40^6 nested loops stop in 3.5 to 4 s |
| Characters per output or intermediate string | 32 Mi (33,554,432) | A 32 MB output flood stops in 1.5 s; string doubling in 0.2 s |
| Total characters of string work per render | 256 Mi (268,435,456) | Bounds repeated concatenation |
| Parser nesting depth | 200 | 10,000 nested parentheses fail with a limit error in about 20 ms, without stack overflow |

Rendering runs off the UI isolate (`Isolate.run`, or the spike's `renderIsolated` with a timeout, 10 s by default) as defense in depth. Memory stays bounded by the renderer's own string caps, not by the isolate, because isolates in one group share a heap. Templates stored in project files are untrusted input: a `.anvil` file is shareable.

### 11.5 Unsupported templates

On project open, and whenever the export page loads templates, `checkTemplate(source)` (returning kind, message, line and column) runs on every `custom_templates.template_source`.

- The stored source is never rewritten or deleted.
- The export page shows a warning per affected template, for example "Uses `{% macro %}` (line 3, column 4), which Anvil 0.2 does not support. Edit the template to export with it.", disables it in the selector and opens the editor at the reported position.
- After opening a project with any such template, one notice appears ("2 custom templates need changes before they can export") and the finding is logged.
- Render-time errors (undefined output, limits) are reported with line and column, as 0.1.6 reported render errors.

0.1.x users were steered to the documented subset, which renders identically. If an unsupported filter turns out to be in use, it is added with a corpus case; each is a few lines.

### 11.6 Quirks kept on purpose

- `export_key` scans only the six domain arrays (classes, abilities, items, recipes, npcs, loot_tables) and never resolves meta ids: `{{ item.rarity_id | export_key }}` prints `rarity-common`. The presets do resolve meta ids, so template and preset output differ here, as in 0.1.6.
- Flat JSON's `derived_stat_export_key` is the raw id (`derived-stat-max-hp`), because derived stats are missing from its lookup.
- CSV: LF line ends, no final newline, header from the first row's keys, quoting only on `,`, `"` or `\n` (a lone `\r` is not quoted), null as an empty cell.

Any behavior change must be a new, explicitly named filter or option, so existing templates never change output silently. `export_key` uses an id index built once per render instead of 0.1.6's linear scan; that changes speed, not output.

### 11.7 Known issue in 0.1.6

0.1.6 is not sandboxed. Nunjucks 3.2.4 returns bound JavaScript functions from member lookups, so `{{ ''.constructor.constructor('return process.platform')() }}` runs arbitrary JavaScript with Node's `process` in the main process. 0.1.6 is frozen with this as a known issue. 0.2.0 closes it by construction (in the new renderer `''.constructor` is simply undefined), and the 0.2.0 release notes say so.

### 11.8 Where the code lives

All of it is in `anvil_core/lib/src/export/`: `js_compat` (number formatting, the `JSON.stringify`-compatible encoder, `String()`, truthiness and operators), the presets, the template renderer (lexer, parser, JavaScript-precedence pass, evaluator, 15 filters) and the context assembler. Nested JSON, Flat JSON and CSV are Dart code ported from `renderNestedJson`, `renderFlatJson`, `renderCsv`, `toCsv` and `csvEscape`, not templates.

### 11.9 Export pipeline

`ExportService` takes a preset or template id and a scope (full project, one domain, or a record selection within one domain). In one background isolate with its own read-only connection it runs:

1. **The validation gate.** Any error-severity issue blocks the export with `Export blocked: <n> validation error(s) must be resolved before exporting.` (derived from `export.handlers.ts`).
2. **Context assembly**, ported from `context-assembler.ts`: `project`, `meta`, and the six domain arrays ordered by display name with their nested arrays and custom fields, stat growth formulas resolved to concrete values per level. In domain and selection scope the other domain arrays are empty, as in 0.1.6 (derived from `context-assembler.ts`; 0.1.6 has no dependency auto-include in the code).
3. **Rendering** with the preset or template.

The isolate returns the output text, or the file list for CSV. The app shows it in the read-only preview, or on execute opens a save dialog (`file_selector`) that defaults to the project's `exports/` folder, created if missing; multi-file CSV output asks for a folder instead. Files are written as UTF-8. The export reflects saved records only, and the export page says so while any editor has unsaved changes.

---

## 12. Project lifecycle

`ProjectService` in `anvil_core/lib/src/project/` ports `src/main/project/project-service.ts` without its auto-save timer and dirty tracking. It returns a `ProjectSession` (§6.6) for the open project.

### 12.1 Create

Project name and game title are required. The folder dialog starts at `defaultSaveLocation`, or the Documents folder when it is unset. `createProjectFolder` makes `{ProjectName}/database/`, `exports/`, `temp/` and `logs/` under the chosen parent and fails if the folder exists; `sanitizeFolderName` is already in the core. The file is `{ProjectName}/database/{sanitized name}.anvil`. Creation acquires the lock, opens the file, runs the migrations, checks integrity, upserts the project name, game title and schema version into `project_info` and adds the project to the recent list. On failure it closes the file, releases the lock and removes the whole folder tree. The create dialog always sends the `blank` template (ANVL-142); real templates are ANVL-156.

### 12.2 Open

The path comes from an open dialog filtered to `.anvil` or from the recent list, and must exist. Opening acquires the lock first; a lock conflict is reported as `This project is already open in another Anvil window.` and is not a recovery case. A background isolate then opens the file read-only, runs `PRAGMA integrity_check` and reads `schema_version` (from `project_info`, else the legacy `project_meta`, else 0). The UI isolate then opens it read-write with the pragmas of §5.4, builds the project metadata and updates the recent list (derived from `project-service.ts`).

### 12.3 Upgrade on open

If the version is below 7, the user is asked "This project was created with an older Anvil schema." with the detail "Anvil will create an upgraded backup copy and leave the original project file unchanged." and the choices Upgrade Copy or Cancel. On Upgrade, a snapshot of the original is written beside it as `{name}_backup_{timestamp}.anvil` (timestamp as 0.1.6 formats it, ISO digits only), the copy is migrated, checked and checkpointed, the lock moves to the copy (the new lock is acquired before the old one is released), and the copy becomes the active project. The pre-open check opens the original read-only, so it stays byte-identical; 0.1.6 opened it with WAL first, which converted its journal mode (derived from `project-service.ts` and ANVL-158 finding 9).

### 12.4 Recovery mode

An integrity failure, or any other open error that is not a lock conflict, leaves the app in recovery mode: the welcome area shows the file name and the error message, nothing is opened and nothing can be edited. 0.1.6 offers no partial recovery, and neither does 0.2.0 (derived from `setRecoveryState` in `project-service.ts`).

### 12.5 Lock

The lock is a sidecar file `<file>.anvil.lock`, created with exclusive-create semantics (`File.create(exclusive: true)`, the equivalent of Node's `wx`). It holds the same JSON as 0.1.6, `{"pid": <int>, "lockedAt": "<ISO 8601>", "filePath": "<path>"}`, so a 0.1.6 instance and a 0.2.0 instance refuse each other's open project. It is deleted on close and on exit. Paths are compared case-insensitively, as in 0.1.6. There is still no stale-lock detection: after a crash the user deletes the lock file by hand, as with 0.1.6 (derived from `project-service.ts`).

### 12.6 Close, Save As and backup

- **Close** runs the dirty-editor guard (§8.8), a `TRUNCATE` checkpoint, closes the handle and releases the lock.
- **Save As** first asks to save or discard dirty editors, then takes a target from a save dialog (`.anvil` appended if missing; the target must not exist; the same path is a no-op), writes `snapshot(target)`, moves the lock and reopens the copy as the active project. On failure it reopens the original (derived from `saveProjectAs`).
- **Backup** writes `snapshot(path)` to a path from a save dialog that defaults to `{project dir}/{name}-backup-{YYYY-MM-DD}.anvil`. The active project does not change.

### 12.7 Recent projects

`recent-projects.json` in the application support directory (`getApplicationSupportDirectory`) keeps up to 10 entries, newest first, de-duplicated by path case-insensitively. Each entry holds the project metadata (name, game title, path, folder paths, schema version, last modified, file size, record counts). On read, entries are refreshed from disk: whether the file still exists, its size and modification time, and the folder structure. Entries can be removed one at a time or all at once. The JSON shape is kept (derived from `project-service.ts`).

### 12.8 Save history and dashboard data

The `save_history` table (migration 007) is kept and written once per transaction (§6.4), trimmed to 50 rows and read newest first. Per-domain record counts feed the sidebar and the recent list. The weekly deltas are kept: per domain, records created in the last 7 days that are still active, minus records deleted in the last 7 days (derived from `getWeeklyDeltas`). The auto-save info and its dashboard countdown are dropped with project-level auto-save.

---

## 13. Application shell and UI

### 13.1 Theme

The theme comes from `forge_ui` (git dependency pinned to a release tag), with the app theme in `lib/app/theme/` as built by ANVL-154: the Electron palette, the twelve-color `AnvilThemeSpec` with dark, light and custom-file modes, `anvilTheme()`, the `AnvilColors` extension and the spacing, radius, layout and type constants. Widgets take colors from `context.colors`, `context.forge` and `context.anvil`, never literals; `test/theme/no_hardcoded_colors_test.dart` fails the build on a color literal outside `anvil_palette.dart` and `color_math.dart`. Fonts come from `forge_ui`, and the app declares none. A role or widget Anvil needs that `forge_ui` lacks is raised in `forge-ui`; the status color roles move there when FU-9 to FU-12 ship (ANVL-170). The theme selection, in memory in `ThemeController` today, is persisted through app settings (§14.1).

### 13.2 Navigation, shell and editing mode

`go_router` ^18 provides a shell route for the sidebar and app bar, and one route per page: dashboard, the six lists and their editors (`/items/:id`), validation, recycle bin and export. The welcome page shows when no project is open. The 0.1.6 editing mode setting (modal by default, or full page) is kept: the editor widget is the same, shown either as a route or inside a dialog route. List pages open records through one helper that reads the setting at call time. Settings are dialogs, not routes, as since ANVL-113.

The sidebar lists the six domains with record counts, plus Dashboard, Validation, Recycle Bin and Export, with badges for validation (errors plus warnings) and the trash count. It collapses between 220 and 56 px with tooltips and badge dots. The welcome page has the hero, the New and Open tiles and the recent list with file size, record counts and a missing-file indicator. The create-project dialog is reachable from any app state (menu and Ctrl+N).

### 13.3 Window

0.2.0 uses the native OS window frame. The Electron frameless window with a custom title bar is dropped: it means fewer moving parts and no `window_manager` dependency, which is mid-migration upstream. The `window:*` channels go with it. The minimum window size of 900×600 is set in the runners rather than through a plugin: in `linux/runner/my_application.cc` (GTK geometry hints) and in the Windows window procedure in `windows/runner/win32_window.cpp` (`WM_GETMINMAXINFO`, scaled for DPI) (paths derived from the current runners). 0.1.6's `BrowserWindow` actually sets a minimum width of 1400 (derived from `src/main/index.ts`); 0.2.0 uses 900×600. The project name and save status sit in the app bar.

### 13.4 Menu and shortcuts

The ANVL-113 hamburger menu (File, View, Project, Data, Help) is rebuilt with `MenuAnchor`, `SubmenuButton` and `MenuItemButton`, whose built-in keyboard navigation replaces `useMenuKeyboard`. The 24-entry shortcut registry becomes intents bound in the app-shell `Shortcuts` and `Actions`, with the user's overrides from `customShortcuts`. The registry's Save, Undo and Redo entries dispatch to the focused editor's `SaveRecordIntent`, `UndoDraftIntent` and `RedoDraftIntent`, and are disabled when no editor has focus; the shell never binds `UndoTextIntent` or `RedoTextIntent` (§8.7). The shortcuts cheatsheet is a dialog (Ctrl+/). The View zoom entries become a UI scale factor applied at the app root (derived from `shortcuts.ts`, which used `webFrame` zoom). External links open through `url_launcher`, restricted to `https`, as 0.1.6 restricted `shell.openExternal`.

### 13.5 Settings dialogs

- **App settings** (General, Appearance, Editor): default save location, theme Dark, Light or Custom with the theme-file picker and the parser's messages, editing mode, shortcut overrides. The auto-save options leave the UI (§14.1).
- **Project settings** (General, Stats & Formulas, Crafting, Custom Fields; opened at a given tab when needed): the buffered meta lists are committed with the scalar settings on one Save (ANVL-121), now through one `saveProjectSettings` transaction, and a row in use is refused at click time through `checkInUse`. The Custom Fields tab keeps immediate persistence, with item categories and NPC types managed in its left rail (ANVL-123).

### 13.6 Charts

`fl_chart` ^1.3 replaces Recharts for the class stat growth chart, the only chart in 0.1.6. Loot table drop percentages stay a computed column, as in 0.1.6; a loot weight chart would be new scope (derived from `LootTableEditorPage.tsx`).

### 13.7 Lists

Lists use `DataTable` or custom rows at `forge_ui`'s desktop density, with search, filters, sortable columns, multi-select with a bulk action toolbar, and the Active/Archived toggle with restore and permanent delete. The recycle bin page groups soft-deleted records by domain, with individual and bulk restore and delete and the double-confirmed Empty Trash. Context menus are ANVL-117. The empty state, the inspector rail with Used By (ability, item, loot table and class editors) and the per-tab dirty dots carry over.

### 13.8 Telemetry

The build-time gated telemetry (event schema, JSONL writer, `data-tid` attributes, IPC timing) is not ported to 0.2.0. It returns only if re-ticketed. File logging is kept (§14.2).

---

## 14. Settings and logging

### 14.1 App settings

App settings stay a JSON file, `app-settings.json`, in the application support directory, with the same keys and normalization as 0.1.6: unknown or invalid values fall back to defaults, and a write merges then normalizes (derived from `app-settings-service.ts`). The model and normalization live in `anvil_core/lib/src/settings/` as `AppSettingsStore`; the app passes in the file path. The custom theme parser (`parseCustomThemeFile`, `CustomThemeColors`) is already there and reproduces the 0.1.x validation messages verbatim.

| Key | Default | 0.2.0 |
| :---- | :---- | :---- |
| `theme` | `dark` | Used (Dark, Light, Custom). |
| `editingMode` | `modal` | Used (§13.2). |
| `autoSaveEnabled` | `true` | Read and preserved, unused: there is no project-level auto-save. |
| `autoSaveIntervalMs` | 5000 (minimum 1000) | Read and preserved, unused. |
| `defaultSaveLocation` | none | Used as the create dialog's starting folder. |
| `customThemePath` | none | Used. |
| `customThemeColors` | none | Used: `mode` plus up to eleven hex colors. |
| `customShortcuts` | none | Used: per-shortcut overrides. |

### 14.2 Logging

The file logger moves to `anvil_core/lib/src/logging/` as a port of `app-logger.ts` and `log-rotation.ts`: levels error, warn, info and debug, with info as the minimum in release builds and debug otherwise (the app passes `kReleaseMode`); lines in the form `<ISO timestamp> [LEVEL] message` with the tags `ERROR`, `WARN `, `INFO ` and `DEBUG`; paths shortened by `anonymizePath` to their last two segments; one file, `anvil.log`, in `<support dir>/logs/`, rotated at 5 MB with 3 rotated files kept (`anvil.log.1` to `.3`); and a logger that never throws. 0.1.6 writes the single `anvil.log`; the dated `anvil-YYYY-MM-DD.log` name predates ANVL-107 (derived from `app-logger.ts`). Appends are synchronous, as in 0.1.6, so the last line before a crash reaches the file. Background isolates hand their log lines back to the UI isolate's logger, so rotation has a single writer.

`main()` runs the app inside `runZonedGuarded`, and `FlutterError.onError` and `PlatformDispatcher.instance.onError` log unhandled errors; together they replace 0.1.6's `uncaughtException` and `unhandledRejection` handlers and console overrides. The lifecycle lines (app start and shutdown; project create, open, close and save; migrations applied or failed; lock conflicts; recovery mode; export blocked or completed; settings changes) are kept. The role of 0.1.6's `safeHandle` wrapper, logging any failed IPC handler once, moves to the notifiers and services that catch core exceptions. The About dialog shows the log folder.

---

## 15. Packaging and release

### 15.1 Targets

| Target | Workflow | Output and requirements |
| :---- | :---- | :---- |
| Windows x64 | Org `release-flutter.yml` with `build-windows: true` | An installer built from an Inno Setup or NSIS script in the repo (the choice belongs to ANVL-167). Requirements, matching 0.1.6's assisted NSIS installer: a wizard with a per-user or all-users choice and an install directory, Start Menu and desktop shortcuts, an uninstaller, and optionally an `.anvil` file association. The SQLite library bundled by the `sqlite3` build hooks ships with the executable. |
| Linux x64 | A separate org reusable workflow (ANVL-168), added as its own job, following the org rule that a new pipeline capability gets its own reusable workflow rather than more inputs on `release-flutter.yml` | AppImage, deb and rpm as in 0.1.6, or at minimum a tarball of the release bundle. The bundle includes `lib/libsqlite3.so`. |

### 15.2 Versioning and notes

The version lives in `pubspec.yaml` as `0.2.0[-rc.N]+BUILD`. `scripts/release/bump-version.sh` and `.ps1` are vendored from the org for `rc` and `final` bumps and replace the npm `rc-tag.js` and `release-tag.js` at cutover. The release flow keeps its tagless self-gating (skip when the tag exists; release candidates only from the version branch; stable on merge to `main`) but reads the version from `pubspec.yaml`. Release notes still come from commit subjects through the org `release-notes.yml` with `ANVL-N:` keys and `Fix` subjects under Bug Fixes; that contract does not change. Install scripts (ANVL-143) and project templates (ANVL-156) are separate tickets under ANVL-150.

### 15.3 Cutover (ANVL-169)

Cutover runs a parity pass against 0.1.6 on the fixture project (open it, exercise every editor, compare export bytes and the validation issue list), freezes the export and formula oracles, removes the Electron source and tooling, updates the `main` ruleset only if check names change (today `ci / ci` and `core / ci`, both already required), and rewrites the README and the Electron sections of `.claude/CLAUDE.md`.

---

## 16. Testing strategy

| Layer | What | How |
| :---- | :---- | :---- |
| Core units | `DraftHistory`, draft equality, save-blocking rules, formula engine, `js_compat`, template renderer, presets, validation families, settings normalization, custom theme parser, lock file, folder names | `dart test` in `packages/anvil_core` |
| Core integration | Repositories, migration runner, project lifecycle | `FixtureCopy`: a fresh temporary copy of the fixture per test, fixture bytes checked unchanged in `tearDown` |
| Parity with 0.1.6 | Schema (`sqlite_master` after each migration, seed rows), export bytes (presets, templates, the 149-case corpus, the JS values oracle), formula cases, the validation issue list on the fixture | Electron oracles regenerated until cutover, then frozen JSON fixtures |
| App widgets | Keyboard routing (field undo versus draft undo, Ctrl+S in a field, focus on open), leave and exit guards, editor and list flows, a settings toggle mid-edit that keeps the draft | `TargetPlatformVariant.only(TargetPlatform.linux)`, since the default test platform is Android with different key maps (ANVL-158 gotcha 12); Windows once runner tests exist. `ProviderScope` with retries off and fake repositories or fixture-backed sessions. |
| Theme | `no_hardcoded_colors_test`, palette parity, theme controller | Existing tests in `test/theme/` |

There are no golden tests for the app; `forge_ui` owns the look. A physical keyboard and IME on Wayland and on Windows is a manual check on each release candidate, because the spike covered keyboard routing only headlessly.

**CI.** The org `ci-flutter.yml` runs twice: `ci / ci` at the root (the app's `test/`) and `core / ci` with `working-directory: packages/anvil_core`, both on Flutter 3.47.5 and both required on `main`; on release-branch PRs they report without being required. Locally, `fvm flutter test test packages/anvil_core/test` runs both. Before heavy runs, check `free -h` and cap concurrency (`-j 2`); keep the corpus scoring and benchmarks out of the default run, and never chain a full test suite and a release build in one command.

---

## 17. Future cloud

These are notes for later releases, not 0.2.0 scope.

### 17.1 Cloud backup

A `BackupService` in the core depends only on `ProjectDatabase.snapshot(path)`, whose `VACUUM INTO` output is a consistent snapshot of the whole `.anvil` file, and on a `BackupTarget` interface (upload, list, download). The first target uploads to Supabase Storage through `forge-core`, which provides sign-in and the session; as a Flutter package it implements `BackupTarget` on the app side. Restore downloads the file to a new path and opens it through the normal open path, lock and upgrade included.

### 17.2 Record-level sync or a mobile client

That would additionally need:

- **Globally unique ids.** Every record table uses TEXT ids. User-created rows (the six domains, user-added meta rows, custom field definitions, custom templates, loot table entries) are v4 UUIDs. Seeded meta rows use fixed ids such as `stat-strength`, unique within a project, which is the unit of sync, but the same in every project. `save_history.id` is `INTEGER AUTOINCREMENT` (local only; history would not sync), `project_info` is the single row `id = 1`, and the junction tables use composite natural keys, except `loot_table_entries`, whose UUIDs are regenerated on every save. Junction rows would therefore sync as part of their owner record, which matches the draft as the unit of change (derived from `src/main/db/migrations/` and `src/main/repositories/`).
- **Change timestamps.** `updated_at` exists on domain, meta, custom field and template tables, as second-resolution UTC text set on save and soft delete. Hard deletes leave no tombstone. A per-row `revision` or a change-log table would be a new migration, which ends two-way compatibility with 0.1.6 (§5.7).
- **A conflict policy.** Last writer wins per record, with the draft baseline check as the local half: a save refuses when the stored record no longer equals the editor's baseline (an optimistic `updated_at` check, ANVL-158 recommendation 4).
- **Sign-in** through `forge-core`.
- **A remote implementation**: a `RemoteXRepository` per domain, or a sync layer wrapping `Sqlite*Repository` that emits a change record after each COMMIT.

None of this changes editors, because they depend on the repository interfaces (§6).

---

## 18. Electron-era decisions

Every architecture decision in the Electron-era list of `.claude/CLAUDE.md`, with its status for the Flutter line:

| Electron decision | Status | 0.2.0 rule | Reason | Section |
| :---- | :---- | :---- | :---- | :---- |
| Main/renderer strict split; all data through typed IPC via `contextBridge` | **Dropped** | One process. The core package takes over every main-process responsibility and the app calls it directly; isolation where needed is by isolate. The `domain:operation` channel convention becomes methods on repository and service interfaces. | Flutter has no renderer sandbox to protect. The boundary that matters is core versus UI, and the core's pubspec enforces it. | §4 |
| SQLite via `better-sqlite3`, raw SQL, no ORM | **Revised** | `package:sqlite3` 3.x with bundled SQLite, raw SQL, no ORM; Drift rejected. | The reasons for raw SQL still hold (explicit migrations and transactions), and the inherited schema must stay byte-compatible. | §5 |
| Three-part record identity | **Kept** | Unchanged. | Ids survive renames; export keys stay user-controlled. | §7 |
| Soft delete by default; hard delete only from archive views and the recycle bin | **Kept** | Unchanged; list soft deletes gain an Undo snackbar. | Recoverability; validation flags references to deleted records. | §7, §8.8 |
| Custom fields are scalar or enum only | **Kept** | Unchanged. | No cross-domain reference field types. | §7 |
| Formula engine in the main process, debounced and cached | **Revised** | Ported to the core and run in-process; debounced in the notifier; batches above 2,000 evaluations on `Isolate.run`; cached per formula and bindings for the editor session. | There is no main process, and an evaluation takes microseconds. | §9 |
| Loot table drop weights are integers | **Kept** | Unchanged. | Percentages are computed for display. | §7 |
| Abilities and Loot Tables are first-class domains | **Kept** | Unchanged: own tables, repositories, lists and editors. | Reused across classes and NPCs. | §7 |
| Export presets are Nested JSON, Flat JSON and CSV | **Kept** | Ported as Dart code, byte-identical to 0.1.6. | They were never templates. | §11.8 |
| Nunjucks for export templates, "sandboxed" in the main process | **Revised** | A purpose-built renderer of a Nunjucks-compatible subset in the core, safe by construction, byte-identical for supported features; unsupported templates detected and disabled, never rewritten. | 0.1.6's Nunjucks is not sandboxed; jinja.dart prints wrong output silently; a JS runtime cannot live in the core. | §11 |

New decisions for the Flutter line:

| Decision | Rule | Section |
| :---- | :---- | :---- |
| Core/UI boundary | `anvil_core` is pure Dart with no Flutter or Riverpod, tested with `dart test`; the app depends on the core, never the reverse. | §4.3 |
| Repository boundary | Editors and the draft layer use repository interfaces only, via root-overridden providers; no SQL or `sqlite3` type crosses; one `ProjectDatabase` with `saveTransaction`. | §6 |
| Migration compatibility contract | The seven migrations verbatim, `schema_migrations` kept, version 7, upgrade a copy; proven against the Electron fixture. | §5.7 |
| Record-level save on Riverpod 3 | One value-equal draft per editor in an `AsyncNotifier` family; one transaction and one history row per save; no project-level save or auto-save. | §8 |
| Keyboard layering | Shell shortcuts never bind `UndoTextIntent`/`RedoTextIntent`; each editor has its own layer with draft undo disabled while a field has focus. | §8.7 |
| Theme rule | Colors come from `forge_ui` and the app theme, never literals, enforced by a test; fonts from `forge_ui`. | §13.1 |
| Shell stack | `go_router` with the modal/full-page editing mode kept, native window frame, `MenuAnchor` menu, `fl_chart`. | §13 |
| Background work | Project-wide validation, export and large formula batches run in isolates with their own read connection. | §4.4 |

---

## 19. Proposed ticket breakdown

Proposed child tickets, in dependency order, each about one working session and independently shippable. Existing tickets are not repeated, and the new ones are cut around them: ANVL-117 (context menus) under ANVL-148; ANVL-140 (formula fill helper) under ANVL-149; ANVL-143, ANVL-156, ANVL-167, ANVL-168 and ANVL-169 under ANVL-150; ANVL-118, ANVL-151 to ANVL-155 and ANVL-170 under ANVL-146; and the open save-model implementation tickets under ANVL-157, which stay the home of their features: `DraftHistory` and the editor controllers (ANVL-159), the save transaction and its history row (ANVL-160), the leave guard (ANVL-161), the editor keyboard layer (ANVL-162), save status and quiet checkpoints (ANVL-163), save blocking (ANVL-164), drafts for project settings and the template editor (ANVL-165) and the list Undo snackbar (ANVL-166). Where a new ticket builds on one of them, the After column names it.

### 19.1 ANVL-147: data and domain core

| # | Summary | Goal | After |
| :---- | :---- | :---- | :---- |
| C1 | Port the database layer and migration runner to anvil_core, with the 0.1.6 fixture set | `ProjectDatabase` (open, read-only open, pragmas, integrity check, snapshot, checkpoint, `read`) and the seven migrations as verbatim SQL. The fixture set and its generator are checked in, and the schema, per-migration and seed parity tests pass. `saveTransaction` and the history row are ANVL-160. | |
| C2 | Port the project lifecycle service | Create, open, close, the lock in the 0.1.6 format, recent projects, the upgrade-a-copy flow, recovery mode, backup and Save As through `snapshot`. Tested on fixture copies, including a lock file written in 0.1.6's format. | C1 |
| C3 | Port app settings and the file logger to anvil_core | `AppSettingsStore` with the 0.1.6 keys and normalization (auto-save keys preserved, unused), and `anvil.log` with 5 MB × 3 rotation and path anonymization. Paths are passed in by the app. | |
| C4 | Add the record and draft types for the six domains, meta and custom fields | Immutable value-equal drafts with hand-written equality and tests, the read models for list rows, and the create inputs, ported from `domain-types.ts`. `DraftHistory<T>` and the controllers are ANVL-159; the §8.6 blockers are ANVL-164. | |
| C5 | Port the formula engine with an Electron parity corpus | Same grammar, errors and messages; cases produced by the Electron engine are the specification. Parse cache, and the 2,000-evaluation isolate threshold set from a benchmark. | |
| C6 | Implement MetaRepository and CustomFieldRepository | The seven meta lists with the 0.1.6 in-use rules, project settings saved with the buffered lists in one transaction, and custom field definitions with immutable types and protected enum options. | C1, C4, ANVL-160 |
| C7 | Implement ClassRepository and AbilityRepository | Load and save of the full class draft (growth, formulas, assignments, overrides, metadata) and the ability draft in one transaction; duplicate, delete, restore and used-by, matching the fixture rows. Saves go through the ANVL-160 transaction and run the ANVL-164 blockers. | C5, C6, ANVL-160 |
| C8 | Implement ItemRepository, RecipeRepository and LootTableRepository | Drafts with custom field values, ingredients and entries; used-by for items and loot tables; saves that refuse blocked drafts, including output-as-ingredient. | C6, ANVL-160 |
| C9 | Implement NpcRepository, LifecycleRepository and SaveHistoryRepository | The NPC draft and the pure stat-block function; bulk soft delete, restore and hard delete, empty trash, delete impact, trash counts and weekly deltas; history reads. | C7, C8 |
| C10 | Port the validation engine with a background project runner | All check families with 0.1.6 messages and severities, the project pass in a background isolate with its own read connection, and `validateRecord`; the fixture's issue list matches Electron's. | C1, C5 |
| C11 | Port the export engine to anvil_core: JS-compatible serialization, the three presets, and a Nunjucks-compatible custom template renderer | The ANVL-151 §7 ticket, reproduced below. | |
| C12 | Port the export context assembler and the export service | A context equal to `context-full.json` and the selection fixture from a SQLite-typed read; gate, assembly and render in one background isolate; `TemplateRepository`; per-template check status for the UI. | C10, C11 |

**C11, as drafted in ANVL-151 FINDINGS §7.** Goals: presets and custom templates produce byte-identical output to Anvil 0.1.6 for the same project file; custom templates render through a pure-Dart, sandboxed renderer of the documented Nunjucks subset plus the common idioms (ANVL-151 FINDINGS §3); templates using unsupported features are detected without rendering, and never altered. Acceptance criteria:

- `js_compat` (number formatting, `JSON.stringify`-compatible encoder with indent semantics and JS key order, `String()`, truthiness, operators) lives in `packages/anvil_core/lib/src/export/`, with the ANVL-151 JS-values fixture as its test.
- Nested JSON, Flat JSON (full, domain, selection) and CSV presets ported; byte-identical to the ANVL-151 preset fixtures for a context read through the Dart SQLite layer (REAL columns as doubles), not only a JSON-decoded one.
- Template renderer ported from the spike (lexer, parser, JS-precedence pass, evaluator, 15 filters) with the ANVL-151 parity corpus and the three template fixtures as tests: every `guide.*` and `edge.*` case matches; every unsupported case is a parse-time `unsupported` error.
- `export_key` and `json` keep Electron semantics (meta ids are not resolved; `json(0)` is compact).
- `export_key` uses an id index built once per render, not a linear scan per call.
- Render limits (iterations, output and intermediate string size, total string work, nesting) with defaults recorded in the design; rendering runs off the UI isolate.
- `checkTemplate(source)` API returns kind, message, line and column; the export service exposes per-template status for the UI (warning UI tracked under ANVL-149).
- No dependency on package:flutter or a third-party template engine; `dart test` in anvil_core covers all of the above.
- The 0.2.0 writing guide text lists exactly the supported subset and states that `export_key` does not resolve meta ids.

### 19.2 ANVL-148: application shell and shared UI

| # | Summary | Goal | After |
| :---- | :---- | :---- | :---- |
| S1 | App bootstrap: error zones, logging, providers, persisted theme and minimum window size | `main()` with `runZonedGuarded` and the error hooks, `ProviderScope` with the root overrides, the theme driven by app settings, and 900×600 set in both runners, which forward close requests to the framework. | C3 |
| S2 | Welcome page and project lifecycle UI | Create dialog with folder picker, open, recent list with remove and clear, and the lock-conflict, upgrade-copy and recovery-mode dialogs. | C2, S1 |
| S3 | Shell route, sidebar and app bar | `go_router` configuration, sidebar with counts, badges and collapse, project name in the app bar, and the route-or-dialog editor helper. The save status indicator is ANVL-163. | S2 |
| S4 | Hamburger menu and shortcut registry on MenuAnchor and Shortcuts/Actions | The five menu sections, the 24 shortcuts as intents with user overrides, dispatch of Save, Undo and Redo to the focused editor, the cheatsheet dialog and UI zoom; no `UndoTextIntent` binding. | S3 |
| S5 | Shared editor scaffold | The draft-synced text field, header, save bar, dirty dots and validation banner on the ANVL-159 controller, plus the dirty-editor registry with the exit prompt (§8.8). The leave guard is ANVL-161 and the keyboard layer with its routing tests is ANVL-162. | C4, S3, ANVL-159 |
| S6 | Shared list scaffold | Toolbar, empty state, multi-select and bulk toolbar with the impact dialog, Active/Archived with restore and permanent delete, and the inspector rail. Instant actions with Undo are ANVL-166 and context menus are ANVL-117. | C9, S3 |
| S7 | App settings dialog | General, Appearance and Editor tabs: theme file picker with the parser's messages, editing mode, default save location and shortcut overrides. | S4 |
| S8 | Project settings dialog with buffered meta lists | The four tabs, the ANVL-121 buffer committed by `saveProjectSettings`, click-time in-use refusal, and the Custom Fields tab with immediate persistence and the category and NPC type rails. Moving the buffer onto a draft with undo is ANVL-165. | C6, S4 |

### 19.3 ANVL-149: domain editors

| # | Summary | Goal | After |
| :---- | :---- | :---- | :---- |
| E1 | Abilities list and editor | Details, Stat Modifiers and Used By on the draft model, with archive and bulk actions from the shared list. | C7, S5, S6 |
| E2 | Items list and editor | Category and rarity, the category-scoped custom fields panel, Used By. | C8, S5, S6 |
| E3 | Recipes list and editor | Output and quantity, station and specialization, the ingredient list with reorder, and the output-as-ingredient blocker. | C8, S5, S6 |
| E4 | Loot tables list and editor | Entries with integer weights, quantity ranges and computed drop percentages, Used By. | C8, S5, S6 |
| E5 | Classes list and editor: details, metadata and abilities | Identity, resource multiplier and metadata fields, ability assignments in the draft (undoable), Used By. | C7, S5, S6 |
| E6 | Class stat growth and derived stats tabs | The growth grid with manual and formula modes and the switch-to-manual dialog, the `fl_chart` chart, derived stat overrides with breakpoints and cycle markers. The fill helper stays in ANVL-140. | E5, C5 |
| E7 | NPCs list and editor | Type and loot table, class assignments with the inherited stat block and overrides, ability assignments, type-scoped custom fields. | C9, S5, S6 |
| E8 | Dashboard and validation panel | Dashboard tiles (counts with weekly deltas, save history feed, validation tile, quick add) and the validation page grouped by domain and severity with click-to-navigate. | C9, C10, S3 |
| E9 | Recycle bin page | All soft-deleted records by domain with individual and bulk restore and permanent delete, and the double-confirmed Empty Trash. | C9, S6 |
| E10 | Export page and template editor | Scope and record selection, the preset and template selector with unsupported-template warnings, preview, execute through the save dialog, and the template editor with the 0.2.0 writing guide (its draft and undo are ANVL-165). | C12, S3 |

### 19.4 ANVL-150: release and cutover

**R1. Write the 0.2.0 upgrade notes for 0.1.x users** (after E1 to E10). Goal: release-notes and README text covering record-level save in place of auto-save, templates that need edits, the closed 0.1.6 template escape, the native window frame and where settings and logs now live. ANVL-167 (Windows installer, plus the release workflow and bump scripts that the `pubspec.yaml` and `ci.yml` comments assign to it), ANVL-168 (Linux packaging), ANVL-169 (cutover), ANVL-143 (install scripts) and ANVL-156 (project templates) cover the rest of the epic.

---

*End of Document*

# Anvil — Claude Code Project Instructions

## Project Overview

Anvil is a desktop RPG data management tool for game designers, built with Flutter for **Windows and Linux**. It gives structured editors for six game data domains (Character Classes, Abilities, Items, Crafting Recipes, NPCs, Loot Tables), project-level settings (stats, rarities, crafting stations and specializations, derived-stat formulas, custom field schemas), project-wide validation, a recycle bin, and an export engine with three built-in presets and user templates in a Nunjucks-compatible subset. A project is one SQLite file (`.anvil`) inside a project folder.

**Current release: 0.2.0**, the Flutter rewrite. `0.2.0-rc.1` was published on 2026-11-03 and checked on Linux; ANVL-169 (this cutover) removed the Electron app from the repository, and the 0.2.0 final is cut from `v0.2.0/main` after it. The next cycle is **0.2.1** (cleanups and follow-ups found during the rewrite, including ANVL-207).

**History.** 0.1.0 to 0.1.6 were an Electron + React + TypeScript app; 0.1.6 (2026-10-11) was the last of them. Its source is at git tag `v0.1.6` and is described by `design_notes/Anvil_Implementation_Design_v1_0.md`. It is the reference for "what 0.1.6 did" whenever a behaviour question comes up, and the oracle generators under `packages/anvil_core/test/fixtures/` run from a checkout of that tag. 0.2.0 opens 0.1.x project files unchanged and keeps their lock file format, so the two versions respect each other's locks.

---

## Key Documents

| Document | Purpose |
| :---- | :---- |
| `design_notes/Anvil_Implementation_Design_v2_0.md` | **Current architecture** (ANVL-155): core/UI and repository boundaries, `sqlite3` raw SQL with the inherited migrations, the Riverpod 3 record-level save model and save blockers (§8.9), the export renderer, formula and validation off the UI isolate, project lifecycle, packaging, testing, future-cloud notes. Decompose new work against it. |
| `design_notes/Anvil_Implementation_Design_v1_0.md` | **Superseded.** The Electron 0.1.x architecture; read it with the `v0.1.6` tag when porting questions come up. |
| `docs/testing.md` | How to run the root and core test suites, the fixture rules and the test conventions. |
| `docs/upgrade-0.2.md` | User-facing note for 0.1.x users (ANVL-201); prepended to every 0.2.0 release body after it publishes. |
| `packages/anvil_core/test/fixtures/README.md` | The Electron 0.1.6 fixture set (`sample-0.1.6.anvil`, the `sqlite_master` after each migration, export contexts and preset outputs) and how its generators are run from the `v0.1.6` tag. The formula, validation and export oracles have their own READMEs beside them. |
| `spikes/` on branches `v0.2.0/ANVL-151-template-engine-spike` and `v0.2.0/ANVL-158-save-model-prototype` | Spike code and `FINDINGS.md` behind the export-engine and save-model decisions. Never merged; the v2 design records the outcomes. |
| `archive/` | **Disregarded and gitignored** (may be absent). It holds the old PRD; the code base's behaviour is the source of truth for what the product does. A features-and-functions document is planned closer to 1.0.0. |

---

## Repository Layout

- `lib/` — the Flutter app (`package:anvil`). `lib/main.dart` boots it; everything else is under `lib/app/`.
- `test/` — the app's widget and controller tests.
- `packages/anvil_core/` — the pure-Dart core in the same pub workspace: database, migrations, project lifecycle, settings and logging, domain types, repositories, formula engine, validation, export, undo history. Its own `test/` and `test/fixtures/`.
- `linux/`, `windows/` — the platform runners. `windows/installer/anvil.iss` is the Inno Setup script; `linux/packaging/` holds the nfpm, AppImage and desktop-entry files.
- `scripts/release/` — `bump-version.sh` / `.ps1` (vendored from `tkforgeworks/.github`), `build-windows.ps1`, `build-linux.sh`.
- `scripts/install/` — the user install and update scripts and their container tests (ANVL-143).
- `resources/icon.png` — the source of the app icon (the Windows `.ico` and the Linux packaging icon are built from it).
- `.fvmrc` pins Flutter **3.47.5**, the same version CI uses (`fvm use 3.47.5`, then `fvm flutter …`).

Checks, from the repo root: `dart format --set-exit-if-changed .`, `fvm flutter analyze`, and `fvm flutter test test packages/anvil_core/test`. A bare `flutter test` runs only the root `test/`; the core's suite needs its path (or `dart test` inside `packages/anvil_core`).

---

## Architecture Decisions (Do Not Reverse Without Discussion)

Recorded with their reasons in the v2 design. Raise a question before deviating from any of them.

- **One process, two packages.** `packages/anvil_core` takes every non-UI responsibility (database, files, migrations, lock, formula, validation, export) and never imports `package:flutter` or Riverpod; its pubspec has no Flutter dependency, so such an import fails analysis, and everything in it runs under `dart test`. The app depends on the core, never the reverse. Isolation where needed is by isolate.
- **SQLite through `package:sqlite3` 3.x, raw SQL, no ORM.** Its build hooks bundle SQLite on Linux and Windows. Drift was rejected: the schema is inherited and must stay byte-compatible. Pragmas `journal_mode = WAL` and `foreign_keys = ON`. Copies and backups go through `VACUUM INTO`, never a file copy of an open WAL database. `sqlite3` is a dependency of the core only.
- **Migration compatibility contract.** `schema_migrations(filename, applied_at)` and the filenames `001_init` … `007_save_history` are 0.1.6's, `currentSchemaVersion = 7` is written to `project_info.schema_version`, and the Dart migrations hold 0.1.6's SQL byte for byte. Upgrading an older file first copies the original. Proven by tests against the Electron-made fixture: it opens with no pending migrations, and a fresh Dart-made project has an identical normalised `sqlite_master`. A new migration is `008_…` in both the filename and the Dart file.
- **Repository boundary.** One `abstract interface class` per domain (plus meta, custom fields, templates, save history and lifecycle), returning `Future`s and taking domain types and drafts; no SQL or `sqlite3` type crosses it. The `Sqlite*` implementations share one `ProjectDatabase`. Editors depend on the interfaces through providers, so a cloud backend, backup hook or sync layer can wrap them without touching editors.
- **Record-level save model** (ANVL-157). Riverpod 3 without codegen. One immutable, value-equal draft per editor, keyed by record id, in an `AsyncNotifier` family. Save is per record, in one transaction, with one `save_history` row. There is no project-level save, dirty flag, auto-save timer or change accumulator. A notifier's `build()` watches only stable providers and reads volatile settings at call time. Undo history (`DraftHistory<T>`) lives in the core.
- **Save blockers vs validation.** Blockers are pure per-domain functions in the core (`lib/src/domain/`), run by the editor controller on every edit and by the repository before the transaction, so a blocked save writes nothing. Project validation reports issues and never blocks a save. The tables of blockers are design §8.9.
- **Keyboard layers.** The app-shell shortcut layer never binds `UndoTextIntent` / `RedoTextIntent`. Each editor has its own shortcut layer around an autofocus `FocusScope`, with draft undo/redo disabled while an `EditableText` has focus, so text undo stays the framework's inside a field.
- **Kept from 0.1.x:** three-part record identity (internal id, display name, export key — never conflated); soft delete by default with hard delete only from archive views and the recycle bin; custom fields scalar or enum only (`text`, `integer`, `decimal`, `boolean`, `enum`), no cross-domain reference fields; integer loot weights; Abilities and Loot Tables as first-class domains; the Nested JSON / Flat JSON / CSV presets as code, byte-identical to 0.1.6.
- **Export templates** are rendered by a purpose-built Dart renderer of a Nunjucks-compatible subset, safe by construction (no host calls, includes, macros or recursion; render limits; off the UI isolate). Output is byte-identical to 0.1.6 for supported features. Templates using unsupported features are detected on load, shown with line and column, disabled in the selector and never rewritten. (0.1.6's Nunjucks was not sandboxed — a template could run JavaScript with Node's `process` — and 0.2.0 closes that.)
- **Shell stack.** `forge_ui` for theme, tokens, fonts and shared widgets; `go_router` with 0.1.x's modal / full-page editing mode kept; the native OS window frame with a 1400×600 minimum set in the runners (0.1.6's frameless custom title bar is dropped; ANVL-207 makes the Linux frame follow the desktop outside GNOME; a frame drawn in Anvil's own theme would reverse this decision and needs discussion first); a `MenuAnchor` hamburger menu and `Shortcuts`/`Actions` for the shortcut registry; `fl_chart` for charts.
- **Project lifecycle.** The `{ProjectName}/database/exports/temp/logs/` folder, the `<file>.anvil.lock` sidecar in 0.1.6's JSON, the recent-projects list and app settings in the application support directory, non-destructive migration on open, file logging with 5 MB rotation.
- **Future cloud stays notes, not scope:** a whole-file backup through `forge-core` would attach via a snapshot and a `BackupTarget` interface; record-level sync would need change timestamps or a change log (a new migration), a conflict policy and a remote repository implementation, none of which touch editors.

---

## The Core (`packages/anvil_core/lib/src/`)

- **`db/`** — `ProjectDatabase` owns the handle privately (`open`, `openReadOnly`, `close`, `integrityCheck`, `snapshot`, `checkpoint`, `read`); the raw handle is an `@internal` getter for the core's own repositories. `saveTransaction(description, body)` is the one write path: `BEGIN IMMEDIATE`, the body through a `SaveScope`, one `save_history` row (`is_auto_save = 0`), the trim to `saveHistoryLimit = 50`, `COMMIT`; any throw rolls back, a `UNIQUE` failure on `export_key` becomes `DuplicateExportKey`, other `SqliteException`s `SaveFailed`, and nesting inside another `saveTransaction` or `read` throws `StateError`. `errors.dart` holds the boundary types `IntegrityCheckFailed`, `MigrationFailed`, `RecordNotFound`, `SaveBlocked`, `DuplicateExportKey`, `MetaInUse`, `SaveFailed`; a `SqliteException` never escapes a public method. `save_descriptions.dart` is the history vocabulary (`Fireball - Ability changed`, `3 items deleted`, `Project settings changed`, …). `migrations/` and `migration_runner.dart` implement the contract above.
- **`project/`** — `ProjectService(supportDirectory:)`: `create` (folder tree, lock, migrate, apply the chosen `ProjectTemplate` in one plain transaction with no history row, integrity check; removes the whole tree on failure as `ProjectCreateFailed`), `open` returning the sealed `OpenResult` (`ProjectOpened` / `ProjectNeedsUpgrade` with the lock held until `upgradeCopy` or `cancelUpgrade` / `ProjectRecovery`) and throwing `ProjectLocked` with 0.1.6's message, `upgradeCopy` to `{name}_backup_{17-digit UTC timestamp}.anvil`, `close` (refreshes the recent entry, checkpoints `TRUNCATE`), `saveAs` and `backup` through `snapshot`, `refreshMetadata(session)`. The pre-open checks run on an isolate over a read-only connection so an unupgraded file stays byte-identical. `ProjectLock` has no stale-lock detection. `RecentProjects` keeps 10 entries in 0.1.6's shape. `ProjectSession` carries the metadata, the database and the eleven repositories as interface-typed fields. `templates/` holds `ProjectTemplate { blank, fantasyRpg, sciFiRpg }` (ids `blank` / `fantasy-rpg` / `sci-fi-rpg`); Blank is exactly migration 002's seed.
- **`settings/`, `logging/`** — `AppSettings` (the eight 0.1.6 keys; the `autoSave*` keys are read and written back but unused) and `AppSettingsStore`, which round-trips a 0.1.6 file byte for byte; `parseCustomThemeFile` with 0.1.6's messages; `AppLogger` (`<ISO ms timestamp> [TAG] message`, appends that never throw, rotation at 5 MB keeping `.1`–`.3`, `anonymizePath`). The app passes the file paths in; the core imports no `path_provider`.
- **`domain/`** — per domain an `XRecord` (list row), `CreateXInput` and an immutable `XDraft` with hand-written `==` / `hashCode` / `copyWith` (nullable fields clear through the `unset` sentinel, proven by the `draftLaws` test helper). Drafts carry no id or timestamps; junction lists are ordered with `sort_order` as the index. The save blockers (`classSaveBlockers` … `npcSaveBlockers`) return `SaveBlocker(field, message)`. Also `resolveStatGrowth`, `computeNpcStatBlock`, the meta types and `ProjectSettingsDraft` (unsaved rows have `new:` ids), custom field types, `RecordListMode { active, all, deletedOnly }`, `LifecycleDomain`.
- **`repositories/`** — every domain repository has the same shape: `list({mode})` ordered by display name ignoring case, `countActive`, `get`, `load` (the draft), `create` and `duplicate` returning the `XRecord`, `save(id, draft)` (blockers, then a Dart export-key check, then `UPDATE … WHERE deleted_at IS NULL` requiring one row, then delete-and-reinsert of every junction, in one `saveTransaction`, returning the read-back draft), `softDelete` / `restore` / `hardDelete`, `usedBy`. Unknown ids throw `RecordNotFound`. Copies get `<slug>-<8 uuid chars>` keys. A hard delete a foreign key refuses arrives as `SaveFailed`. `MetaRepository` has the seven meta lists, `checkInUse` with 0.1.6's reason strings, and `saveProjectSettings` committing the scalars and five buffered lists in one transaction. `CustomFieldRepository` keeps the field type immutable and refuses deleting a definition or enum option still in use (`SaveBlocked`). `LifecycleRepository` does the cross-domain bulk operations, `emptyTrash` (0.1.6's table order, so a trashed class still referenced by a trashed NPC fails the whole operation — pinned by a test), `computeDeleteImpact` and `weeklyDeltas`. `TemplateRepository` and `SaveHistoryRepository` round it out.
- **`formula/`** — the 0.1.6 grammar and every error message verbatim, with JavaScript number semantics (`parseFloat` prefixes, NaN and ±Infinity as values, division failing only on exact zero). `evaluateFormula` / `validateFormula` / `extractVariableNames`, `FormulaEngine` with parse and evaluation caches, `evaluateBatch` on an isolate at or above `isolateThreshold = 10000`, depth limits (`maxFormulaNestingDepth = 1000`, evaluator 2000), `findDerivedStatCycle`. The parity corpus is 222 cases. Known non-parity: 0.1.6 resolved `Object.prototype` member names as variables.
- **`validation/`** — `validateProject(db)` runs every 0.1.6 check family in 0.1.6's order with identical messages, fields and severities; `validateRecord(db, domain, id)` returns exactly that record's subset; `ValidationService(projectPath:).runProject()` runs on an isolate over its own read-only connection. Issue order within a family relies on SQLite row order, as 0.1.6 did.
- **`export/`** — `js_compat.dart` (JavaScript number formatting and `JSON.stringify` order), `presets.dart`, `context_assembler.dart` (no dependency auto-include; 0.1.6 never had one), `ExportScope` (`full` / `domain` / `selection`), `ExportService(projectPath:)` on an isolate (the validation gate `ExportBlocked`, assembly, preset rendering; templates go to `renderTemplateIsolated`, killed on timeout, default 10 s, `RenderTimeout`), `template/` (lexer, parser, evaluator, 15 filters including `export_key`; `RenderLimits` with a parse-time nesting cap of 200; `checkTemplate`), `writing_guide.dart`. The parity corpus is 149 cases (129 byte-identical, 20 unsupported by design).
- **`draft/`** — `DraftHistory<T>`: `start`, `edit(next, {coalesceKey, now})` with 500 ms same-field coalescing, `undo`, `redo`, `rebase({saved, persisted})` after a save, `discard`, `isDirty`, `maxDepth = 200`.

---

## The App (`lib/app/`)

**Bootstrap and providers.** `lib/main.dart` runs inside `runZonedGuarded`, creates the logger under `<support dir>/logs/`, installs the `FlutterError` / `PlatformDispatcher` hooks, reads `app-settings.json` before the first frame and starts a `ProviderScope` with `rootOverrides(...)` (`lib/app/providers.dart`). `projectSessionProvider` holds the open `ProjectSession` or null. `AppExitHandler` runs the unsaved-changes prompt on an exit request, then closes the project (checkpoint, unlock) before logging the shutdown line. The runners enforce 1400×600 and open at 1400×800.

**Provider rules.**
- **Widgets never `ref.watch` `requireSessionProvider` or a repository provider.** A widget still watching when the session clears gets a `StateError` before the router leaves the shell. Widgets watch the nullable session; only providers and notifiers watch the throwing ones.
- **`writeEpochProvider`:** every code path that writes through a repository calls `bump()` once after the write returns. Lists, counts, badges, the dashboard and validation re-read on it (replacing 0.1.6's two-second polling); `validationIssuesProvider` reruns 500 ms after the last bump; `checkpointSchedulerProvider` runs a `PASSIVE` checkpoint 5 s after the last bump.
- Time comes from `clockProvider` (tests override it); dialogs that must open from the shortcut layer use `rootNavigatorKeyProvider`.

**Theme** (`theme/`). `anvilTheme()` builds every mode (Dark, Light, Custom from a theme file) through `forgeTheme(...)` at `ForgeDensity.desktop`; `AnvilColors` (`context.anvil`) holds only the Anvil-only roles `primaryEmphasis`, `textDisabled` and `chartSeries`. See the colour rule under Development Conventions.

**Shell** (`shell/`). `app_router.dart`: one `GoRouter` with `/welcome` outside a `ShellRoute` and `/`, each domain list, `<location>/:id`, `/validation`, `/recycle-bin`, `/export` inside it, redirected by the session, `NoTransitionPage` everywhere, and an `onExit` leave guard on every editor route. `ShellDomain` is the domain enum the shell uses. `openEditor(context, ref, domain, id)` reads the editing mode at call time (full page → `go`, modal → `EditorDialog`, guarded by a `PopScope`). `placeholders.dart` is the page registry each domain registers into. Also the sidebar (220 / 56 px, counts and badges), the save status indicator and the checkpoint scheduler.

**Editor framework** (`editor/`).
- `RecordEditorController<T>` is the base every domain editor subclasses, as `AsyncNotifierProvider.autoDispose.family<…, EditorState<XDraft>, String>`, with the hooks `domain` / `loadDraft` / `saveDraft` / `blockersFor` / `displayNameOf`, a protected `edit(change, {coalesceKey})`, and `undo` / `redo` / `discard` / `save()` (bumps the epoch once on success).
- `dirtyEditorsProvider` lists every dirty editor (`DirtyEditor`, or `DirtyEditor.other` for dialogs such as Project Settings and the template editor); `saveStatusProvider` derives the app-bar status. `confirmLeaveAll` / `confirmLeaveEditor` are the prompts; `leaveGuardProvider` is what the lifecycle notifier asks before closing or switching projects.
- `RecordEditorScope` + `RecordEditorShortcuts` are the editor keyboard layer (Ctrl+S, Ctrl+Z, Ctrl+Shift+Z / Ctrl+Y).
- Shared widgets in `editor/widgets/`: `EditHeader`, `SaveBar`, `DirtyDot` with `dirtyTabs`, `DraftTextField`, `DraftPicker` (pickers use `DropdownButton` or menu anchors, never `DropdownMenu`), `NumberDraftField` / `IntDraftField`, `CustomFieldsPanel`, `ValidationBanner`, and `recordValidationProvider` (runs `validateRecord` after a save). `export_key_slug.dart` is the one key slugifier for create dialogs (the core's `slugify` is `@internal`). New domain UI uses these and adds nothing private.

**List framework** (`lists/`). A domain list implements `ListDomainAdapter<R>` (rows, columns, sort options, search text, the single-record writes); `RecordListController<R>` (through `recordListProvider<R>(adapter)`, one provider per adapter object) holds view, query, sort and selection across reloads; `RecordListPage<R>` composes the toolbar, bulk toolbar, `RecordTable<R>` (sortable, horizontally scrollable, right-click context menu in the Active view) and the dialogs; `showUndoSnackBar` gives every instant action (delete, restore, duplicate, bulk) a 5 s Undo.

**Domains** (`domains/<domain>/`). Each of abilities, classes, items, recipes, loot_tables and npcs has an editor controller, an editor page (0.1.6's tabs, dirty dots, an inspector rail where 0.1.6 had Used By, Duplicate disabled while dirty), a list adapter and list page, a create dialog, its lookup providers, and `<domain>_pages.dart` registering both pages into `placeholders.dart` (file names vary a little between domains, e.g. `recipes_lookups.dart`, `item_meta_providers.dart`). The class editor also has the Stat Growth tab (M/F per stat, fill, interpolate, the formula fill helper, the `fl_chart` growth chart) and the Derived Stats tab.

**Other pages.** `welcome/` and `project/` (welcome page, create dialog with template picker, `ProjectLifecycleNotifier` sequencing open/create/upgrade/close/save-as/backup), `dashboard/` (hero, count tiles, save history, validation tile, quick add, Backup), `validation/` (the grouped issue list with click-through), `recycle_bin/`, `export/` (export page and template dialog), `settings/` (Application Settings with General / Appearance / Editor / Shortcuts; Project Settings with buffered lists committed on one Save, while the Custom Fields tab persists immediately), `menu/` (the menu commands, the 23-entry shortcut registry with user overrides, the global shortcut layer, zoom, About).

**Plugin imports are confined to one place each:** `go_router` under `lib/app/shell/`; `file_selector` in `lib/app/dialogs/file_dialogs.dart` (`FileDialogs`, faked in tests); `url_launcher` in `lib/app/menu/external_links.dart` (absolute `https` only); `package_info_plus` in `lib/app/menu/about_dialog.dart`; `fl_chart` in `lib/app/domains/classes/classes_growth_chart.dart`.

---

## Domain Model Summary

Six first-class domains, each with full CRUD, soft delete, archive view, export participation and (where applicable) custom fields:

1. **Character Classes** — stat growth per level (manual or formula per stat), derived-stat formula overrides, metadata fields usable in formulas, ordered ability assignments.
2. **Abilities** — reusable records assignable to classes and NPCs, with stat modifiers.
3. **Items** — categorised and rarity-tiered, with per-category custom fields.
4. **Crafting Recipes** — output item and quantity, ordered ingredients, station and specialization.
5. **NPCs** — typed (per-type custom fields), class-based stat inheritance (additive across classes, per-stat overrides), abilities and a loot table.
6. **Loot Tables** — integer-weighted entries referencing items, with quantity ranges.

---

## CI & Release

**Workflows** (`.github/workflows/`), both calling org reusable workflows in `tkforgeworks/.github` with `flutter-version: '3.47.5'` (the same pin as `.fvmrc`):

- **`ci.yml`** — on pushes to non-main branches and on pull requests to `main` and `v*/main`. Two jobs on `ci-flutter.yml@main` (`pub get`, format, analyze, test): `ci` at the root and `core` in `packages/anvil_core`, because a bare `flutter test` runs one package. The checks are `ci / ci` and `core / ci`.
- **`release.yml`** — on pushes to `main` and `v*/main`, one job on `release-flutter.yml@main` with `ticket-prefix: ANVL`, `build-windows: true`, `build-linux: true`, `build-android: false`, `secrets: inherit`. The version is `pubspec.yaml`'s (`X.Y.Z[-rc.N]+BUILD`; `+BUILD` is not part of the tag). It skips when the tag exists, an RC version on `main`, or a stable version on a release branch. Otherwise: release notes, a `ci-flutter.yml` gate at the root only (the core tests are covered by the PR's `core / ci`), `build-windows.ps1` on windows-latest and `build-linux.sh` on ubuntu-22.04 in parallel, a draft with all five files, then publish, which creates the tag. `build-linux` is the one allowed input added to `release-flutter.yml` (a new target platform sits beside `build-windows` / `build-android`); any other new pipeline capability is its own org reusable workflow.

**Windows packaging** — Inno Setup 6, `windows/installer/anvil.iss`, built by `scripts/release/build-windows.ps1` (release build, VC++ runtime DLLs into the bundle, `ISCC /DAppVersion=… /DSourceDir=…`, zip of the bundle) → `anvil-<version>-windows-x64-setup.exe` and `anvil-<version>-windows-x64.zip`. Per-user by default or all users (`{autopf}\Anvil`), Start Menu and desktop shortcuts, an uninstaller that keeps app data. The AppId `{C4D7B55B-5739-4101-B405-A93BF69507B4}` must never change. `PrepareToInstall` silently runs the 0.1.x uninstaller it finds under electron-builder's key `268ba5f3-2477-54c8-a960-331b2ce83d97` (HKCU, and HKLM in an all-users install). App data lives in `%APPDATA%\TK ForgeWorks\Anvil`; 0.1.x's `%APPDATA%\Anvil` is left unread. Unsigned, so SmartScreen warns.

**Linux packaging** — `scripts/release/build-linux.sh`: release build, then nfpm 2.48.0 (deb, rpm from `linux/packaging/nfpm.yaml`) and appimagetool 1.9.1 with the type2 runtime (AppImage), all downloaded at pinned versions with sha256 checks, → `anvil-<version>-linux-x86_64.AppImage`, `-linux-amd64.deb`, `-linux-x86_64.rpm` (`--skip-flutter-build` reuses a bundle). The packages keep 0.1.x's name `anvil` and `/opt/Anvil` so apt and dnf upgrade 0.1.x in place, link `/usr/bin/anvil`, and install `com.tkforgeworks.anvil.desktop` (the GTK application id) and its icon. An RC's package version is `X.Y.Z~rc.N` (the deb's full version carries nfpm's revision, `X.Y.Z~rc.N-1`), so it sorts below `X.Y.Z`. `postinstall.sh` (deb postinst, rpm `%posttrans`) restores `/usr/bin/anvil`, which 0.1.6's removal scripts delete during the upgrade. The glibc floor is computed from the bundle (2.34), which is why the job builds on ubuntu-22.04; a local build on a newer distro runs only there and newer.

**Install scripts** — `scripts/install/install-anvil.sh` (Linux) and `install-anvil.ps1` (Windows PowerShell 5.1 and 7) install or update from a published release (newest including RCs, `--stable`, or a tag that may downgrade), verify GitHub's sha256 `digest`, never downgrade without a tag, and `--check` changes nothing. They depend on the asset names above: changing a name in `build-linux.sh`, `build-windows.ps1` or `anvil.iss` means changing the scripts too. `ANVIL_RELEASES_API` points them at a fake release; `scripts/install/test/run-container-tests.sh` is the local proof (no workflow runs them). The README's one-liners serve from `main`.

**Release notes** come from the org's `release-notes.yml` (no local copy, no extra-text input), with ticket links from the `JIRA_BASE_URL` repo variable. **Commit subjects are the changelog contract:** notes are built from subjects since the previous tag (the previous stable tag for a stable release), version-bump and merge commits are filtered out, subjects starting `Fix` or `ANVL-N: Fix …` go under Bug Fixes and the rest under Changes. Write subjects as user-readable changelog lines prefixed with the ticket key. After a 0.2.x release publishes, prepend `docs/upgrade-0.2.md` to its body with `gh release edit`.

### Release process (RC → stable)

1. Topic branches `vX.Y.Z/ANVL-N-short-topic` are cut from and PR'd into the release branch (`vX.Y.Z/main`), never into `main`. Delete them after merge.
2. **RC:** `scripts/release/bump-version.sh rc` (or `.ps1 rc`) on the release branch sets `X.Y.Z-rc.N+BUILD+1`, commits `Release candidate X.Y.Z-rc.N` and pushes; `release.yml` publishes the prerelease and creates the tag. No PR.
3. **Final:** `bump-version.sh final` sets `X.Y.Z+BUILD+1`, commits `X.Y.Z`, pushes (the release workflow skips a stable version on a release branch) and opens the release PR into `main`. Merging it cuts the stable release.
4. Never hand-edit the version or push tags; CI creates tags when it publishes. Bump scripts run only when Tim asks.

### Branching & protection (org standard)

`main` is the released state (`tkforgeworks/.github/docs/branching-and-release.md`). Two rulesets (`branch-protection-ruleset.md`):

- **`main`** (id 16447467) — PR-only, no force-push or deletion, no bypass actors. Required checks `ci / ci` and `core / ci`; strict up-to-date policy. Emergency changes mean disabling the ruleset (`enforcement: "disabled"`), acting and re-enabling.
- **`release-branches`** (id 22348077) — `refs/heads/v*/main`, blocks force-push and deletion only. Deliberately no PR rule and no required check, because the bump scripts push straight to the release branch. A red topic PR merged there is caught at the release PR into `main`.

### Jira

Project **ANVL** (team-managed Software, with Releases). Use `ANVL-N` keys in commit subjects. Every open ticket gets a fix version at creation from three buckets: the current release, the next one (e.g. `0.2.1`, where RC findings that miss the current cycle go), or `1.0.0` for big-picture items. The rewrite's tickets carry the label `flutter-rewrite`; its epics are ANVL-146 (foundation), 147 (data and domain core), 148 (shell and shared UI), 149 (domain editors), 150 (release and cutover) and 157 (save model). (The old ANV-### keys were renumbered when the project moved to ANVL in July 2026; old URLs redirect.)

---

## Known Gaps and Technical Debt

- **Packaging.** An AppImage on a host without Mesa's EGL / GLES libraries fails to start; the bundle carries `lib/libdartjni.so` (pulled in by `path_provider_android`'s `jni` plugin), dead weight on Linux. The Linux window uses a GTK header bar on every Wayland desktop (ANVL-207). The install scripts' Windows path and the Windows installer's 0.1.x replacement still need a real Windows 11 run.
- **Links.** Help > Documentation and Report a Bug open `anvil.tkforgeworks.com`, which does not resolve yet (TKFW-93 sets up the redirect).
- **Lists.** Domain list adapters read their repository through the page's `WidgetRef`, so a Delete or Restore Undo is a no-op once the page is gone (a candidate for the controller's own `Ref`). `RecordListPage` titles pages from `ShellDomain.label` (`Recipes`, `Classes`) where 0.1.6 said `Crafting Recipes` / `Character Classes`. `LootTableRecord` carries no entry count, so the loot table list has no Entries column.
- **Dialogs and sessions.** An editor or Project Settings dialog left open while the project closes sits on the root navigator and still watches the session through its providers. Opening another project from a full-page editor keeps the old record id in the location. The app-bar tooltip says `N record(s) with unsaved changes` while also counting dialog entries; the leave prompt reads `Project Settings (settings)`.
- **Data quirks kept from 0.1.6.** Empty Trash fails as a whole when a trashed class is still referenced by a trashed NPC (pinned by a test). The meta in-use checks ignore soft-deleted records while the foreign keys do not, so such a delete surfaces as `SaveFailed`. The fixture's ability `stat_modifiers_json` is keyed by stat export key and its NPC `combat_stats_json` by `hp` / `armor`, so those values exist on disk but show under no stat. An NPC class level above max level is neither a blocker nor a validation issue.
- **Smaller.** Integer and decimal custom fields accept any text. `file_selector` dialogs have no titles or type filters. A one-file CSV export saves the `--- file ---` summary text as 0.1.6 did. `toStringAsFixed(3)` may round an exact half differently from JavaScript's `toFixed`.

---

## Development Conventions

- **Colours come from the theme, never literals.** Read them through `context.colors` (`ColorScheme`), `context.forge` (`ForgeTokens`, including the warning / info / success intents and containers) and `context.anvil`; non-colour constants through `AnvilSpacing` / `AnvilRadii` / `AnvilLayout` / `AnvilType`. No `Color(0x…)`, `Color.fromARGB(…)` or `Colors.x` (other than `Colors.transparent`) outside `lib/app/theme/anvil_palette.dart` and `lib/app/theme/color_math.dart`; `test/theme/no_hardcoded_colors_test.dart` fails the build otherwise. A role or component `forge_ui` lacks is raised as a `forge-ui` ticket, not patched locally; Anvil-only roles go in `AnvilColors`. Fonts are `forge_ui`'s bundled Poppins / JetBrains Mono / Source Serif 4 (`ForgeType`, `ForgeType.code` for code and export keys, `AnvilType.numeric` for tabular figures); the app declares no fonts and never adds `google_fonts`. The app sets no scrollbar or density of its own.
- **Tests test behaviour, not implementation.** Core logic is tested with `dart test` in `packages/anvil_core`, each database test on a fresh copy of a real fixture through `FixtureCopy` (`test/db/support/fixture_copy.dart`), whose `tearDown` asserts the fixture bytes are unchanged. Parity with 0.1.6 (schema, export bytes, formula and validation results) is asserted against the checked-in fixtures; never regenerate `sample-0.1.6.anvil`, since its ids and timestamps would change. A repository or controller test over a real `Sqlite*` repository asserts the exact `save_history` rows it wrote.
- **Widget tests.** Keyboard-routing tests run under `TargetPlatformVariant.only(TargetPlatform.linux)`. Lay pages out at the real 1400 px minimum (with the 220 px sidebar where the shell is involved), never at an oversized view that hides overflow. A test that clicks through to another domain's editor must supply that domain's fakes (the harnesses take `overrides`). Harnesses that type and then undo override `clockProvider` with the tester's fake clock. A `DataCell`'s child is a gesture detector, so look for the `Text` beneath it. There are no golden tests; `forge_ui` owns the look.
- **Explicit over magic; constructor injection.** Dependencies reach the core through constructors and reach the app through providers, never globals.
- **Migrations are sequential and non-destructive** (see the contract above).
- **Lockfiles:** any `pub get` rewrites `pubspec.lock`; revert it unless the dependency change is the work.
- **License: Apache-2.0.** `LICENSE` is the verbatim Apache text and is never edited. Image assets are all rights reserved through `NOTICE`. Standard: `tkforgeworks/.github/docs/licensing.md`.
- **No half-finished commits** — every commit leaves the code base working.

---

## Roadmap

- **0.2.1** — the cleanups and follow-ups collected during the rewrite, ANVL-207, and the RC findings triaged there.
- **Later** — whether the window frame should follow Anvil's own theme (a reversal of the native-frame decision, to be discussed after ANVL-207 has been seen), and the items collected under `1.0.0` in Jira (features-and-functions document, the future-cloud notes above).

---

## CLAUDE.md Self-Update Rule

**Before completing any `git commit`, check whether this file needs updating.** Review whether any of these have changed in the session and are not reflected here:

- architectural decisions made or changed;
- documents added or superseded;
- roadmap or scope changes;
- new development conventions or test rules;
- project status (a release cut, a cycle started).

If so, update this file in the same commit. A pre-commit hook reminder in `.claude/settings.json` enforces the check. When a release ships, update the Current release line first thing on the next release branch.

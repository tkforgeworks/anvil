# ANVL-158 findings: record-level save cycle on the Recipe editor

Throwaway spike on `v0.2.0/ANVL-158-save-model-prototype`; not for merge.
Stack: Flutter 3.47.5 (fvm), Dart 3.13.4, `flutter_riverpod` 3.4.3 without
code generation, `sqlite3` 3.8.0, `path` 1.9.1. Fixture: a real project file
made with Electron Anvil 0.1.6 (`test/fixtures/sample-0.1.6.anvil`), always
copied to a temp directory before it is opened.

## Acceptance criteria

| # | Criterion | Result | Verified by |
|---|---|---|---|
| 1 | Opens a copy of a real .anvil file and loads one recipe with its ingredients | Met | `sqlite_recipe_repository_test.dart` group "AC1" (copy in a temp dir, WAL + foreign keys on, both recipes listed, Forge Iron Sword with its 2 ingredients in `sort_order`; every tearDown checks the fixture bytes are unchanged). `recipe_editor_page_test.dart` "AC1 lists the copy and opens a recipe with its ingredients". Release binary launched for 6 s on the fixture: it printed `working copy at /tmp/anvl158-…/sample-0.1.6.anvil`, `-wal`/`-shm` appeared next to the copy only, and the source SHA-256 was unchanged. |
| 2 | Dirty marker appears on edit and clears when edits are undone back to the baseline | Met | `draft_history_test.dart` "AC2: …" (2 tests); `recipe_editor_controller_test.dart` "AC2: dirty on edit, clean when typed back to the baseline", "AC2/AC3: undo steps back through ingredients and header to clean"; page test "AC2 dirty marker appears on edit and clears on undo to baseline". |
| 3 | Ctrl+Z inside a text field undoes typing; outside a field it steps back through the draft (header and ingredients) | Met (headless) | Page tests in group "AC3": "inside a field Ctrl+Z is the field undo and never the draft", "field Ctrl+Z reverts the field even when a later draft step exists", "outside a field Ctrl+Z steps the draft: ingredients, header" (add, reorder, quantity, then header text; redo with Ctrl+Shift+Z and Ctrl+Y), "editor scope has focus on open, so shortcuts work at once". Not tried with a physical keyboard on the Wayland session. |
| 4 | Leaving with a dirty draft asks Save / Discard / Cancel | Met | Page tests in group "AC4": clean editor leaves without asking; Cancel stays with the draft; Discard leaves and writes nothing (reopening shows the stored record); Save writes, leaves and the list shows the new history row; a failing Save keeps the user in the editor. |
| 5 | Ctrl+S saves while the cursor is in a text field | Met (headless) | Page test "AC5: saves while the cursor is in a text field": the field still has focus and its text afterwards, and the recipe row and history count changed. |
| 6 | Save writes the recipe, its ingredients and a history row in one transaction; a forced failure rolls all of it back and keeps the draft dirty | Met | Repository: "a save writes all three and returns the read-back draft", "a forced failure before COMMIT rolls everything back" (recipe row, ingredients and `save_history` count unchanged; `autocommit` is true again; the next save works), "a constraint failure mid-save rolls back the recipe row" (an FK failure on the ingredient insert after the UPDATE). Controller: "AC6: a forced failure keeps the draft dirty and writes nothing". Page: "AC6: Ctrl+S with the toggle on writes nothing and stays dirty". |
| 7 | Output-used-as-ingredient blocks Save with a visible message | Met | `recipe_rules_test.dart`; repository "the repository refuses the save and writes nothing"; controller "AC7: output used as ingredient blocks the save path itself"; page "AC7: blocks Save with a visible message, Ctrl+S included" (message shown, Save button disabled, Ctrl+S from editor focus and from field focus write nothing, the leave dialog's Save is disabled, undoing the change clears the block). |
| 8 | Findings noted; prototype code is not merged | Findings: met (this file). Not merging: the orchestrator's call | The spike lives only on the ANVL-158 branch. Dropping it means removing `spikes/` and reverting the root `pubspec.yaml` workspace entry and `pubspec.lock`. |

Test run: 48 tests (13 draft history, 4 rules, 8 repository, 8 controller,
15 widget), all passing.

## What was built

```
lib/src/core/   Flutter-free (dart:io, path, sqlite3 only); could move to anvil_core
  recipe_draft.dart            immutable RecipeDraft + IngredientLine, value equality
  draft_history.dart           generic DraftHistory<T>: baseline, current, undo/redo stacks
  recipe_rules.dart            save blockers (output as ingredient, duplicate, qty < 1)
  recipe_repository.dart       the interface editors see (Futures, drafts in/out)
  project_database.dart        open/openCopy, saveTransaction(), save_history reader
  sqlite_recipe_repository.dart raw SQL
lib/src/app/    Flutter + Riverpod
  providers.dart               hand-written providers
  recipe_editor_controller.dart AsyncNotifier family, one draft per recipe ID
  editor_shortcuts.dart        Ctrl+S / Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y layer
  draft_text_field.dart        TextField kept in sync with one draft string
  recipe_list_page.dart, recipe_editor_page.dart
```

## What worked

- **Value-equality draft against a baseline.** `isDirty = draft != baseline`
  needs no dirty bookkeeping: typing a value back, undoing back, or doing −
  after + all clear the marker.
- **Undo as a pure value.** `DraftHistory<T>` holds no Flutter or Riverpod
  types and is covered by plain unit tests. The rules: edits to the same
  field less than 500 ms apart are one step (matching Electron's
  `useUndoRedo`); structural edits are one step each; an edit that lands on
  the previous snapshot counts as an undo; the stack is capped at 200; after a
  save the baseline moves and the stack is kept.
- **Riverpod 3 without codegen.** `AsyncNotifierProvider.autoDispose.family<
  RecipeEditorController, RecipeEditorState, String>(RecipeEditorController.new)`,
  with the family argument passed to the notifier's constructor (Riverpod 3
  dropped `FamilyNotifier`). `autoDispose` drops the draft when the editor
  route goes away, so Discard is just `Navigator.pop`.
- **One save transaction.** `ProjectDatabase.saveTransaction(description,
  body)` runs `BEGIN IMMEDIATE`, then the repository's writes, then the
  `save_history` insert and the trim to 50 rows, then `COMMIT`, with
  `ROLLBACK` on any throw. The forced failure and a real FK failure both roll
  back completely.
- **Keyboard layering** (diagram in `editor_shortcuts.dart`). The editor's
  `Shortcuts` + `Actions` use their own intents. The draft undo/redo actions
  report themselves disabled while an `EditableText` has focus, so the key
  event keeps bubbling to the framework's `DefaultTextEditingShortcuts` and
  becomes the field's native undo. Ctrl+S has no framework binding, so it is
  handled whatever has focus inside the editor.
- **An editor FocusScope inside the shortcut layer** (`autofocus: true`) takes
  primary focus when the page opens, and again when the desktop tap-outside
  action unfocuses a field (unfocus moves focus to the enclosing scope). Editor
  shortcuts can always be reached.
- **Leave prompt.** `PopScope(canPop: !isDirty)` plus
  `onPopInvokedWithResult` opens the dialog. `Navigator.pop` ignores `canPop`,
  so Save and Discard can then leave directly.
- **sqlite3 3.x build hooks** bundle SQLite into both `flutter test` and
  `flutter build linux` (`bundle/lib/libsqlite3.so`, 1.8 MB) with no system
  dependency.

## Awkward parts and gotchas

1. **Flutter's field undo misses the original text if you type quickly after
   focusing.** `UndoHistory` saves states on a trailing 500 ms throttle, and
   it records the initial text only after focus gives the field a valid
   selection. If you type within 500 ms of focusing, the field's Ctrl+Z
   cannot get back to the original text, though the draft undo can (test
   "typing within 500 ms of focusing…"). The first widget-test run failed
   on exactly this. Fast typists will notice it.
2. **An ancestor `UndoTextIntent` action takes over every field's undo.**
   EditableText registers its undo with `Action.overridable`, so any ancestor
   `Actions` that maps `UndoTextIntent` replaces the field's own undo. A
   throwaway probe confirmed it: after Ctrl+Z the text stayed "typed" and the
   ancestor action ran. That is why the spike uses its own `UndoDraftIntent`.
   The ported menu/shortcut registry (ANVL-113) must never bind
   `UndoTextIntent` or `RedoTextIntent`.
3. **Key events reach the editor's shortcuts before the framework's.**
   Events bubble from the focused node, so the editor `Shortcuts` sees Ctrl+Z
   before `DefaultTextEditingShortcuts` at the `WidgetsApp` root. The draft
   action therefore has to step aside when a text field has focus. This is the
   Flutter form of the Electron bug, where `useUndoRedo` grabs Ctrl+Z on the
   window with `preventDefault`.
4. **If nothing in the editor has focus, the editor's shortcuts are
   unreachable.** Primary focus then sits on the route's FocusScope, which is
   above the editor `Shortcuts`. The editor's own FocusScope fixes this; tests
   assert `primaryFocus.debugLabel == 'editor'` on open and after a click
   outside a field.
5. **`DropdownMenu` contains an `EditableText`.** With focus on it, Ctrl+Z
   would be a text undo, so the spike uses `DropdownButton`. Picker choice in
   ANVL-155 should take this into account, or the check could be narrowed to
   editable fields.
6. **Riverpod 3: an editor notifier must not watch anything that changes
   during editing.** Mutation check: when `recipeRepositoryProvider` watched
   the debug toggle, two AC6 tests failed. Flipping the toggle rebuilt the
   repository, which rebuilt the editor, whose `build()` reloaded from disk and
   lost the draft. Rule: `build()` watches only stable things (project,
   repository); read volatile settings at call time.
7. **Riverpod 3 retries failing providers by default.** The tests turn this
   off up front with `retry: (_, _) => null` on `ProviderScope` and
   `ProviderContainer.test`. It never caused a failure in this spike.
   `ProviderContainer.test` and `ref.mounted` after an `await` behaved as
   documented.
8. **`sqlite3_flutter_libs` is end-of-life** (`0.6.0+eol`: "Not used anymore,
   update to version 3.x of package:sqlite3"). This machine has only
   `libsqlite3.so.0` (no unversioned `libsqlite3.so`), so the hook's
   `source: system` option would fail to load it without the -devel package.
   The bundled default is the right choice.
9. **The fixture uses a rollback journal although Electron sets WAL on open.**
   Opening the copy with WAL, as Electron does, converts the copy. A plain file
   copy of a WAL database that another process has open can miss committed
   pages that are still in `-wal`. Copies and backups should use the SQLite
   backup API or `VACUUM INTO`, not `File.copy`. Not tested against a file
   Electron holds open.
10. **Field and draft undo stacks agree on values, not on steps.**
    `DraftTextField` writes draft changes into its controller, and
    `UndoHistory` records those writes as well. The "edit back to the previous
    snapshot is an undo" rule stops a field's own Ctrl+Z from leaving no-op
    steps on the draft stack.
11. **`sqlite3` is synchronous, but the repository returns Futures** so that a
    later background isolate or remote backend does not change editor code.
    Edits are ignored while a save is in flight (microseconds here).
    `DraftHistory.rebase` already keeps a draft that changed during a save, in
    case async saves allow editing.
12. **Widget tests need `TargetPlatformVariant.only(TargetPlatform.linux)`.**
    The default test platform is Android, whose key maps and tap-outside
    behaviour differ.

## Recommendations for ANVL-155

1. **Draft shape.** One immutable `XDraft` per domain, with hand-written `==`
   and `hashCode` and a test that covers them. It holds the user-editable
   fields plus each junction list as an ordered list (ingredients, ability
   assignments, loot entries; `sort_order` is the index), and no timestamps.
   The baseline is the record as read back inside the save transaction.
   Ability and class assignments, which Electron kept out of undo and saved
   immediately, become part of the draft, so they are undoable and saved
   atomically.
2. **Where undo lives.** A generic pure-Dart `DraftHistory<T>` in
   `anvil_core`, held in each editor's `AsyncNotifier` family state (keyed by
   record ID). The notifier exposes intent methods (`setDisplayName`,
   `addIngredient`, `undo`, `save`). Widgets never touch the history. Inject
   the clock with a provider so coalescing can be tested.
3. **Shortcut layering.**
   - The framework's `DefaultTextEditingShortcuts` owns text-editing keys
     inside fields.
   - The app-shell `Shortcuts` holds app-level intents (the ported ANVL-113
     registry) and never binds `UndoTextIntent` or `RedoTextIntent`.
   - Each editor gets a `RecordEditorShortcuts` layer wrapping an
     `autofocus` FocusScope, with `SaveRecordIntent` (Ctrl+S, works in
     fields) and `UndoDraftIntent`/`RedoDraftIntent` (Ctrl+Z, Ctrl+Shift+Z,
     Ctrl+Y). Their actions are disabled while an `EditableText` has focus.
   - Dialogs are separate routes and fall outside it automatically.
4. **Save transaction.** Every domain repository uses one
   `saveTransaction(description, body)` (a unit of work):
   - `BEGIN IMMEDIATE`
   - the domain writes: UPDATE the row, including `updated_at`, with
     `WHERE deleted_at IS NULL` and `updatedRows == 1`, otherwise
     not-found; then DELETE and re-INSERT the junction rows
   - read the record back
   - INSERT the history row (`"<Domain> '<name>' changed"`, `is_auto_save`
     0) and trim to 50 rows
   - `COMMIT`; on any error, `ROLLBACK` guarded by `!db.autocommit`

   Run the blocking rules in the notifier (UI state) and again inside the
   repository save. With one save per record, the Electron change
   accumulator and its tiered descriptions are not needed. Decide what
   `is_auto_save` means once project-level auto-save is gone. If multiple
   windows or sync are planned, consider an optimistic `updated_at` check
   against the baseline.
5. **Repository interface (cloud-backup goal).** One `abstract interface
   class` per domain in `anvil_core`, returning Futures, drafts in and drafts
   out: `listX()`, `loadX(id)`, `loadLookups()`, `saveX(draft) → draft`, and
   later archive/restore/delete. No SQL or sqlite3 types cross it; the
   transaction and the history row stay inside the implementation, and the
   raw database handle stays private to the data layer. Editors get the
   repository from a root-overridden `Provider`. A backup or sync layer can
   then wrap the implementation (for example, emit a change record after
   COMMIT) without touching editors.
6. **Storage.** `sqlite3` ^3.8 with the default hook-bundled SQLite, opened
   with `foreign_keys = ON` and `journal_mode = WAL` as Electron does. Make
   copies and backups through the backup API or `VACUUM INTO`.
7. **Tests.** Open a fresh copy of a real fixture in each test (the
   `FixtureCopy` pattern). Unit-test history and rules in pure Dart.
   Widget-test keyboard routing under the Linux platform variant (and
   Windows once that runner exists). Keep editor providers' dependencies
   stable, and keep a test that toggles settings mid-edit and asserts the
   draft survives.

## Deviations from the brief

- No `sqlite3_flutter_libs`: the package is end-of-life and `sqlite3` 3.x
  bundles SQLite itself. Rejected alternative: adding the EOL stub.
- Quantities use −/+ steppers, not numeric text fields. This keeps the
  text-field/draft sync to the three header strings. Rejected alternative:
  numeric fields, which raise parse-error-versus-int-draft design questions
  outside the ACs.
- The fault hook fires after the recipe row, the ingredients and the history
  row are all written, just before COMMIT. Rejected alternative: failing right
  after the recipe UPDATE, which proves less.
- Added duplicate-ingredient and quantity < 1 blockers. Without them the
  primary key and CHECK constraints would fail the save at the database
  instead. Rejected alternative: letting the database reject them and roll
  back.
- The fixture is copied into `test/fixtures/` (348 KB) so the tests are
  self-contained. Rejected alternative: reading it from the session
  scratchpad, which would not survive the session.

## Not covered

- A physical keyboard and IME on the Wayland session. The binary was launched
  but not driven; all keyboard evidence comes from headless widget tests.
- Closing the window or exiting the app with a dirty draft. This needs a
  registry of dirty editors and `AppLifecycleListener.onExitRequested`, and a
  check that the Linux and Windows runners pass close requests to the
  framework.
- Windows, more than one editor open at once (the family supports it, but
  there is no UI for it), numeric text fields, and a source file held open
  by Electron.

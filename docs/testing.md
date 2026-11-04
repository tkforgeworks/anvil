# Testing

Anvil has two test suites: the app's widget and provider tests in `test/` and the Flutter-free core's tests in `packages/anvil_core/test/`. Use Flutter 3.47.5 (`fvm use 3.47.5`, then `fvm flutter ...`; see `.fvmrc`).

## Running the tests

From the repository root:

```bash
fvm flutter test test packages/anvil_core/test      # both suites, as CI does
fvm flutter test test                               # app only
fvm flutter test packages/anvil_core/test           # core only
fvm flutter test test/shell/shell_routes_test.dart  # one file
```

A bare `fvm flutter test` runs only the root `test/` directory, not the workspace member's, so the core path must be passed. The core also runs without Flutter: inside `packages/anvil_core`, `dart test` (or `fvm dart test`) runs its suite alone.

The checks CI runs are `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test`, at the root and again with `working-directory: packages/anvil_core` (the `ci / ci` and `core / ci` checks). Run the full suite on its own, not chained with a build, and cap concurrency with `-j 4` on a small machine.

## Core tests (`packages/anvil_core/test/`)

They run under plain `dart test` and never import Flutter. Areas: `db/` (open, migrations, save transaction), `domain/`, `draft/`, `repositories/`, `project/` (create, open, upgrade, lock, recent projects), `settings/`, `logging/`, `formula/`, `validation/`, `export/`.

### Fixtures and `FixtureCopy`

`packages/anvil_core/test/fixtures/` holds the Electron 0.1.6 fixture set; its `README.md` describes every file. The project file `sample-0.1.6.anvil` is never opened directly. Database tests use `FixtureCopy` (`test/db/support/fixture_copy.dart`): call `FixtureCopy.setUpEach()` at the top of a test file's `main`, and each test gets a fresh temp directory with a copy of the fixture (`copyFixture()`, `pathFor(name)`). Its `tearDown` closes every database the test opened, deletes the directory and asserts the fixture's bytes are unchanged, so a test that writes to the original fails.

**Never regenerate `sample-0.1.6.anvil`.** Regenerating it assigns new ids and timestamps and breaks every export, validation and formula fixture built from it. The per-migration schema dumps (`schema-step-0N.json`) can be regenerated on their own with the `-t` filter described in the fixtures README.

The Electron source is no longer in this repository. The oracles that produced the fixtures (the vitest generators and the node scripts under `fixtures/export/tool/`) are kept as the record of how the files were made, and run from a checkout of git tag `v0.1.6`; the fixtures README and the `formula/` and `validation/` READMEs give the steps. Parity tests compare the Dart code against these frozen outputs: schema (`sqlite_master` after each migration), export bytes, the 222-case formula corpus, the validation issue lists and the 149-case Nunjucks corpus.

### WAL mode and external SQLite browsers

`ProjectDatabase.open` sets `PRAGMA journal_mode = WAL` and `foreign_keys = ON`. In WAL mode committed writes sit in the `-wal` sidecar until a checkpoint moves them into the main `.anvil` file. The app checkpoints `TRUNCATE` when a project closes, and a quiet-time `PASSIVE` checkpoint runs five seconds after the last write.

Consequences:

- A SQLite browser (DB Browser, DataGrip) opened on a project while Anvil has it open can show a stale view of the main file. Close the project first, or use a WAL-aware read.
- Copying an open project's file misses uncheckpointed pages. Backups and Save As go through `ProjectDatabase.snapshot` (`VACUUM INTO`), which includes the WAL; tests that assert a file changed on disk after a checkpoint therefore compare the main file's bytes.
- The fixture is in rollback-journal mode with no sidecars, which is why `FixtureCopy.copyFixture` can use a plain file copy.

## App tests (`test/`)

They mirror `lib/app/`: shell and routes, menu and shortcuts, editors, lists, each domain under `test/domains/`, dashboard, validation, export, recycle bin, settings, welcome and project lifecycle, bootstrap and theme. Most pump the real widgets over fake repositories, or over a `ProjectSession` opened on a fixture copy (`test/shell/shell_harness.dart`, the per-area `fakes.dart` files).

Conventions:

- **Keyboard routing runs as Linux.** Tests that touch shortcuts, focus or text-field undo use `TargetPlatformVariant.only(TargetPlatform.linux)` (`variant:` on `testWidgets`), so the key bindings and text-editing shortcuts are the ones the Linux build uses.
- **No hard-coded colours.** `test/theme/no_hardcoded_colors_test.dart` fails on any colour literal in `lib/` outside the palette and colour-math files.
- **No goldens.** `forge_ui` owns the look.
- **Window size.** Layout tests that depend on the 1400×600 minimum window set the test view to that size; a larger view can hide overflow.
- **Clocks.** Tests that depend on the 500 ms undo coalescing or the checkpoint timer override `clockProvider` or the timer factory rather than waiting.

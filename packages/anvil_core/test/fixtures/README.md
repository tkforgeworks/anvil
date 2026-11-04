# Anvil spike fixtures (generated 2026-10-31)

`fixtures/sample-0.1.6.anvil` was created with the Electron 0.1.6 code (migrations + repositories)
by `build-fixture.test.ts`, a throwaway vitest file. The Electron source was removed from this
repository at cutover (ANVL-169) and is reachable at git tag `v0.1.6`; every generator in this
directory is kept as the record of how its oracle was made and runs from a checkout of that tag:

    git worktree add ../anvil-0.1.6 v0.1.6
    cd ../anvil-0.1.6 && npm ci          # Node 20+, npm 10+

The generators import the 0.1.6 modules with relative paths (`../db/...`), so each is copied into
`src/main/__spike__/` of that checkout and run there, writing into a scratch directory given by an
absolute path (`$ANVIL` below is this repository's checkout). To regenerate everything:
copy `build-fixture.test.ts` to `src/main/__spike__/`, run
`FIXTURE_DIR=<scratch> npx vitest run src/main/__spike__/build-fixture.test.ts` (after
`npm rebuild better-sqlite3` for the Node ABI), then delete `src/main/__spike__/`.

Contents: seeded project with 2 classes (manual + formula stat growth, derived-stat override,
metadata, ability assignments), 3 abilities (1 soft-deleted), 6 items (1 soft-deleted, custom
fields on weapons), 2 recipes, 1 loot table, 2 NPCs (class/ability assignments, custom field),
3 custom templates, 2 save_history rows. Alongside: the full export context (`context-full.json`),
a selection-scope context, the three preset outputs, and each custom template with the Electron
rendering (`template-*.expected.txt`). `schema-sqlite-master.json` is the schema at migration 7.

Intended to become the ANVL-147 fixture set (checked into `packages/anvil_core/test/fixtures/`).

## Per-migration schema dumps (`schema-step-01.json` .. `schema-step-07.json`)

The second test in `build-fixture.test.ts`, `dumps sqlite_master after each migration step`,
builds a fresh database, applies the seven Electron migrations one at a time exactly as
`runner.ts` does (`schema_migrations` created first; `up()` plus the `schema_migrations` insert in
one transaction per step) and writes `schema-step-0N.json` after each step: the rows
`{type, name, tbl_name, sql}` of `sqlite_master` (`sql IS NOT NULL`, ordered by type, name). They
are the oracle for "migration N applied to state N-1 matches Electron". `schema-step-07.json`
equals `schema-sqlite-master.json` once projected to `{type, name, sql}`.

Run only this test, into a scratch directory, then copy the seven step files here:

    # in the v0.1.6 checkout (../anvil-0.1.6), $ANVIL = this repository's checkout
    npm rebuild better-sqlite3            # Node ABI
    mkdir -p src/main/__spike__ && cp $ANVIL/packages/anvil_core/test/fixtures/build-fixture.test.ts src/main/__spike__/
    FIXTURE_DIR=<scratch> npx vitest run src/main/__spike__/build-fixture.test.ts -t "dumps sqlite_master"
    rm -rf src/main/__spike__

Never run the first test (`builds the 0.1.6 fixture ...`) against this directory: it regenerates
`sample-0.1.6.anvil` and every export fixture with new ids and timestamps and breaks the set.

## Export engine fixtures (`export/`, ANVL-181)

The export tests (`test/export/`) use the context, preset and template fixtures above plus two
files from the ANVL-151 spike in `export/`: `js-values.json`, what node prints for 3,025 doubles,
8 `JSON.stringify` cases and 8 `String()` cases (the oracle for `js_compat.dart`), and
`nunjucks-parity.json`, the 149-case parity corpus (45 `guide.*`, 69 `idiom.*`, 32 `edge.*`,
3 `host.*`) rendered by Nunjucks 3.2.4 in 0.1.6's exact environment over `context-full.json`.
`export/tool/` holds the node oracles that wrote them (`js_values_oracle.js`, `nunjucks_oracle.js`
with the case list `parity_cases.js`), with paths adjusted to this layout; they are documentation of
how the files were made and are not run by the tests. They write next to themselves, so to add a
case, run them from this repository's `packages/anvil_core` with Nunjucks taken from the `v0.1.6`
checkout after `npm ci` there:
`NUNJUCKS=../anvil-0.1.6/node_modules/nunjucks node test/fixtures/export/tool/nunjucks_oracle.js`
(path relative to `packages/anvil_core`, adjust to where the worktree is). The Electron source is
gone from this repository, so nothing else in the oracle needs it; the JSON files are otherwise
frozen.

# Anvil spike fixtures (generated 2026-10-31)

`fixtures/sample-0.1.6.anvil` was created with the Electron 0.1.6 code (migrations + repositories)
by `build-fixture.test.ts`, a throwaway vitest file. To regenerate: copy the file to
`src/main/__spike__/build-fixture.test.ts` in the anvil checkout (node_modules installed for Node,
not Electron), run `FIXTURE_DIR=<dir> npx vitest run src/main/__spike__/build-fixture.test.ts`,
then delete `src/main/__spike__/`.

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

    npm rebuild better-sqlite3            # Node ABI
    mkdir -p src/main/__spike__ && cp packages/anvil_core/test/fixtures/build-fixture.test.ts src/main/__spike__/
    FIXTURE_DIR=<scratch> npx vitest run src/main/__spike__/build-fixture.test.ts -t "dumps sqlite_master"
    rm -rf src/main/__spike__ && npm run rebuild   # restore the Electron binary

Never run the first test (`builds the 0.1.6 fixture ...`) against this directory: it regenerates
`sample-0.1.6.anvil` and every export fixture with new ids and timestamps and breaks the set.

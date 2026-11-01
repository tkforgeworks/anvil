# Validation oracle

The expected output of the Electron 0.1.6 validation engine (`src/main/validation/engine.ts`),
which `packages/anvil_core/lib/src/validation/` must reproduce exactly, order included:

- `validation-issues-fixture.json`: `validateProject` on a copy of `../sample-0.1.6.anvil`.
- `validation-issues-mutated.json`: `validateProject` on a copy with `validation-mutations.sql`
  applied, statement by statement, after splitting the file on `;\n`.

Each entry is a 0.1.6 `ValidationIssue` without its `id` (`domain`, `recordId`,
`recordDisplayName`, `field`, `severity`, `message`), in the order the engine returned them.
0.1.6 gave every issue a random UUID, so ids cannot be compared and are left out; the Dart
`ValidationIssue` leaves `id` out of `==` and `toJson()` for the same reason.

`validation-mutations.sql` is the specification of what the oracle covers: it provokes every
0.1.6 message (broken and soft-deleted direct and junction references, required custom fields,
derived-stat syntax, level-1 runtime and cycle errors, and the three stat growth cases) and
switches the soft-delete reference severity to `Error`. It disables foreign keys first, so it
can create dangling references, and turns them back on at the end. Its ids are literal strings,
so the output is deterministic. A case the oracle should cover is added there, never to the
JSON by hand.

`test/validation/oracle_parity_test.dart` compares both lists. `validate_record_test.dart` uses
the mutated project to check that `validateRecord` returns each record's share of the project
list.

To regenerate, from the anvil checkout with `node_modules` installed (`better-sqlite3` must be
built for Node, not Electron; the oracle mocks `app-logger`, which pulls in Electron):

    npm rebuild better-sqlite3            # Node ABI
    mkdir -p src/main/__spike__
    cp packages/anvil_core/test/fixtures/validation/build-validation-oracle.test.ts src/main/__spike__/
    FIXTURE_DIR=packages/anvil_core/test/fixtures/validation \
      npx vitest run src/main/__spike__/build-validation-oracle.test.ts
    rm -rf src/main/__spike__ && npm run rebuild   # restore the Electron binary

The oracle reads `sample-0.1.6.anvil` and `validation-mutations.sql` from
`packages/anvil_core/test/fixtures/` under the working directory; set `VALIDATION_FIXTURES` to
another `validation/` directory (for example a worktree's) to read them from there. It never
writes to the fixture, only to copies in a temp directory. The oracle is regenerated until
cutover (ANVL-169) and then frozen.

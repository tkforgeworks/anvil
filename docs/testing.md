# Testing

## Repository integration tests

The repository layer has an integration test suite that runs directly under Node.js — no running Electron process or `.anvil` project file required.

### Running the tests

```bash
npm test
```

To run in watch mode during development:

```bash
npm run test:watch
```

### What is tested

Each of the six domain repositories is covered by a dedicated test file under `src/main/repositories/__tests__/`. Each test file spins up a fresh in-memory SQLite database, applies all migrations (including reference data seeding), exercises the repository against it, and discards the database at the end.

Every repository is tested for:

| Operation | What is verified |
| --- | --- |
| `create` | Record is returned with the correct fields and is retrievable via `get` |
| `list` | Active records appear; soft-deleted records are excluded by default; they reappear with `includeDeleted: true` |
| `update` | Changed fields are persisted; fields omitted from the call retain their previous values |
| `softDelete` | Sets `deleted_at`; record is excluded from the default `list` |
| `restore` | Clears `deleted_at`; record reappears in the default `list` |

The `DomainRepository` base class operations (`countActive`, `hardDelete`) are covered via `ClassRepository`.

Sub-table operations (stat growth, ability/class assignments, recipe ingredients, loot table entries, custom field values) are covered with at least one round-trip test per repository that exposes them.

### Framework

Tests use [Vitest](https://vitest.dev/) with `pool: 'forks'` (required for the `better-sqlite3` native module). The configuration is in `vitest.config.ts` at the project root.

---

## WAL mode and external SQLite browsers

Anvil enables SQLite Write-Ahead Logging (WAL mode) for every open project:

```typescript
// src/main/db/connection.ts
db.pragma('journal_mode = WAL')
```

In WAL mode, committed writes are appended to a sidecar file (`.anvil-wal`) and are not flushed into the main `.anvil` database file until a *checkpoint* occurs. A checkpoint happens automatically when the connection closes (i.e., when the project is closed or the app exits) and can also be triggered explicitly on save.

**Consequence for manual inspection:** If you open the `.anvil` file in an external tool (DB Browser for SQLite, DataGrip, etc.) while the Anvil app is running, you will see an empty or stale view of the database. The rows that appear on the Anvil dashboard exist and are committed — they are just sitting in the WAL file, not yet in the main file. This is correct SQLite behaviour, not a bug.

To inspect live data with an external browser, either:
- Close the project in Anvil first (this checkpoints and closes the connection), or
- Open the `.anvil-wal` file alongside the main file if your SQLite tool supports WAL-aware reads.

The automated tests sidestep this entirely by using in-memory databases, which never produce WAL sidecar files.

---

## Note on native module ABI compatibility

`better-sqlite3` is a native Node.js addon. The project includes an `npm run rebuild` script that recompiles it against Electron's V8 ABI for use in the packaged application.

If you have run `npm run rebuild` and the tests fail with an error like `"was compiled against a different Node.js version"`, the binary has been compiled for Electron rather than your system Node.js. Fix this by recompiling for Node.js first:

```bash
npm rebuild better-sqlite3
npm test
```

After testing, restore the Electron-compatible binary before launching the app:

```bash
npm run rebuild
```

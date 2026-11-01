# Orchestrator lessons (anvil)

## Standing context (copy into every brief)
- Flutter 3.47.5 via fvm: run every Flutter/Dart command as `fvm flutter ...` / `fvm dart ...`. `.fvmrc` is in each repo.
- Checks: `fvm dart format --set-exit-if-changed .`, `fvm flutter analyze`, tests. In anvil the core tests need the path: `fvm flutter test test packages/anvil_core/test`.
- `packages/anvil_core` never imports `package:flutter`.
- Colours never as literals outside the allowed files (anvil: `lib/app/theme/anvil_palette.dart`, `color_math.dart`; forge-ui: `forge_brand.dart`, `forge_tokens.dart`, `forge_provider_brand.dart`). A test enforces it in both repos.
- forge-ui goldens are compared exactly, generated on Linux with 3.47.5: any visual change means `cd example && fvm flutter test --update-goldens` in the same change, and the agent must look at the PNGs it regenerated.
- Subagents never commit, push, branch, open PRs or touch Jira. They edit the working tree and report.

## Never delegate
- CLAUDE.md edits (self-update rule needs the main thread's view of the session).
- Architecture decisions; the design doc's decisions are written by the main thread, agents draft prose from them.
- Anything that runs a version bump script.

## Tier calibration
- 2026-10-31, forge-ui FU-9/10/11/12: `worker` was right for a one-helper or one-widget change with a spelled-out design (FU-11, FU-9, FU-12); `worker-heavy` was right for FU-10, which needed layout judgement (button `visualDensity` pinned to standard under a compact theme). All four returned accepted first time; the briefs carried exact file lists, the done-check command list and "open the PNG" instructions, which is what made review cheap.
- Golden-test repos: stack dependent branches on the previous ticket's tip in the same worktree (FU-11 → FU-9, FU-10 → FU-12) and let the main thread rebase/regenerate goldens when two branches touch the same PNGs. Conflicts were only the eight full-page gallery PNGs; `git checkout --ours` + `--update-goldens` resolved them in one pass.
- Agents reliably report `example/pubspec.lock` being rewritten by `pub get`; tell them up front to `git checkout -- example/pubspec.lock` before reporting.
- Design-doc drafting from a decisions list is delegable to `worker-heavy` at higher effort; the decisions themselves are not.
- 2026-11-01, ANVL-171: `worker-heavy` was right for the sqlite3 port + runner + parity tests (T-006, accepted first time, 53 tests); `worker` at lower effort was right for extending the vitest fixture generator and running it from the Electron tree (T-007, accepted first time). Two agents in parallel on disjoint files with a shared file contract (`schema-step-0N.json` shape spelled out in both briefs) worked: the step test was written against the contract and went green when the dumps landed.

## Repo gotchas for briefs
- anvil_core: Electron SQL ported byte for byte needs `'''\n    CREATE ...` (escaped leading newline), because Dart drops the newline right after `'''` while the TS template literal keeps it; the tests compare whitespace-normalized, so this is for `sqlite_master` text fidelity only.
- anvil_core: `sample-0.1.6.anvil` is in rollback-journal mode (`delete`), not WAL, because the generator opened it without the WAL pragma; `ProjectDatabase.open` switches a copy to WAL, `openReadOnly` cannot. Real 0.1.6 files are WAL.
- anvil_core: to corrupt a fixture copy for an integrity_check test, overwrite row data inside a populated page (the `stats` page), not unused space; the brief's "page 3 + 200" offset landed in free space and SQLite reported `ok`.
- anvil_core: `Isolate.resolvePackageUriSync` does not work under `flutter_tester`; test support locates `test/fixtures/` from the working directory (package dir or repo root).
- Electron tree: `better-sqlite3` is compiled for Electron's ABI; `npm rebuild better-sqlite3` before a Node/vitest run, `npm run rebuild` after. Both worked on 2026-11-01.
- forge-ui: `flutter_test` runs as Android, so Material adds no `Scrollbar` and no desktop behaviour unless the test sets `debugDefaultTargetPlatformOverride` (and clears it before the body returns) or uses a platform variant.
- forge-ui: the full-page gallery goldens (`gallery_*_{light,dark}.png`, 8 files) change on ANY gallery edit, including an app-bar icon; section goldens under `components/` change only for their section.

- 2026-10-31 (T-003, ANVL-155): the brief told the worker the ANVL-157 children "ANVL-158 to ANVL-166" were complete, meaning the ticket set was complete; the worker read it as the work being done and proposed new tickets that duplicated ANVL-159 to ANVL-166 (all still To Do). Before a brief describes other tickets, pull their status from Jira and say "open" or "done" explicitly; never write "complete" about a ticket set.
- 2026-10-31: the worker correctly flagged four brief-vs-code discrepancies (min window width 1400 not 900, single `anvil.log`, no export dependency resolver, no formula cache). Briefs that restate CLAUDE.md facts about the Electron code should say "verify against the source and report differences"; CLAUDE.md status entries have drifted before.
- 2026-10-31: `git push` over the 1Password SSH agent fails with "communication with agent failed" when 1Password has auto-locked; inside the sandbox it fails fast, outside it hangs on the approval prompt. Not fixable from the session; tell the user to unlock 1Password and retry.

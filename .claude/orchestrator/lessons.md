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
- 2026-11-01: never chain worktree/branch cleanup after the merge gate with `;`. The gate on PR #38 correctly refused (`core / ci` FAILURE) but the `; git worktree remove ...` after it still ran and deleted the un-merged branch's worktree (recovered from the remote branch). Cleanup goes in a separate command run only after the merge is confirmed.
- 2026-11-01 (T-011): stack-overflow behaviour is not a parity oracle. Corpus cases nesting 200000 deep overflowed in Node and in local Dart but not on the GitHub runner, so the test was green locally and red in CI. Parity corpora must exclude cases whose outcome depends on stack size; if a limit is wanted, make it explicit in the Dart code.
- 2026-11-01 (T-012/T-013): a brief's "grep -rn package:flutter … | wc -l → 0" done-check trips on the package README and the pubspec comment; write it as `grep -rn "^import 'package:flutter"` over `lib` and `test`. T-013 also found the spike's parser overflowed the stack on flat operator chains of ~10,000 terms (same family as the T-011 lesson): any port of a recursive parser needs an explicit depth cap with a test, not a reliance on the runtime stack.
- 2026-11-01 (PR #46 gate): both required check names (`ci / ci`, `core / ci`) appear twice on a topic PR, once from the `push` event and once from `pull_request`. A dict keyed by name collapses them and can show a stale state. The watcher and the merge gate must require every run of each required name to be `success`, not the last one seen.
- 2026-11-01 (T-017/T-018): when a brief's save-blocker rules come from the design rather than from 0.1.6 behaviour, say so in the brief ("design §8.6 rule; 0.1.6 only disabled Save on …"). Both workers spent time verifying that 0.1.6 blocked nothing on empty name/key and reported it as a discrepancy; the provenance line would have made that a one-line confirmation.
- 2026-11-01 (sibling repository tickets): cutting two parallel branches from a shared base commit holding the common helpers (`SaveBlocker`, `UsedByRef`, `record_helpers.dart`) kept the rebase conflict to the sorted export barrels, resolved by rewriting the full list. Barrels are the only expected conflict between core tickets; CLAUDE.md's status paragraph is the only one in the app.
- 2026-11-01 (ANVL-179 commit): a heredoc `python3 - <<'EOF' … EOF` ends the `&&` chain; the commands on the lines after `EOF` run regardless of the script's exit. The CLAUDE.md anchor assertion failed and the commit still went ahead without the entry. Put the commit in a separate command gated on the previous one's result, or write the script to a file and chain `python3 file.py && git add …`.
- 2026-11-01 (PR #50): `git push -q … | tail -1` followed at once by `gh pr view --json headRefOid` showed the OLD head although the push had succeeded; GitHub's PR view lags the ref update by a few seconds. Confirm a push with `git fetch` + `git rev-parse origin/<branch>`, not with `gh pr view`. The retry force-push was then refused by the auto-mode classifier as destructive; it was unnecessary.

## 2026-11-01 — T-023 / T-024 (ANVL-185, ANVL-162)
- Riverpod 3: a widget still `ref.watch`ing a provider that throws (e.g. `requireSessionProvider` when the session clears) gets the error reported through `FlutterError` before the router removes the widget. Rule for every shell/editor brief: widgets watch the nullable `projectSessionProvider`; only providers and notifiers watch `requireSessionProvider` or the repository providers.
- A brief's behavioural assertion can be wrong about the model: T-024 said "the draft history has NOT stepped" after a field undo, but `DraftHistory` counts an edit landing on the previous snapshot as an undo by design. Worker caught it and matched the spike. Write such assertions as "verify against the spike test and match it" instead of stating the expected state.
- Two heavy workers in parallel on disjoint directories (`lib/app/shell/` vs `lib/app/editor/`) merged cleanly; the second one's worktree was fast-forwarded with its uncommitted changes via `git merge --ff-only` before the commit, which works when the incoming commits touch none of its files.
- `sed -i 's#...#...#'` breaks when the replacement contains `#` (PR numbers). Use python for ledger edits.

## 2026-11-01 — T-033..T-037 (domain editors, Undo snackbar, shared widgets)
- Widget tests of a list or editor page must pump at the app's minimum (1400×800 with the 220 px sidebar taken, or through `test/shell/shell_harness.dart`). T-035's own tests ran at 2000 px and hid a 148 px `ListToolbar` overflow that the shell tests caught at merge. Every list/editor brief carries the rule and treats any `RenderFlex overflowed` as a failure to fix.
- The domain list adapters are built with the list page's `WidgetRef`, which Riverpod 3.4 makes throw after the page unmounts. Anything that must outlive the page (the ANVL-166 Duplicate Undo) goes through `ProviderScope.containerOf` and a repository provider instead of the adapter. Follow-up candidate: adapters read repositories through the controller's own `Ref`.
- Workers copying the landed `go_router` navigation imported `package:go_router` directly in a domain editor (T-034). Briefs now state the rule (`go_router` only under `lib/app/shell/`; navigate through `ref.read(routerProvider).go(...)`) and the done-check greps for it.
- Three heavy workers on disjoint `lib/app/domains/<d>/` directories merged with no conflicts; the only shared edits (registry in `placeholders.dart`, `shell_routes_test.dart`, CLAUDE.md entry) are the orchestrator's after each merge. Cutting the three worktrees from the open PR's head commit (not the merged tip) was fine: the merge commit's first parent is that head.

## 2026-11-01, ANVL-196/198/199 reviews
- Widget tests render with the Ahem test font: every glyph is 1 em wide, so a 22-character timestamp is ~310 px and tables are far wider than in the app. A `RecordTable` row's actions can therefore sit off-screen even at 1400 px; tests over long rows call `tester.ensureVisible(action)` before tapping (the user would scroll). The earlier "RenderFlex overflowed by 7 px" on the NPC list was the same artefact; the horizontal scroll stays as a safety net.
- A worker's "all tests passed" holds for its base only: the full suite must be re-run after fast-forwarding a worktree onto newer commits (the 199 SQLite test went red only once 197's horizontal-scroll table arrived under it).
- `DraftHistory`'s 500 ms coalescing reads `clockProvider`, which defaults to the real clock; page tests that type then undo are flaky under a loaded `-j 4` run unless the harness overrides it with `tester.binding.clock.now` (done in `ClassHarness.pump`). Put the override in every domain harness from now on.
- Riverpod in widget tests refreshes providers on a zero-length timer: `tester.pump()` alone never runs it, tests need `pump(Duration)` (worker note, ANVL-196).

## 2026-11-01, ANVL-140/200 reviews
- A worker's ff onto a tip whose changes are in a disjoint directory can lean on CI as the full-suite gate; the local re-run rule is for overlapping files (shared tables, placeholders, shell tests).
- `gh pr create` fails with "you must first push the current branch" when the preceding `git push` silently failed over SSH (the tail showed only "and the repository exists."); check `git status -sb` for `[ahead N]` before assuming the push landed.
- The CLAUDE.md anchor chain works across parallel worktrees only if the second PR's entry is added after its ff onto the first PR's merge; add the entry last, not with the worker's diff.

## 2026-11-03, wave 1 (ANVL-117/156/165/167/201-204)
- herdr workers: `herdr pane split --pane <id> --direction down --cwd <worktree> --no-focus`, then `herdr agent start anvil-<N> --kind claude --pane <id> -- --agent orchestration:worker-heavy --permission-mode auto`, prompt with the brief path, and a background `herdr agent wait anvil-<N> --timeout 7200000`. Close each pane after the merge.
- The subagent guard refuses to run the real bump scripts, even against a scratch clone. When a brief needs a release-script test, the orchestrator runs it itself.
- Check a ticket's premise in the source before briefing. ANVL-204 said the dashboard showed a stale game title; no screen shows the title while a project is open. The fault was the recent-projects entry after close, and the ACs were amended before dispatch.
- With four parallel PRs, add each CLAUDE.md status entry only after that worktree has been fast-forwarded onto the previous merge (the T-044 lesson). Two worktrees still conflicted on `menu_commands.dart` (202 and 203); stash, ff, pop and keep both sides' removals.

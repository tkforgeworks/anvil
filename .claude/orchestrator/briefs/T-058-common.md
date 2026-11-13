# 1.0.0 baseline review: common brief (T-058 … T-063)

You are one of six reviewers. Each reviews one area of Anvil at the 0.2.0-rc.2 tip
(`a0823e2`, checked out on branch `review/1.0.0-baseline`). Your area brief names your files.
Read this file first, then your area brief.

## Goal

Anvil's next major release is 1.0.0. Before it, the code base is refactored to be SOLID, with
concise files and a strict single-responsibility principle, bent where cyclomatic complexity
argues against splitting. The aim is code that is easy to adjust, not large single files.
Your review is the baseline: it produces findings and a ticket-sized refactor plan for your
area. **Nobody changes code in this phase.**

## Hard rules

- **Read-only.** Do not edit, create or delete any file in the repository except your own
  report file (named in your area brief, under `.claude/orchestrator/briefs/`, which git ignores).
  No `git checkout`/`switch`/`stash`/`commit`, no `pub get` (it rewrites `pubspec.lock`), no
  formatter runs that write. No Jira, no GitHub. Before you report, run
  `git -C /home/tkforgeworks/projects/anvil status --porcelain` — expected output is exactly
  `?? node_modules/`.
- You may run read-only commands: `grep`, `rg`, `sed -n`, `wc`, `git log`/`git show`/`git grep`,
  `fvm flutter analyze` (read-only), and the metrics tool below.
- No test runs are needed; do not start full test suites.
- Every claim cites `path:line`. If a metric or a CLAUDE.md statement disagrees with the source,
  the source wins: **verify against the source and report differences** in your report's
  Discrepancies section.

## Project context

Read `.claude/CLAUDE.md` (architecture, provider rules, conventions) before reviewing. The
"Architecture Decisions (Do Not Reverse Without Discussion)" list is binding: a finding that
would reverse one goes under Open Questions, not Proposed Tickets. Constraints every refactor
proposal must respect:

- Behaviour-preserving: every proposed ticket is a pure refactor (no UI or output change), tests
  stay green, and parity with 0.1.6 (schema, export bytes, formula and validation results) holds.
- `packages/anvil_core` never imports Flutter or Riverpod; the app depends on the core, not the reverse.
- Widgets never `ref.watch` `requireSessionProvider` or a repository provider.
- Plugin imports stay confined (`go_router` under `lib/app/shell/`, `file_selector` in
  `lib/app/dialogs/file_dialogs.dart`, `url_launcher` in `lib/app/menu/external_links.dart`,
  `package_info_plus` in `lib/app/menu/about_dialog.dart`, `fl_chart` in
  `lib/app/domains/classes/classes_growth_chart.dart`). A split may move the confining file only
  if the proposal says where the confinement goes.
- Colours never as literals outside `lib/app/theme/anvil_palette.dart` and `color_math.dart`.
- Pickers use `DropdownButton` or menu anchors, never `DropdownMenu`.

## Agreed thresholds (Tim, 2026-11-13)

| Measure | Target | Hard |
|---|---|---|
| File length | ~300 lines | 500 |
| Public types per file | 1 (private helpers fine if used only there) | — |
| Cyclomatic complexity per function | ≤10 | 15 |
| Nesting depth | ≤4 | — |
| `build()` length | ~60 lines (target) | tickets only above 100 |

Exceptions agreed:
- A sealed hierarchy with its subclasses, and a domain's `XRecord` / `CreateXInput` / `XDraft`
  family, may share a file.
- Exempt by nature: migrations (`db/migrations/`), project template seed data
  (`project/templates/`), and 0.1.6-parity-bound code where a split would hurt the parity proof.
- Large `switch` dispatchers are judged by design, not the number: a command or node `switch` that
  every new feature must edit is an open/closed finding (e.g. a registry); a token or AST
  dispatcher that reads best as one `switch` can be recommended as exempt with a reason.
- Thresholds are guidance, not the goal. The test for a split is "does this file or class have
  more than one reason to change?" A cohesive 350-line unit stays whole; say so.

## Metrics

A baseline from an analyzer-based tool is in
`/tmp/claude-1000/-home-tkforgeworks-projects-anvil/4d2d6879-2823-4c1a-b915-8415082ae0e4/scratchpad/baseline/`:
`summary.md`, `files.csv` (path, lines, public/private types, max cc, exempt),
`functions.csv` (file, function, line, lines, cc, nesting; closures appear as
`Parent#closure@line` and are not counted in their parent), `dup_private.csv` (private class
names defined in more than one file; `_Parser` and `_Frame` are false positives — unrelated
classes sharing a name). Nesting counts `if`/`for`/`while`/`try`/`switch` statements only, not
widget-tree depth. Filter the CSVs to your area with `grep`.

## What to look for

1. **Single responsibility.** Files and classes with more than one reason to change: a page that
   also holds a controller, a dialog that holds its own validation rules, a repository that
   also computes usage reports, a widget file with several unrelated public widgets.
2. **Duplication.** Copied widgets, helpers or logic. Duplicates within your area are yours.
   Duplicates that cross areas: report them tagged `cross-area` with every location you found;
   the orchestrator assigns them (the shared-framework reviewer owns extraction into
   `lib/app/editor/widgets/` or `lib/app/widgets/`).
3. **Complexity.** Functions over the cc and `build()` thresholds, and how to reduce them
   (extract widget, extract method, table or registry, guard clauses).
4. **Dependency direction / inversion.** Code reaching around an abstraction (e.g. a list adapter
   reading a repository through a page's `WidgetRef`), concrete types where an interface exists,
   hidden globals.
5. **Open/closed.** What has to change to add a seventh domain or a new menu command, setting or
   export preset. Count the files and `switch`es; propose a seam where the count is high.
6. **Interface segregation.** Fat interfaces or classes callers use a small part of.
7. **Consistency for 1.0.0.** File and folder naming and layout that differ between siblings for
   no reason (CLAUDE.md notes e.g. `recipes_lookups.dart` vs `item_meta_providers.dart`), dead code
   or unused public API (check with `git grep`), stale comments.
8. **Known gaps.** CLAUDE.md's "Known Gaps and Technical Debt" items in your area that are
   structural; include them as findings if a refactor fixes them, and say whether the fix
   changes behaviour (if so it is not a pure refactor; mark it).

## Ticket grain

One ticket = one PR, reviewable in one sitting (as a rule of thumb, at most ~1,500 lines moved or
~600 lines of real change). Order tickets so shared pieces come first. Each proposed ticket must
be behaviour-preserving and leave every check green on its own.

## Report format (write it to your report file, Markdown)

1. **Summary** — 3–6 lines: the area's state and the top three problems.
2. **Findings** — a table: id (`<area>-F1`…), check (1–8 above), `path:line`, evidence (metric or
   quoted code), severity (high = blocks easy change; medium; low), proposed fix in one line.
3. **Proposed tickets** — for each: id (`<area>-T1`…), a changelog-style title (user-readable,
   e.g. "Split the class Stat Growth tab into one file per panel"), the findings it closes, files
   in scope, the target layout (new file names and what each holds, with rough line counts),
   dependencies on other tickets (yours or `cross-area`), size S/M/L, risk, the test files it will
   touch, and done-checks (commands with expected output; always `fvm dart format
   --set-exit-if-changed .`, `fvm flutter analyze`, `fvm flutter test test packages/anvil_core/test`,
   plus any grep that proves the split).
4. **Target layout** — the proposed folder tree for your area after all your tickets.
5. **Recommended exemptions** — file or function, threshold, reason.
6. **Discrepancies** — places where CLAUDE.md, this brief or the metrics disagree with the source.
7. **Open questions** — anything needing Tim's decision (including any architecture-decision
   reversal).

When done, reply in the terminal with only the report path and one line: findings count,
tickets count.

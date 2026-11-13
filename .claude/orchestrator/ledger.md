# Orchestrator ledger

Session 2026-10-31 (ANVL-155 design + FU-9/10/11/12 in forge-ui); session 2026-11-01 (ANVL-170 inline, ANVL-171 T-006/T-007, Set A T-008..T-011 in parallel worktrees).

| ID | Chunk | Agent / tier | Status | Verdict | Notes |
|---|---|---|---|---|---|
| T-012 | ANVL-160 saveTransaction + history + error types (wt ANVL-160) | worker | done | accepted | 13 tests; PR #40 merged 2bb6581; ready-to-close |
| T-013 | ANVL-181 export engine from ANVL-151 spike (wt ANVL-181) | worker-heavy | done | accepted | 129/149 parity, nesting cap added; PR #41 merged 95f6f1d; ready-to-close |
| T-014 | ANVL-180 validation engine + Electron oracle + isolate runner (wt ANVL-180) | worker-heavy | done | accepted | 32 tests, oracle exact first run; PR #43 merged 9b026ac; ready-to-close |
| T-015 | ANVL-176 MetaRepository + CustomFieldRepository (wt ANVL-176) | worker-heavy | done | accepted | 81 tests; PR #42 merged 45f447f; ready-to-close |
| T-016 | ANVL-183 app bootstrap: error zones, providers, persisted theme, window minimum (wt ANVL-183) | worker-heavy | done | accepted | 38 app tests; runner default size set to 1400x800 inline; PR #44 merged 4347074; ready-to-close |
| T-017 | ANVL-177 class + ability repositories | worker-heavy | done; PR #45 merged eceea8d |
| T-018 | ANVL-178 item, recipe, loot repositories | worker-heavy | done; PR #46 merged e6de9f4 |
| T-019 | ANVL-182 export service | worker-heavy | done; PR #47 merged eb25df7 |
| T-020 | ANVL-184 welcome page | worker-heavy | done; PR #48 merged 69f918f |
| T-011 | ANVL-175 formula engine + parity corpus (wt ANVL-175) | worker-heavy | done | accepted (after 1 rework) | nesting limits 1000/2000; PR #38 merged 029f785; ready-to-close |

## Done
| T-008 | ANVL-172 project lifecycle service | worker-heavy | accepted | PR #39 merged 016c3e4; ANVL-172 ready-to-close |
| T-010 | ANVL-174 record/draft types + NPC stat block | worker-heavy | accepted | PR #37 merged 16ced1e; ANVL-174 ready-to-close |
| T-009 | ANVL-173 app settings + file logger | worker | accepted | PR #36 merged c316a70; ANVL-173 ready-to-close |
| T-007 | ANVL-171 fixture generator step dumps | worker | accepted | schema-step-01..07.json + README; Electron binary restored |
| T-006 | ANVL-171 ProjectDatabase + migrations + runner + parity tests | worker-heavy | accepted | 53 core tests, SQL byte-for-byte, fixture unchanged |
| T-003 | ANVL-155 design doc draft (anvil) | worker-heavy | accepted | design v2 merged via PR #32/#33; ANVL-155 ready-to-close |
| T-005 | FU-12 scrollbar theme | worker | accepted | PR forge-ui#27 merged 1701b8c; FU-12 ready-to-close |
| T-002 | FU-10 desktop density | worker-heavy | accepted | PR forge-ui#26 merged b5af587; FU-10 ready-to-close |
| T-004 | FU-9 status roles | worker | accepted | PR forge-ui#25 merged 4fd3c14; FU-9 ready-to-close |
| T-001 | FU-11 ForgeType.code | worker | accepted | PR forge-ui#24 merged 9475535; FU-11 ready-to-close |
| T-021 | ANVL-179 NPC, lifecycle and save-history repositories | worker-heavy | done; PR #49 merged 4ccb115 | worktree anvil-wt/ANVL-179, base eb25df7 |
| T-022 | ANVL-159 DraftHistory + shared editor controller base | worker-heavy | done; PR #50 merged 4349d97 | worktree anvil-wt/ANVL-159, base 69f918f, parallel with T-021 on disjoint dirs |
| T-023 | ANVL-185 shell route, sidebar, app bar, openEditor | worker-heavy | done | merged 3141651 (PR #52) |
| T-024 | ANVL-162 editor keyboard layer (RecordEditorShortcuts + RecordEditorScope) | worker-heavy | done | merged 7d53dc0 (PR #51) |
| T-025 | ANVL-187 shared editor scaffold (EditHeader, SaveBar, DraftTextField, banner, exit prompt) | worker-heavy | done | merged fc7626b (PR #53); epoch bump added inline |
| T-026 | ANVL-188 shared list scaffold (RecordListPage, bulk dialogs, InspectorRail) | worker-heavy | done | merged b9cd4ca (PR #54) |
| T-027 | ANVL-186 hamburger menu, shortcut registry, cheatsheet, zoom | worker-heavy | done: merged 3b930f8 (PR #55) | worktree anvil-wt/ANVL-186, base 3141651 |
| T-028 | ANVL-190 project settings dialog with buffered meta lists | worker-heavy | done: merged 7ae568f (PR #56) | worktree anvil-wt/ANVL-190, base fc7626b, parallel with T-027 |
| T-029 | ANVL-161 leave guard (editor dialog, routes, project actions) | worker-heavy | done: merged 89d1a92 (PR #58) | worktree anvil-wt/ANVL-161, base 7ae568f, parallel with T-030/T-031 |
| T-030 | ANVL-163 save status indicator, quiet checkpoint, close on exit | worker-heavy | done: merged ebdb968 (PR #57) | worktree anvil-wt/ANVL-163, base 7ae568f, parallel |
| T-031 | ANVL-189 app settings dialog, shortcut overrides, menu wiring | worker-heavy | done: merged e6abb19 (PR #59) | worktree anvil-wt/ANVL-189, base 7ae568f, parallel |
| T-032 | ANVL-164 stat growth formula blocker + design §8 blocker list | worker | done: merged 13f178f (PR #60) | worktree anvil-wt/ANVL-164, base e6abb19, core + design doc only |
| T-033 | ANVL-191 abilities list and editor | worker-heavy | done: merged e19ae0b (PR #61); I fixed the placeholder-expecting tests and wired the registry | worktree anvil-wt/ANVL-191, base e6abb19, lib/app/domains/abilities |
| T-034 | ANVL-192 items list and editor | worker-heavy | done: merged 8782501 (PR #63); I replaced its direct go_router import and fixed open_editor_test | worktree anvil-wt/ANVL-192, base e6abb19, lib/app/domains/items |
| T-035 | ANVL-193 recipes list and editor | worker-heavy | done: merged 82fa9d0 (PR #62); I wrapped the shared ListToolbar after its tests masked a 148 px overflow | worktree anvil-wt/ANVL-193, base e6abb19, lib/app/domains/recipes |
| T-036 | ANVL-166 Undo snackbar for instant list actions | worker-heavy | done: merged dc922f5 (PR #65); I made the Duplicate Undo outlive the page via the container | worktree anvil-wt/ANVL-166, base 82fa9d0 ff'd to 5a579e7, lib/app/lists only |
| T-037 | ANVL-149 shared DraftPicker / number fields / export-key slug across the three editors | worker | done: merged 5a579e7 (PR #64) | worktree anvil-wt/ANVL-149, base 8782501, lib/app/editor + lib/app/domains |
| T-038 | ANVL-194 loot tables list and editor | worker-heavy | done: merged e16e1cf (PR #67) | worktree anvil-wt/ANVL-194, base 1a60549, lib/app/domains/loot_tables |
| T-039 | ANVL-195 classes list and editor (details, metadata, abilities) | worker-heavy | done: merged 4220629 (PR #66); I fixed two click-through tests that expected the classes placeholder | worktree anvil-wt/ANVL-195, base 1a60549, lib/app/domains/classes |
| T-040 | ANVL-197 NPCs list and editor + CustomFieldsPanel move to lib/app/editor | worker-heavy | done: merged e167220 (PR #68); I fixed the class click-through test and made RecordTable scroll sideways; ready-to-close |
| T-044 | ANVL-200 export page + template dialog | worker-heavy | done: merged 2edd8ee (PR #73); ready-to-close | worktree anvil-wt/ANVL-200 removed |
| T-041 | ANVL-196 class stat growth + derived stats tabs, fl_chart, AnvilColors.chartSeries | worker-heavy | done: merged e03ec12 (PR #71) under the renamed branch v0.2.0/ANVL-196-stat-growth-tabs; stale remote v0.2.0/ANVL-196-stat-growth-derived left for Tim; ready-to-close | worktree anvil-wt/ANVL-196 removed |
| T-042 | ANVL-198 dashboard + validation page | worker-heavy | done: merged b39e1bd (PR #70); I applied its welcome-test patch and wired NPCs into Quick add; ready-to-close | worktree anvil-wt/ANVL-198, base 48d2fa0 (SSH agent locked: branch not yet pushed), lib/app/dashboard + lib/app/validation |
| T-043 | ANVL-199 recycle bin page | worker-heavy | done: merged 90b997a (PR #69); I resolved the routes-test merge and fixed the SQLite test that went red under 197's scrolling table (ensureVisible); ready-to-close | worktree anvil-wt/ANVL-199, base 48d2fa0 (not yet pushed), lib/app/recycle_bin |
| T-045 | ANVL-140 Formula Fill helper | worker-heavy | done: merged 46ef296 (PR #72); ready-to-close | worktree anvil-wt/ANVL-140 removed |
| T-046 | ANVL-117 right-click context menu on list rows | worker-heavy (herdr anvil-117, w5:p3) | done: merged fbfb59a (PR #76); I fixed the loot table cell-cast test; ready-to-close | worktree removed |
| T-047 | ANVL-156 project templates (core seeding + New Project picker) | worker-heavy (herdr anvil-156, w5:p5) | done: merged f044a71 (PR #75); ready-to-close | worktree removed |
| T-048 | ANVL-165 settings/template dialog drafts + leave prompt (Custom Fields stays immediate) | worker-heavy (herdr anvil-165, w5:p4) | done: merged e98cbc6 (PR #77); I scoped ExportPage note to records and amended the ticket; ready-to-close | worktree removed |
| T-049 | ANVL-167 release pipeline on release-flutter.yml + bump scripts + Windows installer | worker-heavy (herdr anvil-167, w5:p6) | done: merged 949714c (PR #74); I ran the bump-script test and replaced the runner icon; ready-to-close | worktree removed |
| T-050 | ANVL-202 Save As + Backup wiring | worker-heavy (herdr anvil-202) | done: merged 5a39370 (PR #78); I added .anvil normalisation + test; ready-to-close | worktree removed |
| T-051 | ANVL-203 About dialog (package_info_plus behind appVersionProvider) | worker (herdr anvil-203) | done: merged 3465f86 (PR #79); I swapped literals for AnvilSpacing and resolved the menu_commands conflict; ready-to-close | worktree removed |
| T-052 | ANVL-201 upgrade notes (docs/upgrade-0.2.md + README) | worker (herdr anvil-201, w5:p9) | done: merged 41ef79c (PR #81) with the approved security paragraph; ready-to-close | worktree removed |
| T-053 | ANVL-204 fresh session metadata after writes + recent entry rewritten on close | worker-heavy (herdr anvil-204) | done: merged d3c1877 (PR #80); ticket ACs amended; ready-to-close | worktree removed |
| T-054 | ANVL-168 org side: build-linux input on release-flutter.yml + docs | inline (orchestrator) | done | tkforgeworks/.github PR #22 merged 1c459d3 (+ glibc wording fix) |
| T-055 | ANVL-168 Anvil side: build-linux.sh + linux/packaging (AppImage, deb, rpm), container install and 0.1.6 upgrade tests | worker-heavy (herdr anvil-168) | accepted | anvil PR #82 (7fa07e1); orchestrator added docs/CLAUDE.md; all container tests passed |
| T-056 | ANVL-143 install/update scripts (sh + ps1), fake-release container tests | worker-heavy (herdr anvil-143) | accepted | anvil PR #83 (cc39941); worker found nfpm deb revision -1 breaking compares (fixed); orchestrator added CLAUDE.md; Windows install path unproven until rc.1 |
| T-057 | ANVL-169 cutover: remove Electron app, README, docs/testing.md, fixture READMEs, .gitignore | worker (herdr anvil-169) | accepted | commit ef23558, PR #84; 1707 tests, analyze clean, linux build ok; CLAUDE.md rewritten by orchestrator |
| T-058 | 1.0.0 review: shared editor/list/widget framework + cross-area extraction + guard test | worker-heavy (herdr anvil-rev-fw) | accepted: report in, 15 tickets, tree clean; spot-checked claims hold | read-only, base a0823e2 on review/1.0.0-baseline; report briefs/T-058.report.md |
| T-059 | 1.0.0 review: domain editors | worker-heavy (herdr anvil-rev-dom) | accepted: report in, 12 tickets, tree clean; spot-checked claims hold | read-only, base a0823e2 on review/1.0.0-baseline; report briefs/T-059.report.md |
| T-060 | 1.0.0 review: settings, export, menu | worker-heavy (herdr anvil-rev-sem) | accepted: report in, 13 tickets, tree clean; spot-checked claims hold | read-only, base a0823e2 on review/1.0.0-baseline; report briefs/T-060.report.md |
| T-061 | 1.0.0 review: shell, project lifecycle, pages, theme | worker-heavy (herdr anvil-rev-shp) | accepted: report in, 14 tickets, tree clean; spot-checked claims hold | read-only, base a0823e2 on review/1.0.0-baseline; report briefs/T-061.report.md |
| T-062 | 1.0.0 review: core data layer | worker-heavy (herdr anvil-rev-cdl) | accepted: report in, 11 tickets, tree clean; spot-checked claims hold | read-only, base a0823e2 on review/1.0.0-baseline; report briefs/T-062.report.md |
| T-063 | 1.0.0 review: core engines | worker-heavy (herdr anvil-rev-eng) | accepted: report in, 8 tickets, tree clean; spot-checked claims hold | read-only, base a0823e2 on review/1.0.0-baseline; report briefs/T-063.report.md |
| T-064 | 1.0.0 review: file the plan in Jira | orchestrator (main thread) | done: epics ANVL-208–213, children ANVL-214–284 (64 refactor + 7 consistency, fix 1.0.0), 0.2.1 bugs ANVL-285–290; ANVL-205/206 rescoped with comments; epic tables list plan id → key | plan briefs/1.0.0-refactor-plan.md (Jira keys section) |
| T-065 | 1.0.0 review: correct CLAUDE.md and track the orchestration log | orchestrator (main thread) | done: CLAUDE.md corrections checked against a0823e2; `.git/info/exclude` lines removed; ANVL-291 | branch v0.2.0/ANVL-291-review-notes |

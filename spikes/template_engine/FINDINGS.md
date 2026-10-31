# ANVL-151 findings: export template engine for the Flutter rewrite

Spike package: `spikes/template_engine/` (pure Dart, throwaway). Everything below is backed by `dart test` in this package unless marked *on paper*.

**Decision: Option 2, a purpose-built Dart renderer for a Nunjucks-compatible subset**, on top of a JS-compatible serialisation layer that the presets need as well. Reasons in §6.

## 1. Inventory: what Anvil 0.1.6 must keep rendering

### 1.1 How Electron renders a custom template

`src/main/export/renderer.ts`:

```ts
const env = new nunjucks.Environment(null, { autoescape: false, throwOnUndefined: true })
env.renderString(templateSource, { ...context, ctx: context })
```

* Nunjucks 3.2.4, default tags, **no loader** (so `include`/`import`/`extends` fail with "template not found"), **no autoescape**, no `trimBlocks` or `lstripBlocks` (template text, newlines and CRs are kept exactly; a final newline is kept). Whitespace control `{%- -%}`, `{{- -}}`, `{#- -#}` works.
* **`throwOnUndefined` is an output-time check, not a lookup check.** Nunjucks wraps every `{{ }}` in `ensureDefined`, so outputting `null` *or* `undefined` throws "attempted to output null or undefined value". Looking up a missing name or key returns `undefined` silently. Verified in the parity corpus (`guide.error_*`, `guide.undefined_in_if_ok`, `edge.*`):
  * throw: `{{ nope }}`, `{{ project.nope }}`, `{{ nope.deeper }}`, `{{ recipe.crafting_specialization_id }}` when it is null, `{{ none }}`, `{{ items[-1] }}`, `{{ nope | export_key }}`, `{{ nope | json }}`, `{{ null_value | default('d') }}`;
  * no throw: `{% if nope.deeper.x %}`, `{% for x in nope %}` (runs `else`), `{% set a = nope %}`, `{{ nope | upper }}` (empty), `{{ nope | default('d') }}`, `{{ 'a' ~ nope }}` (prints `aundefined`), `{{ nope == 1 }}`.
* `ctx` is an undocumented alias for the whole context.
* Template values are JavaScript values, so JS semantics leak into output: `String(x)` for `{{ x }}` (`[1,2]` prints `1,2`, objects print `[object Object]`, `1.0` prints `1`), JS truthiness (`[]` and `{}` are truthy, `''` and `0` falsy), loose `==`, and **JS operator precedence**: Nunjucks emits `or and not ~ + - * / %` and comparisons as unparenthesised JS, so `not a == b` is `(!a) == b`, `1 ~ 2 + 3` is `"123"`, `2 * 3 % 4` is `2`, `'Lv ' ~ max_level - 1` is `NaN`. Only `//` (`Math.floor`), `**` (`Math.pow`), `in`, filters, lookups and parentheses are boundaries.
* `{% set %}` inside a `for` updates an existing outer variable (an accumulator works) but a new name stays loop-local; loop-local names persist across iterations.
* String literals: only `\n`, `\t`, `\r` are escapes; `\x` is `x` (so `'\u0001'` is `u0001`). No exponent literals (`1e3` is an undefined name).

### 1.2 What the in-app writing guide documents

`src/renderer/src/pages/ExportPage.tsx` lines 540-620:

* Syntax: `{{ variable }}`, `{% for item in items %}...{% endfor %}`, `{% if condition %}...{% endif %}`, `{% set x = value %}`.
* Filters: `{{ value | json }}` ("formatted JSON", optional indent `json(4)`), `{{ some_id | export_key }}` ("resolve an internal ID to its export key").
* Context variables: `project` (name, game_title, schema_version, max_level); `meta` (stats, rarities, item_categories, npc_types, crafting_stations, crafting_specializations, derived_stats); `classes` (with stat_growth, abilities, derived_stat_overrides, metadata); `abilities` (with stat_modifiers); `items` (with custom_fields); `recipes` (with ingredients); `npcs` (with class_assignments, ability_assignments, combat_stats, custom_fields); `loot_tables` (with entries). "Each record has" `id`, `export_key`, `display_name`, `description`.
* The example template (`guide.example_verbatim` in the corpus): `# {{ project.game_title }} - Items` / `{% for item in items %}` / `## {{ item.display_name }} ({{ item.export_key }})` / `Category: {{ item.item_category_id | export_key }}` / `Rarity: {{ item.rarity_id | export_key }}` / `{{ item.description }}` / `{% endfor %}`.

Not documented but reachable in 0.1.6: every other Nunjucks feature (all built-in filters and tests, macros, `range`/`cycler`/`joiner`, method calls on JS values). They are the "idiom" part of the corpus.

### 1.3 The two Anvil filters, exact semantics

* `json(value, indent)` = `JSON.stringify(value, null, indent ?? 2)`. So `json` and `json(2)` indent by 2, `json(0)` (or any number < 1) is compact, numbers are clamped to 10, a string indent is used as is (first 10 chars). `JSON.stringify(undefined)` is `undefined`, so `{{ nope | json }}` throws; `{{ null_field | json }}` prints `null`.
* `export_key(id)`: scan `ctx.classes, abilities, items, recipes, npcs, loot_tables` in that order for the first record with `r.id === id` (strict) and return its `export_key`; otherwise return `id` unchanged. **It never resolves meta ids**: `{{ item.rarity_id | export_key }}` prints `rarity-common`, not `common`, and the guide's own example prints `Category: item-category-consumable` (see `template-guide.expected.txt`). The presets do resolve meta ids, so template and preset output differ here. `export_key` reads `this.ctx`, the template's `ctx` variable.

### 1.4 Context shape (`context-assembler.ts`)

`project {name, game_title, schema_version, max_level}`; `meta.{stats, rarities, item_categories, npc_types, crafting_stations, crafting_specializations, derived_stats}` (rows with `id`, `display_name`, `export_key`, `sort_order` plus `color_hex` / `description` / `formula, output_type, rounding_mode`); six domain arrays ordered by display name, each with nested arrays: classes `stat_growth[] {stat_id, level, value}`, `abilities[] {ability_id, sort_order}`, `derived_stat_overrides[] {derived_stat_id, formula}`, `metadata {}`; abilities `stat_modifiers {}`; items `custom_fields {}`; recipes `ingredients[] {item_id, quantity, sort_order}`; npcs `combat_stats {}`, `class_assignments[] {class_id, level, sort_order}`, `ability_assignments[] {ability_id, sort_order}`, `custom_fields {}`; loot tables `entries[] {item_id, weight, quantity_min, quantity_max, sort_order}`. In a domain or selection scope the other domain arrays are empty.

Five columns are SQLite `REAL`: `classes.resource_multiplier`, `class_stat_growth.value`, `class_metadata_fields.value`, `abilities.resource_cost`, `abilities.cooldown`. JavaScript has one number type, so `12.0` printed as `12`; a Dart SQLite read returns `12.0` (§5).

### 1.5 Presets are code, not templates

Nested JSON, Flat JSON and CSV are TypeScript functions (`renderNestedJson`, `renderFlatJson`, `renderCsv`, `toCsv`, `csvEscape`). The engine choice does not touch them; §5 ports them.

## 2. How the options were measured

* **Fixtures** (captured from Electron 0.1.6): the three templates and their outputs, the presets, the context.
* **Parity corpus**: `tool/parity_cases.js` holds 149 template snippets in four groups: `guide.*` (45, what the guide documents, plus the brief's subset: `loop.index/first/last`, `elif`, comments, literals, comparisons, `and/or/not`), `idiom.*` (69, common Nunjucks beyond the guide), `edge.*` (32, null/undefined/number/precedence corners) and `host.*` (3, include/extends/import). `tool/nunjucks_oracle.js` renders them with Nunjucks 3.2.4 in Electron's exact environment (it reuses the Electron app's `node_modules/nunjucks`) into `test/fixtures/nunjucks-parity.json`. The oracle reproduces the three fixture outputs byte for byte.
* **JS values oracle**: `tool/js_values_oracle.js` writes what node prints for 3,025 doubles, 8 `JSON.stringify` edge cases and 8 `String()` cases.
* A case **matches** when the output is identical or both engines reject the template. Misses are `outputDiffers` (silently different output, the dangerous kind), `engineRejects` (Dart throws, Nunjucks rendered) and `engineAccepts` (Dart renders, Nunjucks threw).

## 3. Option results

### Option 1: the `jinja` package (ykmnkmi/jinja.dart 0.7.2)

Configured through its public API only (`lib/src/jinja_renderer.dart`): `keepTrailingNewLine: true`; `finalize` throws on null (the Nunjucks output check) and prints values with JS `String()`; `getItem` makes lookups on null return null and supports `.length`; `json`, `export_key` and `dump` filters with Electron semantics; `print`, `namespace`, `list` and `runtimetype` removed; `range` capped at 100,000 items.

**Fixtures: 0 differences** (all three byte-identical). Variants, each with its single cause (tests in `fixture_templates_test.dart`):

| Variant | guide | recipe-book | beyond-guide |
|---|---|---|---|
| Anvil-tuned | identical | identical | identical |
| tuned, Dart `toString` output | identical | identical | 1 byte run: `3.0` for `{{ (1.5 + 1.5) }}` (number formatting) |
| jinja defaults + `dart:convert` `json` filter | identical | `json(0)` block differs: `JsonEncoder.withIndent('')` is not compact (JSON serialisation) | throws: no `dump` filter (missing filter) |

No whitespace differences on the fixtures: jinja.dart's default whitespace handling (no trim/lstrip, `-` control) matches Nunjucks once `keepTrailingNewLine` is on.

**Corpus: 105/149 match** (guide 43/45, idiom 45/69, edge 14/32, host 3/3). Of the 44 misses, **15 are silently different output** and they sit in the engine core, outside every public hook:

* guide: `guide.string_escapes` (jinja.dart leaves `\"`, `\'`, `\t`, `\n` in string literals unprocessed, so `| join('\n')` joins with a backslash-n); `guide.crlf_kept` (template CRLF normalised to LF).
* semantics: `[]`/`{}` are falsy (`truthy_empty_list/object`, `and_returns_operand`); `set` inside `for` never reaches the outer scope (`set_accumulate_in_loop` prints 0, Nunjucks 100); Python precedence instead of JS (`js_precedence_not`, `js_precedence_compare`); `'a' ~ nope` prints `anull`; string `reverse` prints `(c, b, a)`; single-target `for` over a map yields `MapEntry(...)`.
* numbers: int64 wrap-around (`1000000 * 1000000 * 1000000 * 1000` prints `3875820019684212736`, JS `1e+21`); Dart `%` sign (`-7 % 3` is 2, JS -1).

The other 29: 25 errors where Nunjucks rendered (`for` over null/undefined throws, `'a' + 1`, `elseif`, `===`, string `<`, bare dict keys, inline `if` without `else` yields null and trips the output check, missing filters `sort round sum selectattr select reject groupby indent urlencode nl2br`, `join` without its attribute argument, no `cycler`/`joiner`, no method calls), and 4 renders where Nunjucks threw (`map` filter exists; `1e3` is a literal; null vs undefined cannot be told apart, so `null | default('d')` prints `d` and `nope | json` prints `null`).

**Undefined variables.** There is no Nunjucks-style mode. jinja.dart has an `Environment(undefined:)` callback; its doc comment says the default throws `UndefinedError`, but `defaults.undefined` returns `null`. A throwing callback fires on any reference to an unknown *top-level* name (map key misses never reach it), which is stricter than Nunjucks: it breaks `{% if missing %}`, `missing | default(...)` and even `none`, which is not a literal in jinja.dart (only `null` is) (`throwOnReference` test). The Nunjucks behaviour has to be rebuilt with `finalize`, and that cannot tell null from undefined.

Package health (pub.dev, 2026-10-31): 0.7.2 published 2026-09-10, 52 versions since 2019, 160/160 points, 48 likes, about 49k downloads in 30 days, single maintainer, README says "work in progress", sdk `>=3.13.0` and uses Dart 3.13 primary-constructor syntax. Deps: `html_unescape`, `meta`, `path`, `string_scanner`, `textwrap`. `Context` is not exported, so `passContext` filters cannot be typed without `package:jinja/src/` imports (`implementation_imports`).

### Option 2: purpose-built subset renderer (`lib/src/subset/`)

A port of the Nunjucks 3.2.4 lexer (whitespace, string escapes, number literals), its parser's precedence ladder, a pass that re-associates operator regions by JS precedence the way the emitted JS parses (`jsassoc.dart`), and a tree-walking evaluator with Nunjucks runtime semantics: frame-scoped `set`, JS truthiness and operators, `undefined` distinct from `null`, output-time throw on null/undefined, `ctx` alias.

Supported: text, `{{ }}`, `{# #}`, whitespace control; `for` (one target, or `k, v` over maps and lists) with `else` and `loop.index/index0/revindex/revindex0/first/last/length`; `if`/`elif`/`elseif`/`else`; `set` (`=` form, several targets); literals (string, int, float, `true`/`false`, `none`/`null`, lists, dicts); `.name` and `[expr]` lookups (JS-style `.length` on lists and strings); `or and not in` / `not in`, comparisons (`== === != !== < > <= >=`), `~`, `+ - * / // % **`, unary `- +`, inline `if ... else`; 15 filters: `json`, `export_key`, `dump`, `length`, `upper`, `lower`, `capitalize`, `title`, `trim`, `default`/`d`, `replace`, `join` (with attribute), `first`, `last`, `reverse`.

**Not supported, rejected at parse time with line and column**: `macro`, `call`, `include`, `import`, `from`, `extends`, `block`, `raw`, `verbatim`, `filter` blocks, `{% set x %}...{% endset %}`, `switch`, async tags, `is` tests, any function or method call (`range()`, `cycler()`, `joiner()`, `'a'.toUpperCase()`), keyword arguments, regex literals, parenthesised tuples, and the other Nunjucks filters (`sort`, `round`, `int`, `float`, `abs`, `sum`, `batch`, `slice`, `selectattr`, `rejectattr`, `select`, `reject`, `groupby`, `dictsort`, `list`, `string`, `wordcount`, `truncate`, `center`, `indent`, `nl2br`, `urlencode`, `striptags`, `escape`/`e`, `safe`, `forceescape`, `random`, `urlize`). Each missing filter is roughly 5-15 lines if usage shows up.

**Fixtures: 0 differences.** guide and recipe-book are byte-identical, and so is beyond-guide: it uses `loop.index`, `| length`, `| upper`, `not loop.last`, inline `if/else`, `>`, `~`, indexing, `| default`, `| replace`, `{%-`/`-%}`, `| first`, `| dump`, `+`, parentheses, a list literal and `| join`, all in the supported set. A renderer limited to the brief's minimum subset would fail beyond-guide at its first `| length`.

**Corpus: 129/149 match** (guide 45/45, idiom 49/69, edge 32/32, host 3/3). **No case renders different output.** All 20 misses are `idiom.*` features in the "not supported" list, and each is rejected by the parser before any rendering (`AnvilTemplate.check()` returns kind `unsupported`).

Size: 1,565 lines (1,353 excluding comments and blank lines) in `lib/src/subset/`: parser 560, evaluator 271, lexer 244, filters 145, jsassoc 143, ast 127, the rest 75. About 450 of those cover the beyond-guide idioms (13 extra filters, arithmetic, `~`, inline `if`, list/dict literals, `in`). It also uses `js_compat.dart` (302 lines), which the presets need anyway, and `anvil_filters.dart` (42).

Speed is the same as jinja: on a context scaled 200× (1,000 items, 400 recipes), guide renders in about 200 ms and recipe-book (1.5 MB output) in about 240 ms with either engine (`tool/bench.dart`). The cost is `export_key`'s linear scan (Electron's algorithm), so an id index is a free win.

### Option 3: embed a JS runtime and keep Nunjucks (on paper, not built)

`flutter_js` 0.8.7 (published 2026-01-27; 0.8.5 2025-06; 140/160 points, 360 likes, about 56k downloads in 30 days):

* **A Flutter plugin** (`flutter`, `ffi`, `http`, `sync_http`). It cannot live in `anvil_core`, and README §"Unit Testing" says desktop tests need the app built first and `LIBQUICKJSC_TEST_PATH` pointing at the built `.so`. So no plain `dart test`.
* Linux and Windows use QuickJS through **prebuilt binaries shipped inside the package**: `linux/shared/libquickjs_c_bridge_plugin.so` (963 KB) and `windows/shared/quickjs_c_bridge.dll` (677 KB), dated 2025-02-21 in the archive, built in a separate repo (abner/quickjs-c-bridge). That is an opaque native supply-chain dependency. Bundle cost is about 1 MB native per platform plus `nunjucks.min.js` (91 KB).
* `getJavascriptRuntime(xhr = true)` by default calls `enableFetch()`, which bridges `fetch`/XHR to Dart `http`. Combined with the Nunjucks escape in §4, a template could reach the network unless that is turned off and the injected globals are audited.
* No QuickJS interrupt handler is exposed (no `interrupt` in `lib/`). JS runs synchronously inside an FFI call, and `Isolate.kill` cannot interrupt native code, so `while(true){}` reached through the escape hangs the thread for good.
* `export_key` would not cross the boundary: the context would be passed in as JSON and the filter written in JS, as in Electron. Exactness would be perfect; that is the only advantage.
* Alternatives: `flutter_qjs` 0.3.7 (2022, Dart 2 only, 60/160); `jsf` 1.2.1 and `fjs` 3.3.2 (also Flutter FFI plugins; `fjs` adds flutter_rust_bridge); `dart_eval` interprets Dart, not JS, so it cannot run Nunjucks.

Verdict: rejected. It breaks the pure-Dart core rule, it is untestable under `dart test`, it ships opaque binaries, and it keeps Nunjucks's escape alive with weaker hang protection than Electron had.

## 4. Sandbox assessment

**Electron 0.1.6 is not sandboxed.** With the same Nunjucks 3.2.4 and environment, run in node 22 (not inside the packaged app), `{{ ''.constructor.constructor('return process.platform')() }}` prints `linux`, and `typeof process.mainModule` is `object`. Nunjucks returns bound JS functions from member lookups, so `Function` is reachable and a template runs arbitrary JS with Node's `process` in the main process. The textbook escalation (`process.mainModule.require('child_process')`) was not executed. CLAUDE.md's "runs sandboxed in the main process" is wrong. Since a `.anvil` project is a shareable file, a template is untrusted input. 0.1.6 is frozen; 0.2.0 closes this by construction (Option 2), and the release notes or a ticket should say so.

**Option 1 (jinja), measured** (`sandbox_test.dart`, `tool/probe_jinja_sandbox.dart`):

* Cannot reach: files or network (no loader means `include`/`import` throw `StateError`; never configure `FileSystemLoader`), or Dart members (`{{ ''.runtimeType }}`, `'abc'.toUpperCase()`, `items.add(1)`, `project.clear()` all throw; member access needs `package:jinja/reflection.dart`, which uses `dart:mirrors` and is not available under AOT anyway).
* Stock globals: `print` writes to the app's stdout (captured in a test), plus `range`, `list` and `namespace`; the `runtimetype` filter reveals Dart type names. The tuned config removes them and caps `range`.
* CPU is unbounded. An empty loop costs about 2.7 µs per iteration because each iteration copies the context (`range(1e6)` 2.7 s, `range(1e7)` 27 s); 40^4 nested loops over context rows take 1.7 s; a doubling macro takes 6.2 s at 2^20 calls. Infinite recursion (`macro`, `for ... recursive` with `loop()`) ends in a catchable `StackOverflowError` in 20-50 ms.
* Memory is unbounded: `{{ ('x' * 50000000) | length }}` builds a 50 MB string in 0.3 s, and 100 MB took 0.7 s; `* 10000000000` would try to allocate 10 GB. `center(n)`, `wordwrap` and `batch` allocate in the same way.
* Mitigation: render in a separate isolate and `kill(priority: Isolate.immediate)` on timeout (`lib/src/isolate_render.dart`). Measured: a 2^28-call macro and 40^6 nested loops are both killed about 1.02 s after a 1 s timeout. **This bounds time, not memory**: isolates spawned in the same group share one heap, so an allocation bomb can still take the app down. jinja offers no public hook on `*`, `~` or `+` to cap sizes.

**Option 2 (subset), by construction**: there are no calls, globals, includes, macros or recursion, so a template can only read the export context and loop over finite values. The remaining costs are capped by `RenderLimits`: 5,000,000 loop iterations, 32 M chars per output or intermediate string, 256 M chars of total string work, and parser nesting of 200. Measured: 40^6 nested loops (4.1e9 iterations) stop in 3.5-4 s (lower the cap or optimise the per-iteration `loop` map to go faster); string doubling stops in 0.2 s; a 32 MB output flood stops in 1.5 s; 10,000 nested parentheses or 1,000 nested `if`s are a limit error in about 20 ms, with no stack overflow; `''.constructor` is just undefined. Defence in depth: still render off the UI isolate (`Isolate.run`, or `renderIsolated` with a timeout). Memory stays bounded because the renderer caps its own strings.

## 5. Preset port probe

`lib/src/presets.dart` ports `renderNestedJson`, `renderFlatJson`, `renderCsv`, `toCsv` and `csvEscape` (`presets_test.dart`). With the JS-compatible serialiser (`js_compat.dart`), **every preset is byte-identical**: flat JSON, nested JSON, flat JSON in selection scope, the CSV preview and all six CSV files. That holds for the JSON-decoded context and for a **SQLite-typed context** whose REAL columns are Dart doubles.

Byte differences a naive port would introduce:

* **Integral doubles.** `JsonEncoder`/`toString` print `12.0`. On the SQLite-typed context: flat JSON 70 changed lines, nested JSON 170, CSV 2 rows (`mana,12.0,3.0`, `stamina,5.0,1.0`). Every difference is a `.0` suffix (asserted). A JSON-decoded context shows none, so the fixtures alone would not catch it. Dart's `double.toString` otherwise agrees with JS: it differed on 6,838 of 20,025 sampled doubles, and stripping `.0` and printing `-0.0` as `0` fixed all of them (3,025 node-printed values checked in a test).
* **`-0.0`** prints `-0.0`; JS prints `0`.
* **NaN/Infinity**: `JsonEncoder` throws; JS writes `null`.
* **Integer-like keys**: JS orders `"2"`, `"10"` before other keys (custom field or metadata names such as `"10"`); Dart keeps insertion order.
* **`json(0)`**: `JsonEncoder.withIndent('')` still breaks lines; JS is compact.
* **int64 vs double**: Dart ints above 2^53 print exactly where JS rounds. Arithmetic in templates must use doubles (Option 2 does).
* Identical already: string escaping (control chars as `\b \t \n \f \r \u00xx`, lone surrogates as `\udxxx`, U+2028 unescaped), empty `[]`/`{}`, two-space layout, key order of the JS spreads (Dart `LinkedHashMap` keeps an overwritten key in place, like `{...c, abilities: x}`).
* CSV: LF line ends, no final newline, header from the first row's keys, quote only on `,` `"` or `\n` (a lone `\r` is not quoted), null/undefined as an empty cell, numbers via JS `String()`.
* Electron quirks to keep: flat JSON's `derived_stat_export_key` is the raw id (`derived-stat-max-hp`), because derived stats are missing from the lookup; `export_key` in templates ignores meta ids although the presets resolve them.

## 6. Recommendation

**Choose Option 2, the purpose-built renderer, in `packages/anvil_core`**, with `js_compat.dart` as the shared serialisation layer for presets and templates.

* **Exact where it matters, and fails loudly elsewhere.** It matches Electron on all 3 fixtures, all 45 documented-feature cases and all 32 edge cases. Across 149 cases it never prints different output: whatever it does not support is rejected at parse time with a position. jinja also passes the 3 fixtures, but it prints wrong output silently in 15 cases, including two documented features (string escapes, CRLF). Those causes sit in its core (truthiness, scoping, precedence, integer arithmetic), so they could only be fixed by forking it.
* **Safe by construction**: no host calls, includes, recursion or unbounded allocation, plus limits. jinja needs an isolate kill for time and has no answer for memory.
* **Pure Dart, no dependency**, so plain `dart test` runs in `anvil_core`. jinja.dart is a single-maintainer 0.x port ("work in progress"); we would carry its Jinja semantics and then patch around them.
* **Cost**: about 1,550 lines, specified by an executable corpus. That is modest next to the formula engine the rewrite ports anyway.

**Existing custom templates that use unsupported features.** On project open, and whenever the export page loads templates, run `AnvilTemplate.check()` on every `custom_templates.template_source`:

* Never rewrite or delete the stored source.
* Show a per-template warning on the export page, for example "Uses `{% macro %}` (line 3, column 4), which Anvil 0.2 does not support. Edit the template to export with it." Disable that template in the selector and open the editor at the reported position.
* Show one notice after opening a project with any such template ("2 custom templates need changes before they can export"), and log it.
* Errors at render time (undefined output, limits) surface like Electron's render errors, with line and column.

In practice 0.1.x users were steered to the documented subset, which renders identically, so only templates that used undocumented Nunjucks features are affected. If one of the unsupported filters turns out to be in use, add it; each is a few lines with a corpus case.

## 7. Draft child ticket for ANVL-147

**Summary:** Port the export engine to anvil_core: JS-compatible serialisation, the three presets, and a Nunjucks-compatible custom template renderer.

**Goals**

* Presets and custom templates produce byte-identical output to Anvil 0.1.6 for the same project file.
* Custom templates render through a pure-Dart, sandboxed renderer of the documented Nunjucks subset plus the common idioms (ANVL-151 FINDINGS §3).
* Templates using unsupported features are detected without rendering, and never altered.

**Acceptance criteria**

- [ ] `js_compat` (number formatting, `JSON.stringify`-compatible encoder with indent semantics and JS key order, `String()`, truthiness, operators) lives in `packages/anvil_core/lib/src/export/`, with the ANVL-151 JS-values fixture as its test.
- [ ] Nested JSON, Flat JSON (full, domain, selection) and CSV presets ported; byte-identical to the ANVL-151 preset fixtures for a context read through the Dart SQLite layer (REAL columns as doubles), not only a JSON-decoded one.
- [ ] Template renderer ported from the spike (lexer, parser, JS-precedence pass, evaluator, 15 filters) with the ANVL-151 parity corpus and the three template fixtures as tests: every `guide.*` and `edge.*` case matches; every unsupported case is a parse-time `unsupported` error.
- [ ] `export_key` and `json` keep Electron semantics (meta ids are not resolved; `json(0)` is compact).
- [ ] `export_key` uses an id index built once per render, not a linear scan per call.
- [ ] Render limits (iterations, output and intermediate string size, total string work, nesting) with defaults recorded in the design; rendering runs off the UI isolate.
- [ ] `checkTemplate(source)` API returns kind, message, line and column; the export service exposes per-template status for the UI (warning UI tracked under ANVL-149).
- [ ] No dependency on package:flutter or a third-party template engine; `dart test` in anvil_core covers all of the above.
- [ ] The 0.2.0 writing guide text lists exactly the supported subset and states that `export_key` does not resolve meta ids.

## 8. What ANVL-155 (implementation design) must record

1. The decision: a purpose-built renderer for a Nunjucks-compatible subset, not Jinja semantics and not a JS runtime, with the reasons in §6 and the rejected options.
2. The compatibility contract: 0.1.6 output byte for byte for supported features. The parity corpus and fixtures are the specification. They are regenerated with `tool/nunjucks_oracle.js` against the Electron `node_modules` until cutover; once ANVL-169 removes Electron the JSON fixtures are frozen.
3. JS value semantics are part of the export contract: number formatting, `JSON.stringify` layout and key order, `String()`, truthiness, loose equality, operator precedence, `undefined` vs `null`, and output-time undefined checks.
4. The number typing rule: REAL columns arrive as doubles, and every exporter prints integral doubles without `.0`. Template arithmetic is double-based, as in JS.
5. The sandbox model: no host calls, `RenderLimits` defaults, rendering off the UI isolate, and memory bounded by the renderer itself (isolates share a heap). Project files and their templates are untrusted input.
6. The unsupported-template policy (§6): check on load, warn per template, never rewrite.
7. Compatibility quirks that are kept on purpose (`export_key` and meta ids, flat JSON `derived_stat_export_key`, CSV `\r`). Any behaviour change must be a new, explicitly named filter or option, so existing templates never change output silently.
8. The 0.1.6 template escape (§4) as a known issue of the Electron line that 0.2.0 closes.
9. Where the code lives (`anvil_core/lib/src/export/`) and that the presets are Dart code, not templates.

## 9. Tests and tools in this package

`fvm dart test` (from `spikes/template_engine/`):

* `js_compat_test.dart`: numbers, `JSON.stringify` and `String()` against the node oracle, plus the documented `dart:convert` differences.
* `fixture_templates_test.dart`: the three templates byte for byte for both engines. It also asserts the accepted differences of two jinja variants: `3.0` with Dart `toString`, and `json(0)` / missing `dump` with jinja defaults.
* `parity_corpus_test.dart`: scores both engines on the 149-case corpus and pins each engine's set of misses. These are accepted, documented differences, not equality, so any engine change shows up there.
* `sandbox_test.dart`: reach probes, limits and timings, and isolate kill.
* `presets_test.dart`: every preset byte for byte on both contexts. It also asserts the naive-port differences (only `.0` suffixes, with exact counts).

Tools: `tool/nunjucks_oracle.js` + `tool/parity_cases.js` (corpus), `tool/js_values_oracle.js` (JS values), `tool/score_corpus.dart` (corpus summary per engine), `tool/probe_jinja_sandbox.dart` (jinja timings, about 2 minutes), `tool/bench.dart` (throughput).

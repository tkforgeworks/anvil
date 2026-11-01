# Formula parity corpus

`formula-corpus.json` is the expected behaviour of the Electron 0.1.6 formula engine
(`src/main/formula/engine.ts`) for every case in `build-formula-corpus.test.ts`, a throwaway vitest
oracle. `test/formula/parity_test.dart` runs each case through the Dart port and asserts the same
`value`, `error`, `isSyntaxError`, `validateFormula` message (`validate`) and
`extractVariableNames` list (`variables`).

Encoding: numbers (`value` and `bindings`) are JSON numbers, except NaN, Infinity, -Infinity and
negative zero, which are the strings `"NaN"`, `"Infinity"`, `"-Infinity"` and `"-0"`. A case with
`repeat` instead of `formula` stands for `open × depth + core + close × depth` (the stack-overflow
cases, which would otherwise be hundreds of kilobytes).

To regenerate, from the anvil checkout with `node_modules` installed (the engine does not use
better-sqlite3, so no rebuild is needed; the oracle mocks `app-logger`, which pulls in Electron):

    mkdir -p src/main/__spike__
    cp packages/anvil_core/test/fixtures/formula/build-formula-corpus.test.ts src/main/__spike__/
    FORMULA_CORPUS_DIR=packages/anvil_core/test/fixtures/formula \
      npx vitest run src/main/__spike__/build-formula-corpus.test.ts
    rm -rf src/main/__spike__

Add cases to the `CASES` list in the oracle, never by hand to the JSON. Cases whose JavaScript
result is not a number are rejected by the oracle: identifiers that name `Object.prototype`
members (`constructor`, `toString`, `valueOf`, `hasOwnProperty`, `__proto__`, ...) resolve to
those members in 0.1.6, as variables and as functions, and the Dart port deliberately treats them
as unknown. The oracle is regenerated until cutover (ANVL-169) and then frozen.

Nesting depth: 0.1.6 has no explicit limit. A formula fails when Node's stack overflows, after
roughly a few thousand nesting levels, depending on the machine. The Dart engine instead stops at
`maxFormulaNestingDepth` (1000 levels; a deeper formula is `Invalid formula` /
`Formula evaluation failed`). It also stops evaluating a tree deeper than `maxFormulaTreeDepth`
(2000), which bounds long flat chains such as `x + x + ... + x`. Between those limits and Node's,
the two engines can differ, so the corpus deliberately holds no case in that band: its `repeat`
cases are 500 levels deep, which both engines handle, or 200000, which both reject.

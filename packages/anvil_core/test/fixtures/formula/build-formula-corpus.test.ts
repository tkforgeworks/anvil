// Throwaway oracle: runs a case list through the Electron 0.1.6 formula engine
// and writes the results to formula-corpus.json, the parity specification for
// packages/anvil_core/lib/src/formula/. See README.md beside this file.
import { writeFileSync } from 'fs'
import { join } from 'path'
import { it, vi } from 'vitest'

// engine.ts logs through app-logger, which pulls in Electron.
vi.mock('../logging/app-logger', () => ({
  logWarn: () => {},
  logError: () => {},
  logInfo: () => {},
  logDebug: () => {},
}))

import { evaluateFormula, extractVariableNames, validateFormula } from '../formula/engine'

const OUT = process.env.FORMULA_CORPUS_DIR!

type Num = number | string
interface Repeat { open: string; core: string; close: string; depth: number }
interface CaseIn { formula?: string; repeat?: Repeat; bindings?: Record<string, Num>; note?: string }

/** JSON-safe number: specials and negative zero become strings. */
function enc(v: number): Num {
  if (Number.isNaN(v)) return 'NaN'
  if (v === Infinity) return 'Infinity'
  if (v === -Infinity) return '-Infinity'
  if (Object.is(v, -0)) return '-0'
  return v
}
function dec(v: Num): number {
  if (typeof v === 'number') return v
  return v === '-0' ? -0 : Number(v)
}

const zeros = (n: number): string => '0'.repeat(n)

const CASES: CaseIn[] = [
  // ─── Arithmetic and precedence ───
  { formula: '1' },
  { formula: '42' },
  { formula: '1 + 2' },
  { formula: '1 + 2 * 3' },
  { formula: '(1 + 2) * 3' },
  { formula: '10 - 4 - 3', note: 'left associative' },
  { formula: '100 / 10 / 5', note: 'left associative' },
  { formula: '2 * 3 / 4' },
  { formula: '1 - 2 + 3' },
  { formula: '((((1))))' },
  { formula: '(1 + (2 * (3 - (4 / 2))))' },
  { formula: '((1 + 2) * (3 + 4))' },
  { formula: '0.1 + 0.2' },
  { formula: '0.1 * 3' },
  { formula: '1 / 3' },
  { formula: '2 / 3 * 3' },
  { formula: '1 + 2 * 3 - 4 / 5' },
  { formula: '8 - 2 * 3 + 1' },
  // ─── Number literals (parseFloat prefix semantics) ───
  { formula: '1.2.3' },
  { formula: '.5' },
  { formula: '5.' },
  { formula: '.' },
  { formula: '.5.5' },
  { formula: '1..2' },
  { formula: '..5' },
  { formula: '1.5.5 + 1' },
  { formula: '007' },
  { formula: '0.000' },
  { formula: '1e5' },
  { formula: '1 . 5' },
  { formula: '99999999999999999999' },
  { formula: '123456789.123456789' },
  { formula: '3.14159265358979323846' },
  { formula: '0.' + zeros(323) + '1', note: '1e-324 rounds to zero' },
  { formula: '1 / 0.' + zeros(323) + '1', note: 'divisor literal rounds to zero' },
  { formula: '1 / 0.' + zeros(319) + '1', note: 'denormal divisor' },
  { formula: '1' + zeros(309), note: 'literal overflows to Infinity' },
  { formula: '1' + zeros(308) + ' * 10' },
  { formula: '1' + zeros(309) + ' - 1' + zeros(309) },
  { formula: '-1' + zeros(309) },
  // ─── Unary minus ───
  { formula: '-3' },
  { formula: '--3' },
  { formula: '---3' },
  { formula: '-(2)' },
  { formula: '2*-3' },
  { formula: '2 - -3' },
  { formula: '-2 * -3' },
  { formula: '- 3' },
  { formula: '-x', bindings: { x: 4 } },
  { formula: '-0' },
  { formula: '-(0)' },
  { formula: '0 * -1' },
  { formula: '-0 + 0' },
  { formula: '-0 - 0' },
  { formula: '-min(1, 2)' },
  { formula: '-' },
  { formula: '2 * -' },
  { formula: '+3' },
  { formula: '2 + + 3' },
  { formula: '-(-(q))', bindings: { q: 2 } },
  // ─── Division ───
  { formula: '1 / 0' },
  { formula: '1 / 0.0' },
  { formula: '1 / -0' },
  { formula: '1 / -0.0' },
  { formula: '0 / 0' },
  { formula: 'x / y', bindings: { x: 1, y: 0 } },
  { formula: '1 / (2 - 2)' },
  { formula: '1 / (0.1 + 0.2 - 0.3)' },
  { formula: 'x / 0' },
  { formula: '1 / 0 + y' },
  { formula: 'y + 1 / 0' },
  { formula: '0 / x', bindings: { x: 0 } },
  { formula: '1 / x', bindings: { x: 'NaN' } },
  { formula: '1 / x', bindings: { x: 'Infinity' } },
  { formula: '-1 / x', bindings: { x: 'Infinity' } },
  { formula: '1 / x', bindings: { x: '-0' } },
  { formula: '5 / 2' },
  // ─── Built-in functions ───
  { formula: 'min(1, 2)' },
  { formula: 'max(1, 2)' },
  { formula: 'min(3, 1, 2)' },
  { formula: 'max(3, 1, 2, 5)' },
  { formula: 'min(7)' },
  { formula: 'min()' },
  { formula: 'max()' },
  { formula: 'floor()' },
  { formula: 'ceil()' },
  { formula: 'floor(2.7)' },
  { formula: 'floor(-2.7)' },
  { formula: 'ceil(2.1)' },
  { formula: 'ceil(-2.1)' },
  { formula: 'floor(-0.5)' },
  { formula: 'ceil(-0.5)' },
  { formula: 'floor(1, 2)' },
  { formula: 'ceil(1.5, 99)' },
  { formula: 'floor(1, foo(2))', note: 'extra args are still evaluated' },
  { formula: 'min(0, -0)' },
  { formula: 'min(-0, 0)' },
  { formula: 'max(-0, 0)' },
  { formula: 'max(0, -0)' },
  { formula: 'min(1, x)', bindings: { x: 'NaN' } },
  { formula: 'max(x)', bindings: { x: 'NaN' } },
  { formula: 'floor(x)', bindings: { x: 'Infinity' } },
  { formula: 'ceil(x)', bindings: { x: '-Infinity' } },
  { formula: 'floor(x)', bindings: { x: 'NaN' } },
  { formula: 'floor(min())' },
  { formula: 'ceil(max())' },
  { formula: 'floor(max(1.5, 2.5))' },
  { formula: 'max(min(1, 2), min(3, 4))' },
  { formula: 'min(max(1, floor(2.9)), ceil(0.1))' },
  { formula: 'MIN(1, 2)' },
  { formula: 'Floor(1.5)' },
  { formula: 'sqrt(4)' },
  { formula: 'pow(2, 3)' },
  { formula: 'foo(x)' },
  { formula: 'min(x, foo(1))', bindings: { x: 1 } },
  { formula: 'min(y, 1)' },
  { formula: 'min' },
  { formula: 'min + 1', bindings: { min: 5 } },
  { formula: 'min(min, 1)', bindings: { min: 0 } },
  { formula: 'floor + ceil', bindings: { floor: 1, ceil: 2 } },
  { formula: 'min (1, 2)' },
  { formula: 'min(1,2)' },
  { formula: 'min( 1 , 2 )' },
  { formula: 'max(1, min(2, max(3, min(4, 5))))' },
  // ─── Malformed calls ───
  { formula: 'min(1,)' },
  { formula: 'min(,1)' },
  { formula: 'min(1 2)' },
  { formula: 'min(1' },
  { formula: 'min(' },
  { formula: 'min(1, 2' },
  { formula: 'min(1, 2))' },
  { formula: 'floor((1)' },
  { formula: 'min(1,,2)' },
  { formula: 'min)' },
  // ─── Parentheses and stray tokens ───
  { formula: '(1 + 2' },
  { formula: '1 + 2)' },
  { formula: '()' },
  { formula: '(' },
  { formula: ')' },
  { formula: '(1,2)' },
  { formula: '(1)(2)' },
  { formula: '2(3)' },
  { formula: '1, 2' },
  { formula: ',' },
  { formula: '1 +' },
  { formula: '* 2' },
  { formula: '1 * / 2' },
  { formula: '1 2 3' },
  { formula: '((1)' },
  { formula: '(1))' },
  // ─── Lexer errors ───
  { formula: '1 + #' },
  { formula: '1 % 2' },
  { formula: '2 ^ 3' },
  { formula: 'a.b' },
  { formula: 'x$' },
  { formula: 'é + 1' },
  { formula: '1 + 2 )#', note: 'lexer errors win over parse errors' },
  { formula: '1 = 1' },
  { formula: 'x;' },
  { formula: '[1]' },
  { formula: '\u{1F600}', note: 'astral character: the message holds the lone high surrogate' },
  { formula: '1 + 2 @ 3' },
  { formula: '1\u0000' },
  { formula: '"1"' },
  // ─── Empty and whitespace ───
  { formula: '' },
  { formula: '   ' },
  { formula: '\t\n' },
  { formula: ' ' },
  { formula: '﻿' },
  { formula: '\u0085', note: 'NEL is not JavaScript whitespace' },
  { formula: '᠎' },
  { formula: '​' },
  { formula: '  1 　' },
  { formula: '  2  ' },
  { formula: '\v\f3' },
  { formula: ' 1 + 2 ' },
  { formula: '1\n+\n2' },
  { formula: '\t1\t*\t2\t' },
  { formula: '1+2' },
  { formula: '1\r\n+ 2' },
  // ─── Identifiers and variable extraction ───
  { formula: 'x', bindings: { x: 5 } },
  { formula: 'x' },
  { formula: '_x1', bindings: { _x1: 3 } },
  { formula: '__', bindings: { __: 1 } },
  { formula: 'level_2', bindings: { level_2: 9 } },
  { formula: 'X', bindings: { x: 1 } },
  { formula: '1x' },
  { formula: 'x y' },
  { formula: 'x + y', bindings: { x: 1 } },
  { formula: 'x + x + y + x', bindings: { x: 1, y: 2 } },
  { formula: 'b + a * c - a', bindings: { a: 1, b: 2, c: 3 } },
  { formula: 'max(c, b) + floor(a)', bindings: { a: 1.5, b: 2, c: 3 } },
  { formula: 'foo(z)' },
  { formula: 'x + y', bindings: { x: 1, y: 2, z: 3 }, note: 'extra bindings are ignored' },
  // ─── Bindings with special values ───
  { formula: 'x', bindings: { x: '-0' } },
  { formula: 'x + 1', bindings: { x: 'Infinity' } },
  { formula: 'x * 0', bindings: { x: 'Infinity' } },
  { formula: 'x - x', bindings: { x: 'Infinity' } },
  { formula: 'x', bindings: { x: 'NaN' } },
  { formula: 'x * 2', bindings: { x: 1e308 } },
  { formula: 'x', bindings: { x: 5e-324 } },
  // ─── Realistic Anvil formulas ───
  { formula: 'floor(base_hp + level * hp_growth)', bindings: { base_hp: 50, level: 10, hp_growth: 7.5 } },
  { formula: 'floor(base_hp + level * hp_growth)', bindings: { base_hp: 50, level: 1, hp_growth: 7.3 } },
  { formula: 'max(1, strength * 0.5)', bindings: { strength: 1 } },
  { formula: 'max(1, strength * 0.5)', bindings: { strength: 31 } },
  { formula: 'strength * 2 + agility', bindings: { strength: 12, agility: 7 } },
  { formula: 'floor(intelligence * 1.5 + level / 2)', bindings: { intelligence: 11, level: 3 } },
  { formula: 'ceil(level / max_level * 100)', bindings: { level: 7, max_level: 50 } },
  { formula: 'level * level * 0.5 + 10', bindings: { level: 13 } },
  { formula: 'floor(10 + level * 1.25)', bindings: { level: 17 } },
  { formula: 'min(100, floor(dexterity / 4 + level))', bindings: { dexterity: 300, level: 40 } },
  { formula: '(strength + constitution) / 2', bindings: { strength: 9, constitution: 14 } },
  { formula: 'max(0, armor - penetration)', bindings: { armor: 5, penetration: 12 } },
  { formula: 'floor(base_mp * resource_multiplier)', bindings: { base_mp: 33, resource_multiplier: 1.1 } },
  { formula: 'attack_power + floor(strength / 3) - 1', bindings: { attack_power: 20, strength: 10 } },
  { formula: 'max_level - level', bindings: { max_level: 50, level: 50 } },
  // ─── Depth: moderate nesting works, extreme nesting overflows the stack ───
  { repeat: { open: '(', core: '1', close: ')', depth: 500 } },
  { repeat: { open: '-', core: '1', close: '', depth: 501 } },
  { repeat: { open: 'x+', core: 'x', close: '', depth: 500 }, bindings: { x: 1 } },
  { repeat: { open: '(', core: '1', close: ')', depth: 200000 }, note: 'parse overflows' },
  { repeat: { open: '-', core: '1', close: '', depth: 200000 }, note: 'parse overflows' },
  { repeat: { open: 'x+', core: 'x', close: '', depth: 200000 }, bindings: { x: 1 },
    note: 'parses iteratively, evaluation and variable collection overflow' },
]

const build = (c: CaseIn): string =>
  c.repeat
    ? c.repeat.open.repeat(c.repeat.depth) + c.repeat.core + c.repeat.close.repeat(c.repeat.depth)
    : c.formula!

it('builds the formula parity corpus', () => {
  const cases = CASES.map((c) => {
    const formula = build(c)
    const encBindings = c.bindings ?? {}
    const bindings: Record<string, number> = {}
    for (const [k, v] of Object.entries(encBindings)) bindings[k] = dec(v)
    const r = evaluateFormula(formula, bindings)
    if (r.value !== null && typeof r.value !== 'number') {
      throw new Error(`non-numeric result for ${formula}`)
    }
    return {
      ...(c.note ? { note: c.note } : {}),
      ...(c.repeat ? { repeat: c.repeat } : { formula }),
      bindings: encBindings,
      value: r.value === null ? null : enc(r.value),
      error: r.error,
      isSyntaxError: r.isSyntaxError,
      validate: validateFormula(formula),
      variables: extractVariableNames(formula),
    }
  })
  const corpus = {
    generator: 'packages/anvil_core/test/fixtures/formula/build-formula-corpus.test.ts',
    engine: 'src/main/formula/engine.ts (Electron 0.1.6)',
    encoding:
      "Numbers are JSON numbers, except NaN, Infinity, -Infinity and negative zero, which are the strings 'NaN', 'Infinity', '-Infinity' and '-0'. A case with 'repeat' instead of 'formula' is open × depth + core + close × depth.",
    cases,
  }
  writeFileSync(join(OUT, 'formula-corpus.json'), JSON.stringify(corpus, null, 1) + '\n')
})

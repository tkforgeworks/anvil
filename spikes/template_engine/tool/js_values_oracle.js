// Writes test/fixtures/js-values.json: what JavaScript prints for values the
// Dart port must serialise identically (JSON.stringify, String(), numbers).
// The Dart tests rebuild each value by name (test/js_compat_test.dart).
//   node tool/js_values_oracle.js
const fs = require('fs')
const path = require('path')

const numbers = []
const dv = new DataView(new ArrayBuffer(8))
function addNumber(x) {
  dv.setFloat64(0, x)
  numbers.push([dv.getBigUint64(0).toString(16).padStart(16, '0'), String(x)])
}
let seed = 7
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 }
for (let i = 0; i < 3000; i++) {
  let x = (rnd() - 0.5) * Math.pow(10, Math.floor(rnd() * 60) - 30)
  if (i % 3 === 0) x = Math.round(x)
  if (i % 5 === 0) x = Math.round(x * 100) / 100
  addNumber(x)
}
for (const x of [0, -0, 1, -1, 0.1, 0.2, 0.1 + 0.2, 1e21, 1e20, 123456789012345680000, 1e-6, 1e-7,
  1.5e-7, 5e-324, 1.7976931348623157e308, 2 ** 53, 2 ** 53 + 2, 0.8, 1.25, 12, 100, 1 / 3, NaN, Infinity, -Infinity]) addNumber(x)

const keyOrder = {}
for (const k of ['b', '2', '10', 'a', '01', '4294967295', '4294967294', '-1', '1.5']) keyOrder[k] = k
const json = {
  numbers: [JSON.stringify([1, 1.5, 0.8, 1.25, -0, 1e21, 1e-7, 100, 0.1 + 0.2, 12])],
  non_finite: [JSON.stringify([NaN, Infinity, -Infinity])],
  escapes: [JSON.stringify('\u0000\u0001\b\t\n\u000b\f\r\u001f \"\\/ é    \u007f 😀')],
  lone_surrogates: [JSON.stringify('a\ud800b\udc00c\ud83d')],
  key_order: [JSON.stringify(keyOrder)],
  nested_empty_2: [JSON.stringify({ a: [], b: {}, c: [[]], d: [{}], e: { f: [1, { g: null }] } }, null, 2)],
  undefined_members: [JSON.stringify({ a: undefined, b: 1, c: [undefined, null] })],
  indents: [0, 1, 4, 10, 11, -3, 2.7, '\t', 'abcdefghijkl', null, true].map((s) => JSON.stringify({ k: [1, 'x'] }, null, s)),
}
const toStringCases = {
  list_mixed: String([1, 2, 'a']),
  list_nullish: String([null, undefined, 1]),
  list_nested: String([[1, 2], [3]]),
  object: String({}),
  bools: String(true) + String(false),
  number_integral: String(1.0),
  number_negative_zero: String(-0),
  number_float: String(0.8),
}
fs.writeFileSync(path.join(__dirname, '../test/fixtures/js-values.json'),
  JSON.stringify({ numbers, json, toString: toStringCases }, null, 1) + '\n')
console.log(`${numbers.length} numbers, ${Object.keys(json).length} JSON cases`)

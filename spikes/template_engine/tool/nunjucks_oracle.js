// Renders tool/parity_cases.js with Nunjucks in Anvil 0.1.6's exact
// environment (src/main/export/renderer.ts) and writes the results to
// test/fixtures/nunjucks-parity.json. Needs the Electron app's node_modules:
//   NUNJUCKS=/path/to/anvil/node_modules/nunjucks node tool/nunjucks_oracle.js
const path = require('path')
const fs = require('fs')
const nunjucks = require(process.env.NUNJUCKS || path.join(__dirname, '../../../node_modules/nunjucks'))
const here = __dirname
const env = new nunjucks.Environment(null, { autoescape: false, throwOnUndefined: true })
env.addFilter('json', (value, indent) => JSON.stringify(value, null, indent ?? 2))
env.addFilter('export_key', function (id) {
  const ctx = this.ctx
  for (const domain of ['classes', 'abilities', 'items', 'recipes', 'npcs', 'loot_tables']) {
    const match = ctx[domain].find((r) => r.id === id)
    if (match) return match.export_key
  }
  return id
})
const context = JSON.parse(fs.readFileSync(path.join(here, '../test/fixtures/context-full.json'), 'utf8'))
const cases = require('./parity_cases.js')
const out = {}
for (const [name, source] of Object.entries(cases)) {
  try {
    out[name] = { source, ok: true, output: env.renderString(source, { ...context, ctx: context }) }
  } catch (e) {
    out[name] = { source, ok: false, error: String(e).split('\n').map((s) => s.trim()).filter(Boolean).join(' | ') }
  }
}
fs.writeFileSync(path.join(here, '../test/fixtures/nunjucks-parity.json'), JSON.stringify(out, null, 2) + '\n')
console.log(`${Object.keys(out).length} cases, ${Object.values(out).filter((r) => !r.ok).length} errors`)

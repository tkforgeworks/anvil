import { logWarn } from '../logging/app-logger'

/**
 * Custom recursive-descent formula parser and evaluator.
 *
 * Grammar:
 *   expr    = term (('+' | '-') term)*
 *   term    = factor (('*' | '/') factor)*
 *   factor  = '-' factor | primary
 *   primary = NUMBER | IDENT '(' arglist ')' | IDENT | '(' expr ')'
 *   arglist = expr (',' expr)*
 *
 * Supported functions: min, max, floor, ceil
 * Variables: any identifier resolved from the provided bindings map.
 */

// ─── Errors ───────────────────────────────────────────────────────────────────

export class FormulaSyntaxError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'FormulaSyntaxError'
  }
}

export class FormulaRuntimeError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'FormulaRuntimeError'
  }
}

// ─── Lexer ────────────────────────────────────────────────────────────────────

type TokenType =
  | 'NUMBER'
  | 'IDENT'
  | 'PLUS'
  | 'MINUS'
  | 'STAR'
  | 'SLASH'
  | 'LPAREN'
  | 'RPAREN'
  | 'COMMA'
  | 'EOF'

interface Token {
  type: TokenType
  value: string
  pos: number
}

function tokenize(input: string): Token[] {
  const tokens: Token[] = []
  let pos = 0

  while (pos < input.length) {
    // Skip whitespace
    if (/\s/.test(input[pos])) { pos++; continue }

    const ch = input[pos]

    // Number literal (integer or decimal)
    if (/[0-9]/.test(ch) || (ch === '.' && pos + 1 < input.length && /[0-9]/.test(input[pos + 1]))) {
      const start = pos
      while (pos < input.length && /[0-9.]/.test(input[pos])) pos++
      tokens.push({ type: 'NUMBER', value: input.slice(start, pos), pos: start })
      continue
    }

    // Identifier
    if (/[a-zA-Z_]/.test(ch)) {
      const start = pos
      while (pos < input.length && /[a-zA-Z0-9_]/.test(input[pos])) pos++
      tokens.push({ type: 'IDENT', value: input.slice(start, pos), pos: start })
      continue
    }

    // Single-character tokens
    const single: Record<string, TokenType> = {
      '+': 'PLUS', '-': 'MINUS', '*': 'STAR', '/': 'SLASH',
      '(': 'LPAREN', ')': 'RPAREN', ',': 'COMMA',
    }
    if (single[ch]) {
      tokens.push({ type: single[ch], value: ch, pos: pos++ })
      continue
    }

    throw new FormulaSyntaxError(`Unexpected character '${ch}' at position ${pos}`)
  }

  tokens.push({ type: 'EOF', value: '', pos })
  return tokens
}

// ─── AST ──────────────────────────────────────────────────────────────────────

type Expr =
  | { kind: 'number'; value: number }
  | { kind: 'variable'; name: string }
  | { kind: 'unary'; operand: Expr }
  | { kind: 'binary'; op: '+' | '-' | '*' | '/'; left: Expr; right: Expr }
  | { kind: 'call'; name: string; args: Expr[] }

// ─── Parser ───────────────────────────────────────────────────────────────────

function parse(tokens: Token[]): Expr {
  let pos = 0

  const peek = (): Token => tokens[pos]
  const consume = (): Token => tokens[pos++]

  const expect = (type: TokenType): Token => {
    if (peek().type !== type) {
      throw new FormulaSyntaxError(
        `Expected ${type} but found '${peek().value}' at position ${peek().pos}`,
      )
    }
    return consume()
  }

  const parseExpr = (): Expr => {
    let left = parseTerm()
    while (peek().type === 'PLUS' || peek().type === 'MINUS') {
      const op = consume().type === 'PLUS' ? '+' : '-'
      left = { kind: 'binary', op, left, right: parseTerm() }
    }
    return left
  }

  const parseTerm = (): Expr => {
    let left = parseFactor()
    while (peek().type === 'STAR' || peek().type === 'SLASH') {
      const op = consume().type === 'STAR' ? '*' : '/'
      left = { kind: 'binary', op, left, right: parseFactor() }
    }
    return left
  }

  const parseFactor = (): Expr => {
    if (peek().type === 'MINUS') {
      consume()
      return { kind: 'unary', operand: parseFactor() }
    }
    return parsePrimary()
  }

  const parsePrimary = (): Expr => {
    const tok = peek()

    if (tok.type === 'NUMBER') {
      consume()
      const value = parseFloat(tok.value)
      if (isNaN(value)) throw new FormulaSyntaxError(`Invalid number '${tok.value}'`)
      return { kind: 'number', value }
    }

    if (tok.type === 'IDENT') {
      consume()
      if (peek().type === 'LPAREN') {
        consume() // '('
        const args: Expr[] = []
        if (peek().type !== 'RPAREN') {
          args.push(parseExpr())
          while (peek().type === 'COMMA') {
            consume()
            args.push(parseExpr())
          }
        }
        expect('RPAREN')
        return { kind: 'call', name: tok.value, args }
      }
      return { kind: 'variable', name: tok.value }
    }

    if (tok.type === 'LPAREN') {
      consume()
      const expr = parseExpr()
      expect('RPAREN')
      return expr
    }

    if (tok.type === 'EOF') {
      throw new FormulaSyntaxError('Unexpected end of formula')
    }

    throw new FormulaSyntaxError(`Unexpected '${tok.value}' at position ${tok.pos}`)
  }

  const ast = parseExpr()
  if (peek().type !== 'EOF') {
    throw new FormulaSyntaxError(`Unexpected '${peek().value}' at position ${peek().pos}`)
  }
  return ast
}

// ─── Evaluator ────────────────────────────────────────────────────────────────

const BUILTINS: Record<string, (...args: number[]) => number> = {
  min: (...args) => Math.min(...args),
  max: (...args) => Math.max(...args),
  floor: (x) => Math.floor(x),
  ceil: (x) => Math.ceil(x),
}

function evalExpr(expr: Expr, bindings: Record<string, number>): number {
  switch (expr.kind) {
    case 'number':
      return expr.value

    case 'variable': {
      const val = bindings[expr.name]
      if (val === undefined) {
        throw new FormulaRuntimeError(`Unknown variable '${expr.name}'`)
      }
      return val
    }

    case 'unary':
      return -evalExpr(expr.operand, bindings)

    case 'binary': {
      const l = evalExpr(expr.left, bindings)
      const r = evalExpr(expr.right, bindings)
      switch (expr.op) {
        case '+': return l + r
        case '-': return l - r
        case '*': return l * r
        case '/':
          if (r === 0) throw new FormulaRuntimeError('Division by zero')
          return l / r
      }
    }

    case 'call': {
      const fn = BUILTINS[expr.name]
      if (!fn) throw new FormulaRuntimeError(`Unknown function '${expr.name}'`)
      return fn(...expr.args.map((a) => evalExpr(a, bindings)))
    }
  }
}

// ─── Variable extraction (for cycle detection) ────────────────────────────────

function collectVars(expr: Expr, acc: Set<string>): void {
  switch (expr.kind) {
    case 'number': break
    case 'variable': acc.add(expr.name); break
    case 'unary': collectVars(expr.operand, acc); break
    case 'binary': collectVars(expr.left, acc); collectVars(expr.right, acc); break
    case 'call': expr.args.forEach((a) => collectVars(a, acc)); break
  }
}

// ─── Public API ───────────────────────────────────────────────────────────────

export interface FormulaEvalResult {
  value: number | null
  error: string | null
  isSyntaxError: boolean
}

/**
 * Evaluates a formula string with the given variable bindings.
 * Syntax errors and runtime errors are caught and returned in the result.
 */
export function evaluateFormula(
  formula: string,
  bindings: Record<string, number>,
): FormulaEvalResult {
  if (!formula.trim()) {
    return { value: null, error: 'Formula is empty', isSyntaxError: true }
  }
  try {
    const tokens = tokenize(formula)
    const ast = parse(tokens)
    const value = evalExpr(ast, bindings)
    return { value, error: null, isSyntaxError: false }
  } catch (e) {
    if (e instanceof FormulaSyntaxError) {
      logWarn(`Formula syntax error: ${e.message}`)
      return { value: null, error: e.message, isSyntaxError: true }
    }
    if (e instanceof FormulaRuntimeError) {
      logWarn(`Formula runtime error: ${e.message}`)
      return { value: null, error: e.message, isSyntaxError: false }
    }
    logWarn('Formula evaluation failed')
    return { value: null, error: 'Formula evaluation failed', isSyntaxError: false }
  }
}

/**
 * Validates formula syntax only. Returns an error message or null if valid.
 */
export function validateFormula(formula: string): string | null {
  if (!formula.trim()) return 'Formula is empty'
  try {
    parse(tokenize(formula))
    return null
  } catch (e) {
    return e instanceof FormulaSyntaxError ? e.message : 'Invalid formula'
  }
}

/**
 * Returns all variable names referenced in a formula.
 * Returns an empty array if the formula has a syntax error.
 */
export function extractVariableNames(formula: string): string[] {
  try {
    const tokens = tokenize(formula)
    const ast = parse(tokens)
    const vars = new Set<string>()
    collectVars(ast, vars)
    // Remove built-in function names that might appear as identifiers
    for (const fn of Object.keys(BUILTINS)) vars.delete(fn)
    return [...vars]
  } catch {
    return []
  }
}

import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { FormulaEvalResult } from '../../shared/domain-types'
import { evaluateFormula } from '../formula/engine'

interface FormulaEvalRequest {
  formula: string
  bindings: Record<string, number>
}

export function registerFormulaHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.FORMULA_EVALUATE,
    (_event, formula: string, bindings: Record<string, number>): FormulaEvalResult =>
      evaluateFormula(formula, bindings),
  )

  ipcMain.handle(
    IPC_CHANNELS.FORMULA_EVALUATE_BATCH,
    (_event, requests: FormulaEvalRequest[]): FormulaEvalResult[] =>
      requests.map((r) => evaluateFormula(r.formula, r.bindings)),
  )
}

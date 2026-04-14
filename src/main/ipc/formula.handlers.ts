import { ipcMain } from 'electron'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { FormulaEvalResult } from '../../shared/domain-types'
import { evaluateFormula } from '../formula/engine'

export function registerFormulaHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.FORMULA_EVALUATE,
    (_event, formula: string, bindings: Record<string, number>): FormulaEvalResult =>
      evaluateFormula(formula, bindings),
  )
}

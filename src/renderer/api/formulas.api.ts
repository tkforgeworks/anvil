import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type { FormulaEvalResult } from '../../shared/domain-types'

export const formulasApi = {
  evaluate: (formula: string, bindings: Record<string, number>) =>
    window.anvil.invoke<FormulaEvalResult>(IPC_CHANNELS.FORMULA_EVALUATE, formula, bindings),

  evaluateBatch: (requests: Array<{ formula: string; bindings: Record<string, number> }>) =>
    window.anvil.invoke<FormulaEvalResult[]>(IPC_CHANNELS.FORMULA_EVALUATE_BATCH, requests),
}

import { create } from 'zustand'
import type { ValidationIssue } from '../../../shared/domain-types'

interface ValidationState {
  issues: ValidationIssue[]
  lastValidatedAt: string | null

  setIssues: (issues: ValidationIssue[]) => void
  clearIssues: () => void
}

export const useValidationStore = create<ValidationState>()((set) => ({
  issues: [],
  lastValidatedAt: null,

  setIssues: (issues) => set({ issues, lastValidatedAt: new Date().toISOString() }),
  clearIssues: () => set({ issues: [], lastValidatedAt: null }),
}))

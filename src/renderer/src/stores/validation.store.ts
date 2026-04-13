import { create } from 'zustand'

export type ValidationSeverity = 'error' | 'warning' | 'info'

export interface ValidationIssue {
  id: string
  domain: string
  recordId: string
  recordDisplayName: string
  field: string | null
  severity: ValidationSeverity
  message: string
}

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

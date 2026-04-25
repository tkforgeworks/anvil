import type { ValidationIssue } from '../../../shared/domain-types'

interface FieldValidationResult {
  error: boolean
  helperText: string | undefined
}

export function fieldValidationProps(issues: ValidationIssue[]): FieldValidationResult {
  if (issues.length === 0) return { error: false, helperText: undefined }
  const first = issues[0]
  return {
    error: first.severity === 'error',
    helperText: first.message,
  }
}

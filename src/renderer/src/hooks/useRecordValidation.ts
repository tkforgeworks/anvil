import { useCallback, useState } from 'react'
import { validationApi } from '../../api/validation.api'
import type { ValidationDomain, ValidationIssue } from '../../../shared/domain-types'
import { useValidationStore } from '../stores/validation.store'

interface UseRecordValidationResult {
  recordIssues: ValidationIssue[]
  issuesForField: (field: string) => ValidationIssue[]
  errorCount: number
  warningCount: number
  runValidation: () => Promise<void>
}

export function useRecordValidation(
  domain: ValidationDomain,
  recordId: string | undefined,
): UseRecordValidationResult {
  const [recordIssues, setRecordIssues] = useState<ValidationIssue[]>([])
  const setGlobalIssues = useValidationStore((s) => s.setIssues)

  const runValidation = useCallback(async () => {
    if (!recordId) return
    const all = await validationApi.run()
    setGlobalIssues(all)
    setRecordIssues(all.filter((i) => i.domain === domain && i.recordId === recordId))
  }, [domain, recordId, setGlobalIssues])

  const issuesForField = useCallback(
    (field: string) => recordIssues.filter((i) => i.field === field),
    [recordIssues],
  )

  const errorCount = recordIssues.filter((i) => i.severity === 'error').length
  const warningCount = recordIssues.filter((i) => i.severity === 'warning').length

  return { recordIssues, issuesForField, errorCount, warningCount, runValidation }
}

import { useMemo } from 'react'

export function useTabDirtyTracking<T extends Record<string, unknown>>(
  current: T | null,
  baseline: T | null,
  tabFieldMap: Record<number, (keyof T)[]>
): Set<number> {
  return useMemo(() => {
    const dirty = new Set<number>()
    if (!current || !baseline) return dirty
    for (const [tabStr, fields] of Object.entries(tabFieldMap)) {
      const tabIndex = Number(tabStr)
      for (const field of fields) {
        if (JSON.stringify(current[field]) !== JSON.stringify(baseline[field])) {
          dirty.add(tabIndex)
          break
        }
      }
    }
    return dirty
  }, [current, baseline, tabFieldMap])
}

import { useCallback, useState } from 'react'

export interface MultiSelectState {
  selected: Set<string>
  toggle: (id: string) => void
  toggleAll: (allIds: string[]) => void
  clear: () => void
  isSelected: (id: string) => boolean
  isAllSelected: (allIds: string[]) => boolean
  count: number
}

export function useMultiSelect(): MultiSelectState {
  const [selected, setSelected] = useState<Set<string>>(new Set())

  const toggle = useCallback((id: string) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }, [])

  const toggleAll = useCallback((allIds: string[]) => {
    setSelected((prev) => {
      const allSelected = allIds.length > 0 && allIds.every((id) => prev.has(id))
      return allSelected ? new Set() : new Set(allIds)
    })
  }, [])

  const clear = useCallback(() => setSelected(new Set()), [])

  const isSelected = useCallback((id: string) => selected.has(id), [selected])

  const isAllSelected = useCallback(
    (allIds: string[]) => allIds.length > 0 && allIds.every((id) => selected.has(id)),
    [selected],
  )

  return { selected, toggle, toggleAll, clear, isSelected, isAllSelected, count: selected.size }
}

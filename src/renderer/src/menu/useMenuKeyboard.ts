import { useCallback, useEffect, useRef, useState } from 'react'
import type { RefObject } from 'react'

export interface NavRow {
  disabled: boolean
  submenuId?: string
}

interface UseMenuKeyboardOptions {
  open: boolean
  panelRef: RefObject<HTMLDivElement | null>
  rows: NavRow[]
  sectionIds: string[]
  activeTab: string
  setActiveTab: (id: string) => void
  openSubmenuId: string | null
  setOpenSubmenuId: (id: string | null) => void
  getSubmenuItemCount: (id: string) => number
  closeMenu: () => void
}

interface UseMenuKeyboardResult {
  focusedIndex: number
  submenuFocusIndex: number | null
  focusRow: (index: number) => void
  focusSubRow: (index: number) => void
  rowRef: (index: number) => (el: HTMLElement | null) => void
  subRowRef: (index: number) => (el: HTMLElement | null) => void
}

/**
 * Keyboard navigation for the menu dropdown panel (WAI-ARIA menu pattern).
 *
 * Roving focus over the active section's non-divider rows with wrap-around,
 * ArrowRight/ArrowLeft to enter/leave submenus, Enter/Space activation via a
 * DOM click on the focused row (so mouse click handlers are reused), Esc to
 * close the submenu then the panel, and Tab/Shift+Tab cycling the section
 * tabs. Tab is always intercepted while the panel is open, which also traps
 * focus inside the panel.
 */
export default function useMenuKeyboard({
  open,
  panelRef,
  rows,
  sectionIds,
  activeTab,
  setActiveTab,
  openSubmenuId,
  setOpenSubmenuId,
  getSubmenuItemCount,
  closeMenu,
}: UseMenuKeyboardOptions): UseMenuKeyboardResult {
  const [focusedIndex, setFocusedIndex] = useState(0)
  const [submenuFocusIndex, setSubmenuFocusIndex] = useState<number | null>(null)
  const rowEls = useRef(new Map<number, HTMLElement>())
  const subEls = useRef(new Map<number, HTMLElement>())

  // rows is rebuilt every render; read it through a ref so effects keyed on
  // open/activeTab don't re-run (or go stale) on unrelated renders.
  const rowsRef = useRef(rows)
  rowsRef.current = rows

  const rowRef = useCallback(
    (index: number) =>
      (el: HTMLElement | null): void => {
        if (el) rowEls.current.set(index, el)
        else rowEls.current.delete(index)
      },
    [],
  )

  const subRowRef = useCallback(
    (index: number) =>
      (el: HTMLElement | null): void => {
        if (el) subEls.current.set(index, el)
        else subEls.current.delete(index)
      },
    [],
  )

  const focusRow = useCallback((index: number): void => {
    setFocusedIndex(index)
  }, [])

  const focusSubRow = useCallback((index: number): void => {
    setSubmenuFocusIndex(index)
  }, [])

  // On open (and on section change while open), focus the first non-disabled
  // row of the active section.
  useEffect(() => {
    if (!open) return
    const first = rowsRef.current.findIndex((r) => !r.disabled)
    setFocusedIndex(first >= 0 ? first : 0)
    setSubmenuFocusIndex(null)
  }, [open, activeTab])

  // Move real DOM focus to the focused row so screen readers track position.
  useEffect(() => {
    if (!open) return
    if (submenuFocusIndex !== null) {
      subEls.current.get(submenuFocusIndex)?.focus()
    } else {
      const el = rowEls.current.get(focusedIndex)
      if (el) el.focus()
      else panelRef.current?.focus()
    }
  }, [open, focusedIndex, submenuFocusIndex, activeTab, openSubmenuId, panelRef])

  useEffect(() => {
    if (!open) return undefined

    const openSubmenu = (id: string): void => {
      setOpenSubmenuId(id)
      setSubmenuFocusIndex(getSubmenuItemCount(id) > 0 ? 0 : null)
    }

    const closeSubmenu = (): void => {
      setOpenSubmenuId(null)
      setSubmenuFocusIndex(null)
    }

    const handleKeyDown = (e: KeyboardEvent): void => {
      const rowList = rowsRef.current
      const inSubmenu = openSubmenuId !== null && submenuFocusIndex !== null
      const subCount = openSubmenuId !== null ? getSubmenuItemCount(openSubmenuId) : 0

      switch (e.key) {
        case 'ArrowDown':
        case 'ArrowUp': {
          e.preventDefault()
          e.stopPropagation()
          const delta = e.key === 'ArrowDown' ? 1 : -1
          if (inSubmenu && subCount > 0) {
            setSubmenuFocusIndex(((submenuFocusIndex + delta) % subCount + subCount) % subCount)
          } else if (rowList.length > 0) {
            setFocusedIndex(((focusedIndex + delta) % rowList.length + rowList.length) % rowList.length)
          }
          break
        }
        case 'ArrowRight': {
          const row = rowList[focusedIndex]
          if (!inSubmenu && row?.submenuId && !row.disabled) {
            e.preventDefault()
            e.stopPropagation()
            openSubmenu(row.submenuId)
          }
          break
        }
        case 'ArrowLeft': {
          if (openSubmenuId !== null) {
            e.preventDefault()
            e.stopPropagation()
            closeSubmenu()
          }
          break
        }
        case 'Enter':
        case ' ': {
          e.preventDefault()
          e.stopPropagation()
          if (inSubmenu) {
            subEls.current.get(submenuFocusIndex)?.click()
          } else {
            const row = rowList[focusedIndex]
            if (!row || row.disabled) break
            if (row.submenuId) openSubmenu(row.submenuId)
            else rowEls.current.get(focusedIndex)?.click()
          }
          break
        }
        case 'Escape': {
          e.preventDefault()
          e.stopPropagation()
          if (openSubmenuId !== null) closeSubmenu()
          else closeMenu()
          break
        }
        case 'Tab': {
          e.preventDefault()
          e.stopPropagation()
          const idx = sectionIds.indexOf(activeTab)
          const next = e.shiftKey
            ? (idx - 1 + sectionIds.length) % sectionIds.length
            : (idx + 1) % sectionIds.length
          closeSubmenu()
          setActiveTab(sectionIds[next])
          break
        }
      }
    }

    window.addEventListener('keydown', handleKeyDown, true)
    return () => window.removeEventListener('keydown', handleKeyDown, true)
  }, [
    open,
    focusedIndex,
    submenuFocusIndex,
    openSubmenuId,
    activeTab,
    sectionIds,
    setActiveTab,
    setOpenSubmenuId,
    getSubmenuItemCount,
    closeMenu,
  ])

  return { focusedIndex, submenuFocusIndex, focusRow, focusSubRow, rowRef, subRowRef }
}

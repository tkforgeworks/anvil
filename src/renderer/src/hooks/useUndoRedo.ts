import { useCallback, useEffect, useRef, useState } from 'react'

const DEBOUNCE_MS = 500

export interface UndoRedoControls<T> {
  pushState: (state: T) => void
  triggerUndo: () => void
  triggerRedo: () => void
  reset: (state: T) => void
  canUndo: boolean
  canRedo: boolean
}

export function useUndoRedo<T>(onRestore: (state: T) => void): UndoRedoControls<T> {
  const pastRef = useRef<T[]>([])
  const futureRef = useRef<T[]>([])
  const currentRef = useRef<T | null>(null)
  const pendingRef = useRef<T | null>(null)
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const onRestoreRef = useRef(onRestore)
  onRestoreRef.current = onRestore

  const [version, setVersion] = useState(0)

  const flushPending = useCallback(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current)
      timerRef.current = null
    }
    if (pendingRef.current !== null && currentRef.current !== null) {
      pastRef.current.push(currentRef.current)
      currentRef.current = pendingRef.current
      futureRef.current = []
      pendingRef.current = null
    }
  }, [])

  const pushState = useCallback((state: T) => {
    const serialized = JSON.stringify(state)
    const compareTo = pendingRef.current ?? currentRef.current
    if (compareTo !== null && JSON.stringify(compareTo) === serialized) return

    pendingRef.current = state

    if (timerRef.current) clearTimeout(timerRef.current)
    timerRef.current = setTimeout(() => {
      flushPending()
      setVersion((v) => v + 1)
      timerRef.current = null
    }, DEBOUNCE_MS)
  }, [flushPending])

  const triggerUndo = useCallback(() => {
    if (pendingRef.current !== null) {
      if (timerRef.current) {
        clearTimeout(timerRef.current)
        timerRef.current = null
      }
      futureRef.current.push(pendingRef.current)
      pendingRef.current = null
      if (currentRef.current !== null) {
        onRestoreRef.current(currentRef.current)
      }
      setVersion((v) => v + 1)
      return
    }

    if (pastRef.current.length === 0) return

    const prev = pastRef.current.pop()!
    if (currentRef.current !== null) futureRef.current.push(currentRef.current)
    currentRef.current = prev
    onRestoreRef.current(prev)
    setVersion((v) => v + 1)
  }, [])

  const triggerRedo = useCallback(() => {
    if (futureRef.current.length === 0) return

    const next = futureRef.current.pop()!
    if (currentRef.current !== null) pastRef.current.push(currentRef.current)
    currentRef.current = next
    onRestoreRef.current(next)
    setVersion((v) => v + 1)
  }, [])

  const reset = useCallback((state: T) => {
    if (timerRef.current) {
      clearTimeout(timerRef.current)
      timerRef.current = null
    }
    pastRef.current = []
    futureRef.current = []
    currentRef.current = state
    pendingRef.current = null
    setVersion((v) => v + 1)
  }, [])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent): void => {
      const mod = e.ctrlKey || e.metaKey
      if (!mod) return

      if (e.key === 'z' && !e.shiftKey) {
        e.preventDefault()
        triggerUndo()
      } else if (e.key === 'y' || (e.key === 'z' && e.shiftKey)) {
        e.preventDefault()
        triggerRedo()
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [triggerUndo, triggerRedo])

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current)
    }
  }, [])

  // version is used to force re-render when stacks change
  void version

  const canUndo = pastRef.current.length > 0 || pendingRef.current !== null
  const canRedo = futureRef.current.length > 0

  return { pushState, triggerUndo, triggerRedo, reset, canUndo, canRedo }
}

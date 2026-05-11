import { useEffect } from 'react'
import { useUiStore } from '../stores/ui.store'
import { SHORTCUTS } from './shortcuts'
import useCommandDispatch from './useCommandDispatch'

interface KeyCombo {
  key: string
  ctrl: boolean
  shift: boolean
  alt: boolean
}

function parseKeys(keys: string): KeyCombo {
  const parts = keys.split('+')
  return {
    ctrl: parts.includes('Ctrl'),
    shift: parts.includes('Shift'),
    alt: parts.includes('Alt'),
    key: parts[parts.length - 1].toLowerCase(),
  }
}

function matchesEvent(combo: KeyCombo, e: KeyboardEvent): boolean {
  const ctrlOrMeta = e.ctrlKey || e.metaKey
  if (combo.ctrl !== ctrlOrMeta) return false
  if (combo.shift !== e.shiftKey) return false
  if (combo.alt !== e.altKey) return false

  const eventKey = e.key.toLowerCase()
  const comboKey = combo.key

  if (comboKey === eventKey) return true
  if (comboKey === '=' && eventKey === '=') return true
  if (comboKey === '-' && eventKey === '-') return true
  if (comboKey === '/' && eventKey === '/') return true
  if (comboKey === ',' && eventKey === ',') return true
  if (/^\d$/.test(comboKey) && eventKey === comboKey) return true
  if (comboKey.startsWith('f') && eventKey === comboKey) return true

  return false
}

const parsedShortcuts = SHORTCUTS.map((s) => ({
  ...s,
  combo: parseKeys(s.keys),
}))

function isInputFocused(): boolean {
  const el = document.activeElement
  if (!el) return false
  const tag = el.tagName.toLowerCase()
  if (tag === 'input' || tag === 'textarea') return true
  if ((el as HTMLElement).isContentEditable) return true
  return false
}

export default function useGlobalShortcuts(): void {
  const dispatch = useCommandDispatch()

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent): void => {
      const { menuOpen, activeModalId } = useUiStore.getState()

      if (menuOpen) return
      if (activeModalId) return

      if (isInputFocused()) {
        const isUndoRedo =
          (e.ctrlKey || e.metaKey) &&
          !e.altKey &&
          (e.key.toLowerCase() === 'z')
        if (!isUndoRedo) {
          for (const s of parsedShortcuts) {
            if (matchesEvent(s.combo, e)) return
          }
        }
        return
      }

      for (const s of parsedShortcuts) {
        if (matchesEvent(s.combo, e)) {
          e.preventDefault()
          e.stopPropagation()
          dispatch(s.command)
          return
        }
      }
    }

    window.addEventListener('keydown', handleKeyDown, true)
    return () => window.removeEventListener('keydown', handleKeyDown, true)
  }, [dispatch])
}

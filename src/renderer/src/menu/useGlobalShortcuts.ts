import { useCallback, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { projectApi } from '../../api/project.api'
import { useProjectStore } from '../stores/project.store'
import { useUiStore } from '../stores/ui.store'
import { MODAL_IDS } from './constants'
import { SHORTCUTS } from './shortcuts'

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
  // Number keys
  if (/^\d$/.test(comboKey) && eventKey === comboKey) return true
  // F-keys
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
  const navigate = useNavigate()
  const activeProject = useProjectStore((s) => s.activeProject)
  const hydrate = useProjectStore((s) => s.hydrate)

  const dispatch = useCallback(
    (command: string) => {
      const menuOpen = useUiStore.getState().menuOpen
      const openModal = useUiStore.getState().openModal
      const toggleSidebar = useUiStore.getState().toggleSidebar
      const project = useProjectStore.getState().activeProject
      const isDirty = useProjectStore.getState().isDirty
      const isRecoveryMode = useProjectStore.getState().isRecoveryMode

      switch (command) {
        // File
        case 'new-project':
          if (project) return
          void projectApi.create({ projectName: '', gameTitle: '', templateId: 'blank' }).catch(() => {})
          break
        case 'open-project':
          void projectApi.open().then((s) => {
            if (s.activeProject) {
              useProjectStore.getState().hydrate(s)
              navigate('/')
            }
          }).catch(() => {})
          break
        case 'save':
          if (!project || !isDirty || isRecoveryMode) return
          useProjectStore.getState().setSaveStatus('saving')
          useProjectStore.getState().setSaveError(null)
          void projectApi.save().then((s) => useProjectStore.getState().hydrate(s)).catch((err) => {
            useProjectStore.getState().setSaveError(err instanceof Error ? err.message : 'Unable to save project.')
          })
          break
        case 'save-as':
          if (!project) return
          void projectApi.saveAs().then((s) => {
            if (s) useProjectStore.getState().hydrate(s)
          }).catch(() => {})
          break
        case 'close-project':
          if (!project) return
          void projectApi.close().then((s) => useProjectStore.getState().hydrate(s)).catch(() => {})
          break
        case 'app-settings':
          openModal(MODAL_IDS.APP_SETTINGS)
          break
        case 'exit':
          void window.anvil.invoke('window:close')
          break

        // View
        case 'toggle-sidebar':
          if (!project) return
          toggleSidebar()
          break
        case 'validation-panel':
          if (!project) return
          navigate('/validation')
          break
        case 'zoom-in':
        case 'zoom-out':
        case 'zoom-reset':
          // Wired in ANV-120
          break

        // Project
        case 'project-settings':
          if (!project) return
          openModal(MODAL_IDS.PROJECT_SETTINGS)
          break
        case 'custom-field-schemas':
          if (!project) return
          openModal(MODAL_IDS.PROJECT_SETTINGS, { initialTab: 'custom-fields' })
          break
        case 'run-validation':
          if (!project) return
          void window.anvil.invoke('validation:run')
          break
        case 'export':
          if (!project) return
          navigate('/export')
          break

        // Navigation
        case 'nav-dashboard':
          if (!project) return
          navigate('/')
          break
        case 'nav-classes':
          if (!project) return
          navigate('/classes')
          break
        case 'nav-abilities':
          if (!project) return
          navigate('/abilities')
          break
        case 'nav-items':
          if (!project) return
          navigate('/items')
          break
        case 'nav-recipes':
          if (!project) return
          navigate('/recipes')
          break
        case 'nav-npcs':
          if (!project) return
          navigate('/npcs')
          break
        case 'nav-loot-tables':
          if (!project) return
          navigate('/loot-tables')
          break

        // Help
        case 'keyboard-shortcuts':
          openModal(MODAL_IDS.SHORTCUTS)
          break
        case 'documentation':
          // Wired in ANV-122 (shell.openExternal)
          break
      }
    },
    [navigate],
  )

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent): void => {
      const { menuOpen, activeModalId } = useUiStore.getState()

      if (menuOpen) return
      if (activeModalId) return

      // Allow undo/redo in inputs, but suppress everything else
      if (isInputFocused()) {
        const isUndoRedo =
          (e.ctrlKey || e.metaKey) &&
          !e.altKey &&
          (e.key.toLowerCase() === 'z')
        if (!isUndoRedo) {
          // Only suppress if the shortcut matches one of ours
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

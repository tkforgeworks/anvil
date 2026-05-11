import { useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { projectApi } from '../../api/project.api'
import { settingsApi } from '../../api/settings.api'
import { useProjectStore } from '../stores/project.store'
import { useSettingsStore } from '../stores/settings.store'
import { useUiStore, type AppTheme } from '../stores/ui.store'
import { MODAL_IDS } from './constants'

export default function useCommandDispatch(): (command: string) => void {
  const navigate = useNavigate()

  return useCallback(
    (command: string) => {
      const openModal = useUiStore.getState().openModal
      const toggleSidebar = useUiStore.getState().toggleSidebar
      const project = useProjectStore.getState().activeProject
      const isDirty = useProjectStore.getState().isDirty
      const isRecoveryMode = useProjectStore.getState().isRecoveryMode

      switch (command) {
        // File
        case 'new-project':
          if (project) return
          void projectApi
            .create({ projectName: '', gameTitle: '', templateId: 'blank' })
            .catch(() => {})
          break
        case 'open-project':
          void projectApi
            .open()
            .then((s) => {
              if (s.activeProject) {
                useProjectStore.getState().hydrate(s)
                navigate('/')
              }
            })
            .catch(() => {})
          break
        case 'save':
          if (!project || !isDirty || isRecoveryMode) return
          useProjectStore.getState().setSaveStatus('saving')
          useProjectStore.getState().setSaveError(null)
          void projectApi
            .save()
            .then((s) => useProjectStore.getState().hydrate(s))
            .catch((err) => {
              useProjectStore
                .getState()
                .setSaveError(err instanceof Error ? err.message : 'Unable to save project.')
            })
          break
        case 'save-as':
          if (!project) return
          void projectApi
            .saveAs()
            .then((s) => {
              if (s) useProjectStore.getState().hydrate(s)
            })
            .catch(() => {})
          break
        case 'close-project':
          if (!project) return
          void projectApi
            .close()
            .then((s) => useProjectStore.getState().hydrate(s))
            .catch(() => {})
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
          window.anvil.zoomIn()
          break
        case 'zoom-out':
          window.anvil.zoomOut()
          break
        case 'zoom-reset':
          window.anvil.resetZoom()
          break
        case 'theme-dark':
        case 'theme-light':
        case 'theme-custom': {
          const theme = command.replace('theme-', '') as AppTheme
          void settingsApi.setApp({ theme }).then((s) => {
            useSettingsStore.getState().setAppSettings(s)
          })
          break
        }

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
          void window.anvil.invoke('shell:open-external', 'https://anvil.tkforgeworks.com/docs')
          break
        case 'report-bug':
          void window.anvil.invoke('shell:open-external', 'https://anvil.tkforgeworks.com/bugs')
          break
        case 'about':
          openModal(MODAL_IDS.ABOUT)
          break
      }
    },
    [navigate],
  )
}

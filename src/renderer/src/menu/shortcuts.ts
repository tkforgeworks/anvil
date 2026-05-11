import type { ShortcutEntry } from './types'

export const SHORTCUTS: ShortcutEntry[] = [
  // File
  { id: 'new-project', label: 'New Project…', keys: 'Ctrl+N', group: 'File', command: 'new-project' },
  { id: 'open-project', label: 'Open Project…', keys: 'Ctrl+O', group: 'File', command: 'open-project' },
  { id: 'save', label: 'Save', keys: 'Ctrl+S', group: 'File', command: 'save' },
  { id: 'save-as', label: 'Save As…', keys: 'Ctrl+Shift+S', group: 'File', command: 'save-as' },
  { id: 'close-project', label: 'Close Project', keys: 'Ctrl+W', group: 'File', command: 'close-project' },

  // Navigation
  { id: 'nav-dashboard', label: 'Dashboard', keys: 'Ctrl+1', group: 'Navigation', command: 'nav-dashboard' },
  { id: 'nav-classes', label: 'Classes', keys: 'Ctrl+2', group: 'Navigation', command: 'nav-classes' },
  { id: 'nav-abilities', label: 'Abilities', keys: 'Ctrl+3', group: 'Navigation', command: 'nav-abilities' },
  { id: 'nav-items', label: 'Items', keys: 'Ctrl+4', group: 'Navigation', command: 'nav-items' },
  { id: 'nav-recipes', label: 'Recipes', keys: 'Ctrl+5', group: 'Navigation', command: 'nav-recipes' },
  { id: 'nav-npcs', label: 'NPCs', keys: 'Ctrl+6', group: 'Navigation', command: 'nav-npcs' },
  { id: 'nav-loot-tables', label: 'Loot Tables', keys: 'Ctrl+7', group: 'Navigation', command: 'nav-loot-tables' },

  // Editing
  { id: 'undo', label: 'Undo', keys: 'Ctrl+Z', group: 'Editing', command: 'undo' },
  { id: 'redo', label: 'Redo', keys: 'Ctrl+Shift+Z', group: 'Editing', command: 'redo' },

  // View
  { id: 'toggle-sidebar', label: 'Toggle Sidebar', keys: 'Ctrl+B', group: 'View', command: 'toggle-sidebar' },
  { id: 'validation-panel', label: 'Validation Panel', keys: 'Ctrl+Shift+V', group: 'View', command: 'validation-panel' },
  { id: 'zoom-in', label: 'Zoom In', keys: 'Ctrl+=', group: 'View', command: 'zoom-in' },
  { id: 'zoom-out', label: 'Zoom Out', keys: 'Ctrl+-', group: 'View', command: 'zoom-out' },
  { id: 'zoom-reset', label: 'Reset Zoom', keys: 'Ctrl+0', group: 'View', command: 'zoom-reset' },

  // Project
  { id: 'project-settings', label: 'Project Settings', keys: 'Ctrl+,', group: 'Project', command: 'project-settings' },
  { id: 'export', label: 'Export…', keys: 'Ctrl+E', group: 'Project', command: 'export' },

  // Help
  { id: 'documentation', label: 'Documentation', keys: 'F1', group: 'Help', command: 'documentation' },
  { id: 'keyboard-shortcuts', label: 'Keyboard Shortcuts', keys: 'Ctrl+/', group: 'Help', command: 'keyboard-shortcuts' },
]

const shortcutMap = new Map(SHORTCUTS.map((s) => [s.id, s]))

export function getShortcutKeys(id: string): string | undefined {
  return shortcutMap.get(id)?.keys
}

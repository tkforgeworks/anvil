import { MODAL_IDS } from './constants'
import { getEffectiveShortcutKeys } from './shortcuts'
import { useSettingsStore } from '../stores/settings.store'
import type { MenuItem, MenuSection } from './types'

function item(
  id: string,
  icon: string,
  label: string,
  command: string,
  opts?: Partial<MenuItem>,
): MenuItem {
  return {
    kind: 'item',
    id,
    icon,
    label,
    shortcutId: id,
    command,
    ...opts,
  }
}

function divider(): MenuItem {
  return { kind: 'divider' }
}

export const MENU_DATA: MenuSection[] = [
  {
    id: 'file',
    label: 'File',
    items: [
      item('new-project', 'add', 'New Project…', 'new-project'),
      item('open-project', 'folder', 'Open Project…', 'open-project'),
      {
        kind: 'submenu',
        id: 'open-recent',
        icon: 'history',
        label: 'Open Recent',
        command: 'open-recent',
      },
      divider(),
      item('save', 'save', 'Save', 'save'),
      item('save-as', 'save_as', 'Save As…', 'save-as'),
      divider(),
      item('close-project', 'close', 'Close Project', 'close-project'),
      divider(),
      {
        kind: 'item',
        id: 'app-settings',
        icon: 'settings',
        label: 'Application Settings…',
        command: 'app-settings',
      },
      divider(),
      {
        kind: 'item',
        id: 'exit',
        icon: 'exit',
        label: 'Exit',
        shortcutId: undefined,
        command: 'exit',
        danger: true,
      },
    ],
  },
  {
    id: 'view',
    label: 'View',
    items: [
      item('toggle-sidebar', 'sidebar', 'Toggle Sidebar', 'toggle-sidebar'),
      item('validation-panel', 'validation', 'Validation Panel', 'validation-panel'),
      divider(),
      item('zoom-in', 'zoom_in', 'Zoom In', 'zoom-in'),
      item('zoom-out', 'zoom_out', 'Zoom Out', 'zoom-out'),
      item('zoom-reset', 'zoom_reset', 'Reset Zoom', 'zoom-reset'),
      divider(),
      {
        kind: 'submenu',
        id: 'theme-menu',
        icon: 'theme',
        label: 'Theme',
        command: 'theme-menu',
        children: [
          { kind: 'item', id: 'theme-dark', label: 'Dark', command: 'theme-dark' },
          { kind: 'item', id: 'theme-light', label: 'Light', command: 'theme-light' },
          { kind: 'item', id: 'theme-custom', label: 'Custom', command: 'theme-custom' },
        ],
      },
    ],
  },
  {
    id: 'project',
    label: 'Project',
    items: [
      item('project-settings', 'settings', 'Project Settings', 'project-settings'),
      {
        kind: 'item',
        id: 'run-validation',
        icon: 'validation',
        label: 'Run Validation',
        command: 'run-validation',
      },
      {
        kind: 'item',
        id: 'custom-field-schemas',
        icon: 'fields',
        label: 'Custom Field Schemas',
        command: 'custom-field-schemas',
      },
      divider(),
      item('export', 'upload', 'Export…', 'export'),
      {
        kind: 'item',
        id: 'import',
        icon: 'download',
        label: 'Import…',
        command: 'import',
        disabled: true,
        tooltip: 'Coming soon',
      },
    ],
  },
  {
    id: 'data',
    label: 'Data',
    items: [
      item('nav-dashboard', 'dashboard', 'Dashboard', 'nav-dashboard'),
      divider(),
      item('nav-classes', 'groups', 'Classes', 'nav-classes'),
      item('nav-abilities', 'sparkle', 'Abilities', 'nav-abilities'),
      item('nav-items', 'inventory', 'Items', 'nav-items'),
      item('nav-recipes', 'build', 'Recipes', 'nav-recipes'),
      item('nav-npcs', 'face', 'NPCs', 'nav-npcs'),
      item('nav-loot-tables', 'grid', 'Loot Tables', 'nav-loot-tables'),
    ],
  },
  {
    id: 'help',
    label: 'Help',
    items: [
      item('documentation', 'docs', 'Documentation', 'documentation'),
      item('keyboard-shortcuts', 'shortcuts', 'Keyboard Shortcuts', 'keyboard-shortcuts'),
      divider(),
      {
        kind: 'item',
        id: 'report-bug',
        icon: 'bug',
        label: 'Report a Bug',
        command: 'report-bug',
      },
      {
        kind: 'item',
        id: 'about',
        icon: 'about',
        label: 'About Anvil',
        command: 'about',
      },
    ],
  },
]

export function resolveShortcut(item: MenuItem): string | undefined {
  if (item.shortcutId) {
    const custom = useSettingsStore.getState().appSettings?.customShortcuts ?? null
    return getEffectiveShortcutKeys(item.shortcutId, custom)
  }
  return undefined
}

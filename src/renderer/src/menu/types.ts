export interface ShortcutEntry {
  id: string
  label: string
  keys: string
  group: 'File' | 'Navigation' | 'Editing' | 'View' | 'Project' | 'Help'
  command: string
}

export type MenuItemKind = 'item' | 'submenu' | 'divider'

export interface MenuItem {
  kind: MenuItemKind
  id?: string
  icon?: string
  label?: string
  shortcutId?: string
  meta?: string | (() => string)
  sub?: string
  disabled?: boolean | (() => boolean)
  checked?: boolean | (() => boolean)
  danger?: boolean
  tooltip?: string
  children?: MenuItem[]
  command?: string
}

export interface MenuSection {
  id: string
  label: string
  items: MenuItem[]
}

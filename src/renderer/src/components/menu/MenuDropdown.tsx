import { Box } from '@mui/material'
import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { MENU_DATA, resolveShortcut } from '../../menu/menu-data'
import type { MenuItem } from '../../menu/types'
import useCommandDispatch from '../../menu/useCommandDispatch'
import { useProjectStore } from '../../stores/project.store'
import { useSettingsStore } from '../../stores/settings.store'
import { useUiStore } from '../../stores/ui.store'
import MenuRow from './MenuRow'
import RecentSubmenu from './RecentSubmenu'

const KEEP_OPEN = new Set([
  'zoom-in',
  'zoom-out',
  'zoom-reset',
  'toggle-sidebar',
  'theme-dark',
  'theme-light',
  'theme-custom',
])

const PROJECT_REQUIRED = new Set([
  'save-as',
  'close-project',
  'toggle-sidebar',
  'validation-panel',
  'zoom-in',
  'zoom-out',
  'zoom-reset',
  'project-settings',
  'custom-field-schemas',
  'run-validation',
  'export',
  'nav-dashboard',
  'nav-classes',
  'nav-abilities',
  'nav-items',
  'nav-recipes',
  'nav-npcs',
  'nav-loot-tables',
])

const RECORD_COUNT_MAP: Record<string, keyof NonNullable<ReturnType<typeof useProjectStore.getState>['activeProject']>['recordCounts']> = {
  'nav-classes': 'classes',
  'nav-abilities': 'abilities',
  'nav-items': 'items',
  'nav-recipes': 'recipes',
  'nav-npcs': 'npcs',
  'nav-loot-tables': 'lootTables',
}

function resolveDisabled(
  item: MenuItem,
  hasProject: boolean,
  isDirty: boolean,
  isRecoveryMode: boolean,
  hasCustomTheme: boolean,
): boolean {
  if (item.disabled === true) return true
  if (!item.command) return false
  if (item.command === 'new-project') return hasProject
  if (item.command === 'save') return !hasProject || !isDirty || isRecoveryMode
  if (item.command === 'theme-custom') return !hasCustomTheme
  if (PROJECT_REQUIRED.has(item.command)) return !hasProject
  return false
}

function resolveChecked(item: MenuItem, sidebarOpen: boolean, currentTheme: string): boolean {
  if (item.command === 'toggle-sidebar') return sidebarOpen
  if (item.command === 'theme-dark') return currentTheme === 'dark'
  if (item.command === 'theme-light') return currentTheme === 'light'
  if (item.command === 'theme-custom') return currentTheme === 'custom'
  return false
}

export default function MenuDropdown(): React.JSX.Element | null {
  const menuOpen = useUiStore((s) => s.menuOpen)
  const setMenuOpen = useUiStore((s) => s.setMenuOpen)
  const sidebarOpen = useUiStore((s) => s.sidebarOpen)
  const theme = useUiStore((s) => s.theme)
  const activeProject = useProjectStore((s) => s.activeProject)
  const isDirty = useProjectStore((s) => s.isDirty)
  const isRecoveryMode = useProjectStore((s) => s.isRecoveryMode)
  const appSettings = useSettingsStore((s) => s.appSettings)
  const dispatch = useCommandDispatch()
  const [activeTab, setActiveTab] = useState('file')
  const [hoveredSubmenu, setHoveredSubmenu] = useState<string | null>(null)
  const submenuTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (!menuOpen) return undefined
    const handleEsc = (e: KeyboardEvent): void => {
      if (e.key === 'Escape') {
        e.preventDefault()
        e.stopPropagation()
        setMenuOpen(false)
      }
    }
    window.addEventListener('keydown', handleEsc)
    return () => window.removeEventListener('keydown', handleEsc)
  }, [menuOpen, setMenuOpen])

  useEffect(() => {
    if (!menuOpen) {
      setHoveredSubmenu(null)
      setActiveTab('file')
    }
  }, [menuOpen])

  if (!menuOpen) return null

  const hasProject = !!activeProject
  const hasCustomTheme = !!appSettings?.customThemePath
  const activeSection = MENU_DATA.find((s) => s.id === activeTab) ?? MENU_DATA[0]

  const handleItemClick = (item: MenuItem): void => {
    if (!item.command) return
    if (item.kind === 'submenu') return
    if (resolveDisabled(item, hasProject, isDirty, isRecoveryMode, hasCustomTheme)) return
    if (!KEEP_OPEN.has(item.command)) setMenuOpen(false)
    dispatch(item.command)
  }

  const handleSubmenuEnter = (id: string | undefined): void => {
    if (submenuTimerRef.current) clearTimeout(submenuTimerRef.current)
    if (id) {
      submenuTimerRef.current = setTimeout(() => setHoveredSubmenu(id), 150)
    }
  }

  const handleSubmenuLeave = (): void => {
    if (submenuTimerRef.current) clearTimeout(submenuTimerRef.current)
    submenuTimerRef.current = setTimeout(() => setHoveredSubmenu(null), 150)
  }

  const resolveMeta = (item: MenuItem): string | undefined => {
    if (!item.command || !activeProject) return undefined
    const countKey = RECORD_COUNT_MAP[item.command]
    if (countKey) {
      const count = activeProject.recordCounts[countKey]
      return count > 0 ? String(count) : undefined
    }
    return undefined
  }

  return createPortal(
    <>
      <Box
        onClick={() => setMenuOpen(false)}
        sx={{ position: 'fixed', inset: 0, zIndex: 1300 }}
      />
      <Box
        role="menu"
        sx={{
          position: 'fixed',
          top: 48,
          left: 8,
          bgcolor: '#14203a',
          border: '1px solid #2a3553',
          borderRadius: '8px',
          boxShadow: '0 18px 40px rgba(0,0,0,0.55), 0 2px 6px rgba(0,0,0,0.4)',
          width: 320,
          pt: '4px',
          pb: '6px',
          zIndex: 1301,
          WebkitAppRegion: 'no-drag',
        }}
      >
        <Box
          sx={{
            display: 'flex',
            borderBottom: '1px solid #233048',
            px: '6px',
            pt: '4px',
            mb: '4px',
          }}
        >
          {MENU_DATA.map((section) => (
            <Box
              key={section.id}
              onClick={() => setActiveTab(section.id)}
              sx={{
                fontFamily: '"Poppins", sans-serif',
                fontSize: '11px',
                letterSpacing: '0.06em',
                textTransform: 'uppercase',
                fontWeight: 600,
                color: section.id === activeTab ? '#3b82f6' : '#5d6a85',
                borderBottom:
                  section.id === activeTab
                    ? '2px solid #3b82f6'
                    : '2px solid transparent',
                px: '10px',
                py: '8px',
                cursor: 'pointer',
                userSelect: 'none',
                '&:hover': {
                  color: section.id === activeTab ? '#3b82f6' : '#e2e8f0',
                },
              }}
            >
              {section.label}
            </Box>
          ))}
        </Box>

        <Box sx={{ px: '4px', py: '2px' }}>
          {activeSection.items.map((item, i) => {
            const isSubmenu = item.kind === 'submenu'
            const shortcut = resolveShortcut(item)
            const disabled = resolveDisabled(item, hasProject, isDirty, isRecoveryMode, hasCustomTheme)
            const checked = resolveChecked(item, sidebarOpen, theme)
            const meta = resolveMeta(item)

            if (isSubmenu && item.children) {
              return (
                <Box
                  key={item.id ?? `sub-${i}`}
                  onMouseEnter={() => handleSubmenuEnter(item.id)}
                  onMouseLeave={handleSubmenuLeave}
                >
                  <MenuRow
                    item={{
                      kind: 'submenu',
                      icon: item.icon,
                      label: item.label,
                      disabled,
                    }}
                    hovered={hoveredSubmenu === item.id}
                  />
                  {hoveredSubmenu === item.id && item.children.map((child, ci) => (
                    <MenuRow
                      key={child.id ?? `child-${ci}`}
                      item={{
                        kind: child.kind ?? 'item',
                        label: child.label,
                        checked: resolveChecked(child, sidebarOpen, theme),
                        disabled: resolveDisabled(child, hasProject, isDirty, isRecoveryMode, hasCustomTheme),
                      }}
                      onClick={() => {
                        if (child.command) {
                          if (!KEEP_OPEN.has(child.command)) setMenuOpen(false)
                          dispatch(child.command)
                        }
                      }}
                    />
                  ))}
                </Box>
              )
            }

            if (isSubmenu && item.id === 'open-recent') {
              return (
                <Box
                  key={item.id}
                  onMouseEnter={() => handleSubmenuEnter(item.id)}
                  onMouseLeave={handleSubmenuLeave}
                >
                  <MenuRow
                    item={{
                      kind: 'submenu',
                      icon: item.icon,
                      label: item.label,
                    }}
                    hovered={hoveredSubmenu === 'open-recent'}
                  />
                  {hoveredSubmenu === 'open-recent' && <RecentSubmenu />}
                </Box>
              )
            }

            return (
              <MenuRow
                key={item.id ?? `div-${i}`}
                item={{
                  kind: item.kind,
                  icon: item.icon,
                  label: item.label,
                  shortcut,
                  sub: item.sub,
                  meta,
                  disabled,
                  checked,
                  danger: item.danger,
                  tooltip: item.tooltip,
                }}
                onClick={() => handleItemClick(item)}
              />
            )
          })}
        </Box>
      </Box>
    </>,
    document.body,
  )
}

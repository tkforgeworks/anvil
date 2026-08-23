import { Box } from '@mui/material'
import { useCallback, useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { MENU_DATA, resolveShortcut } from '../../menu/menu-data'
import type { MenuItem } from '../../menu/types'
import useCommandDispatch from '../../menu/useCommandDispatch'
import useMenuKeyboard from '../../menu/useMenuKeyboard'
import type { NavRow } from '../../menu/useMenuKeyboard'
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

const CHECKABLE = new Set(['toggle-sidebar', 'theme-dark', 'theme-light', 'theme-custom'])

const SECTION_IDS = MENU_DATA.map((s) => s.id)

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
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!menuOpen) {
      setHoveredSubmenu(null)
      setActiveTab('file')
    }
  }, [menuOpen])

  const hasProject = !!activeProject
  const hasCustomTheme = !!appSettings?.customThemePath
  const activeSection = MENU_DATA.find((s) => s.id === activeTab) ?? MENU_DATA[0]

  let navCounter = -1
  const renderItems = activeSection.items.map((item) => ({
    item,
    navIndex: item.kind === 'divider' ? null : ++navCounter,
  }))
  const navRows: NavRow[] = renderItems
    .filter((r) => r.navIndex !== null)
    .map(({ item }) => ({
      disabled: resolveDisabled(item, hasProject, isDirty, isRecoveryMode, hasCustomTheme),
      submenuId: item.kind === 'submenu' ? item.id : undefined,
    }))

  const getSubmenuItemCount = useCallback((id: string): number => {
    if (id === 'open-recent') {
      const recents = useProjectStore.getState().recentProjects
      // Recent rows plus the trailing "Clear Recents" row.
      return recents.length === 0 ? 0 : recents.length + 1
    }
    for (const section of MENU_DATA) {
      const found = section.items.find((it) => it.id === id)
      if (found?.children) return found.children.length
    }
    return 0
  }, [])

  const closeMenu = useCallback((): void => setMenuOpen(false), [setMenuOpen])

  const { focusedIndex, submenuFocusIndex, focusRow, focusSubRow, rowRef, subRowRef } =
    useMenuKeyboard({
      open: menuOpen,
      panelRef,
      rows: navRows,
      sectionIds: SECTION_IDS,
      activeTab,
      setActiveTab,
      openSubmenuId: hoveredSubmenu,
      setOpenSubmenuId: setHoveredSubmenu,
      getSubmenuItemCount,
      closeMenu,
    })

  if (!menuOpen) return null

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
        ref={panelRef}
        tabIndex={-1}
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
          outline: 'none',
          WebkitAppRegion: 'no-drag',
        }}
      >
        <Box
          role="menubar"
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
              role="menuitem"
              tabIndex={-1}
              onClick={() => {
                setHoveredSubmenu(null)
                setActiveTab(section.id)
              }}
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

        <Box role="menu" sx={{ px: '4px', py: '2px' }}>
          {renderItems.map(({ item, navIndex }, i) => {
            const isSubmenu = item.kind === 'submenu'
            const shortcut = resolveShortcut(item)
            const disabled = resolveDisabled(item, hasProject, isDirty, isRecoveryMode, hasCustomTheme)
            const checked = resolveChecked(item, sidebarOpen, theme)
            const meta = resolveMeta(item)
            const focused = navIndex !== null && focusedIndex === navIndex

            if (isSubmenu && item.children) {
              return (
                <Box
                  key={item.id ?? `sub-${i}`}
                  onMouseEnter={() => {
                    handleSubmenuEnter(item.id)
                    if (navIndex !== null) focusRow(navIndex)
                  }}
                  onMouseLeave={handleSubmenuLeave}
                >
                  <MenuRow
                    ref={navIndex !== null ? rowRef(navIndex) : undefined}
                    role="menuitem"
                    aria-haspopup="menu"
                    aria-expanded={hoveredSubmenu === item.id}
                    tabIndex={focused ? 0 : -1}
                    item={{
                      kind: 'submenu',
                      icon: item.icon,
                      label: item.label,
                      disabled,
                    }}
                    hovered={hoveredSubmenu === item.id || focused}
                  />
                  {hoveredSubmenu === item.id && (
                    <Box role="menu">
                      {item.children.map((child, ci) => {
                        const childCheckable = !!child.command && CHECKABLE.has(child.command)
                        return (
                          <MenuRow
                            key={child.id ?? `child-${ci}`}
                            ref={subRowRef(ci)}
                            role={childCheckable ? 'menuitemcheckbox' : 'menuitem'}
                            aria-checked={childCheckable ? resolveChecked(child, sidebarOpen, theme) : undefined}
                            tabIndex={submenuFocusIndex === ci ? 0 : -1}
                            hovered={submenuFocusIndex === ci}
                            onMouseEnter={() => focusSubRow(ci)}
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
                        )
                      })}
                    </Box>
                  )}
                </Box>
              )
            }

            if (isSubmenu && item.id === 'open-recent') {
              return (
                <Box
                  key={item.id}
                  onMouseEnter={() => {
                    handleSubmenuEnter(item.id)
                    if (navIndex !== null) focusRow(navIndex)
                  }}
                  onMouseLeave={handleSubmenuLeave}
                  sx={{ position: 'relative' }}
                >
                  <MenuRow
                    ref={navIndex !== null ? rowRef(navIndex) : undefined}
                    role="menuitem"
                    aria-haspopup="menu"
                    aria-expanded={hoveredSubmenu === 'open-recent'}
                    tabIndex={focused ? 0 : -1}
                    item={{
                      kind: 'submenu',
                      icon: item.icon,
                      label: item.label,
                    }}
                    hovered={hoveredSubmenu === 'open-recent' || focused}
                  />
                  {hoveredSubmenu === 'open-recent' && (
                    <RecentSubmenu focusedIndex={submenuFocusIndex} rowRef={subRowRef} />
                  )}
                </Box>
              )
            }

            return (
              <MenuRow
                key={item.id ?? `div-${i}`}
                ref={navIndex !== null ? rowRef(navIndex) : undefined}
                role={item.command && CHECKABLE.has(item.command) ? 'menuitemcheckbox' : 'menuitem'}
                aria-checked={item.command && CHECKABLE.has(item.command) ? checked : undefined}
                tabIndex={focused ? 0 : -1}
                hovered={focused}
                onMouseEnter={navIndex !== null ? () => focusRow(navIndex) : undefined}
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

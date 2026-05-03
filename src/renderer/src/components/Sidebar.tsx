import {
  Box,
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Divider,
  Typography,
  Tooltip,
  IconButton,
} from '@mui/material'
import {
  Dashboard as DashboardIcon,
  People as ClassesIcon,
  AutoAwesome as AbilitiesIcon,
  Inventory as ItemsIcon,
  Construction as RecipesIcon,
  SmartToy as NpcsIcon,
  Casino as LootIcon,
  CheckCircle as ValidationIcon,
  Delete as RecycleBinIcon,
  FileUpload as ExportIcon,
  Settings as SettingsIcon,
  ChevronLeft as CollapseIcon,
  ChevronRight as ExpandIcon,
} from '@mui/icons-material'
import { NavLink } from 'react-router-dom'
import type { RecordCounts } from '../../../shared/project-types'
import { useLifecycleStore } from '../stores/lifecycle.store'
import { useProjectStore } from '../stores/project.store'
import { useValidationStore } from '../stores/validation.store'
import { useUiStore } from '../stores/ui.store'

const DRAWER_WIDTH_EXPANDED = 220
const DRAWER_WIDTH_COLLAPSED = 56
const TRANSITION_DURATION = '200ms'

interface NavItem {
  label: string
  to: string
  icon: React.ReactNode
  badge?: number
  badgeColor?: string
  countKey?: keyof RecordCounts
  tid?: string
}

const DOMAIN_NAV: NavItem[] = [
  { label: 'Classes', to: '/classes', icon: <ClassesIcon fontSize="small" />, countKey: 'classes', tid: 'nav-classes' },
  { label: 'Abilities', to: '/abilities', icon: <AbilitiesIcon fontSize="small" />, countKey: 'abilities', tid: 'nav-abilities' },
  { label: 'Items', to: '/items', icon: <ItemsIcon fontSize="small" />, countKey: 'items', tid: 'nav-items' },
  { label: 'Recipes', to: '/recipes', icon: <RecipesIcon fontSize="small" />, countKey: 'recipes', tid: 'nav-recipes' },
  { label: 'NPCs', to: '/npcs', icon: <NpcsIcon fontSize="small" />, countKey: 'npcs', tid: 'nav-npcs' },
  { label: 'Loot Tables', to: '/loot-tables', icon: <LootIcon fontSize="small" />, countKey: 'lootTables', tid: 'nav-loot-tables' },
]

function NavListItem({
  item,
  count,
  collapsed,
}: {
  item: NavItem
  count?: number
  collapsed: boolean
}): React.JSX.Element {
  const button = (
    <ListItemButton
      component={NavLink}
      to={item.to}
      data-tid={item.tid}
      sx={{
        borderRadius: 1,
        mx: 0.5,
        justifyContent: collapsed ? 'center' : 'flex-start',
        px: collapsed ? 1 : undefined,
        '&.active': {
          bgcolor: 'action.selected',
          '& .MuiListItemIcon-root': { color: 'primary.main' },
          '& .MuiListItemText-primary': { color: 'primary.main', fontWeight: 600 },
        },
      }}
    >
      <ListItemIcon
        sx={{
          minWidth: collapsed ? 0 : 36,
          justifyContent: 'center',
          position: 'relative',
        }}
      >
        {item.icon}
        {collapsed && item.badge != null && item.badge > 0 && (
          <Box
            sx={{
              position: 'absolute',
              top: -2,
              right: -4,
              width: 8,
              height: 8,
              borderRadius: '50%',
              bgcolor: item.badgeColor ?? 'error.main',
            }}
          />
        )}
      </ListItemIcon>
      {!collapsed && (
        <>
          <ListItemText
            primary={item.label}
            primaryTypographyProps={{ fontSize: '0.875rem' }}
          />
          {count != null && (
            <Typography
              sx={{ fontSize: '0.7rem', fontWeight: 500, color: 'text.secondary', ml: 1 }}
            >
              {count}
            </Typography>
          )}
          {item.badge != null && item.badge > 0 && (
            <Box
              sx={{
                bgcolor: item.badgeColor ?? 'error.main',
                color: 'common.white',
                borderRadius: '10px',
                minWidth: 20,
                height: 20,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                px: 0.5,
                ml: 1,
              }}
            >
              <Typography sx={{ fontSize: '0.7rem', fontWeight: 700, lineHeight: 1 }}>
                {item.badge > 99 ? '99+' : item.badge}
              </Typography>
            </Box>
          )}
        </>
      )}
    </ListItemButton>
  )

  if (collapsed) {
    return (
      <ListItem disablePadding>
        <Tooltip title={item.label} placement="right" arrow>
          {button}
        </Tooltip>
      </ListItem>
    )
  }

  return <ListItem disablePadding>{button}</ListItem>
}

export default function Sidebar(): React.JSX.Element {
  const recordCounts = useProjectStore((s) => s.activeProject?.recordCounts)
  const issueCount = useValidationStore((s) => s.issues.filter((i) => i.severity === 'error' || i.severity === 'warning').length)
  const hasErrors = useValidationStore((s) => s.issues.some((i) => i.severity === 'error'))
  const trashCount = useLifecycleStore((s) => s.trashCount)
  const sidebarOpen = useUiStore((s) => s.sidebarOpen)
  const toggleSidebar = useUiStore((s) => s.toggleSidebar)

  const collapsed = !sidebarOpen
  const drawerWidth = collapsed ? DRAWER_WIDTH_COLLAPSED : DRAWER_WIDTH_EXPANDED

  const utilityNav: NavItem[] = [
    { label: 'Validation', to: '/validation', icon: <ValidationIcon fontSize="small" />, badge: issueCount, badgeColor: hasErrors ? 'error.main' : 'warning.main', tid: 'nav-validation' },
    { label: 'Recycle Bin', to: '/recycle-bin', icon: <RecycleBinIcon fontSize="small" />, badge: trashCount, badgeColor: 'text.secondary', tid: 'nav-recycle-bin' },
    { label: 'Export', to: '/export', icon: <ExportIcon fontSize="small" />, tid: 'nav-export' },
    { label: 'Settings', to: '/settings', icon: <SettingsIcon fontSize="small" />, tid: 'nav-settings' },
  ]

  const dashboardButton = (
    <ListItemButton
      component={NavLink}
      to="/"
      end
      data-tid="nav-dashboard"
      sx={{
        borderRadius: 1,
        mx: 0.5,
        justifyContent: collapsed ? 'center' : 'flex-start',
        px: collapsed ? 1 : undefined,
        '&.active': {
          bgcolor: 'action.selected',
          '& .MuiListItemIcon-root': { color: 'primary.main' },
          '& .MuiListItemText-primary': { color: 'primary.main', fontWeight: 600 },
        },
      }}
    >
      <ListItemIcon sx={{ minWidth: collapsed ? 0 : 36, justifyContent: 'center' }}>
        <DashboardIcon fontSize="small" />
      </ListItemIcon>
      {!collapsed && (
        <ListItemText
          primary="Dashboard"
          primaryTypographyProps={{ fontSize: '0.875rem' }}
        />
      )}
    </ListItemButton>
  )

  return (
    <Drawer
      variant="permanent"
      sx={{
        width: drawerWidth,
        flexShrink: 0,
        transition: `width ${TRANSITION_DURATION} ease`,
        '& .MuiDrawer-paper': {
          width: drawerWidth,
          boxSizing: 'border-box',
          position: 'relative',
          border: 'none',
          borderRight: 1,
          borderColor: 'divider',
          transition: `width ${TRANSITION_DURATION} ease`,
          overflowX: 'hidden',
          display: 'flex',
          flexDirection: 'column',
        },
      }}
    >
      <List dense>
        <ListItem disablePadding>
          {collapsed ? (
            <Tooltip title="Dashboard" placement="right" arrow>
              {dashboardButton}
            </Tooltip>
          ) : (
            dashboardButton
          )}
        </ListItem>
      </List>

      <Divider sx={{ my: 0.5 }} />

      <List dense>
        {DOMAIN_NAV.map((item) => (
          <NavListItem
            key={item.to}
            item={item}
            count={item.countKey && recordCounts ? recordCounts[item.countKey] : undefined}
            collapsed={collapsed}
          />
        ))}
      </List>

      <Divider sx={{ my: 0.5 }} />

      <List dense>
        {utilityNav.map((item) => (
          <NavListItem key={item.to} item={item} collapsed={collapsed} />
        ))}
      </List>

      <Box sx={{ mt: 'auto', display: 'flex', justifyContent: 'center', pb: 1 }}>
        <Tooltip title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'} placement="right" arrow>
          <IconButton size="small" onClick={toggleSidebar} data-tid="nav-collapse">
            {collapsed ? <ExpandIcon fontSize="small" /> : <CollapseIcon fontSize="small" />}
          </IconButton>
        </Tooltip>
      </Box>
    </Drawer>
  )
}

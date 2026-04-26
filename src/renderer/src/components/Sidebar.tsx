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
} from '@mui/icons-material'
import { NavLink } from 'react-router-dom'
import { useLifecycleStore } from '../stores/lifecycle.store'
import { useValidationStore } from '../stores/validation.store'

const DRAWER_WIDTH = 220

interface NavItem {
  label: string
  to: string
  icon: React.ReactNode
  badge?: number
  badgeColor?: string
}

const DOMAIN_NAV: NavItem[] = [
  { label: 'Classes', to: '/classes', icon: <ClassesIcon fontSize="small" /> },
  { label: 'Abilities', to: '/abilities', icon: <AbilitiesIcon fontSize="small" /> },
  { label: 'Items', to: '/items', icon: <ItemsIcon fontSize="small" /> },
  { label: 'Recipes', to: '/recipes', icon: <RecipesIcon fontSize="small" /> },
  { label: 'NPCs', to: '/npcs', icon: <NpcsIcon fontSize="small" /> },
  { label: 'Loot Tables', to: '/loot-tables', icon: <LootIcon fontSize="small" /> },
]

function NavListItem({ item }: { item: NavItem }): React.JSX.Element {
  return (
    <ListItem disablePadding>
      <ListItemButton
        component={NavLink}
        to={item.to}
        sx={{
          borderRadius: 1,
          mx: 0.5,
          '&.active': {
            bgcolor: 'action.selected',
            '& .MuiListItemIcon-root': { color: 'primary.main' },
            '& .MuiListItemText-primary': { color: 'primary.main', fontWeight: 600 },
          },
        }}
      >
        <ListItemIcon sx={{ minWidth: 36 }}>{item.icon}</ListItemIcon>
        <ListItemText
          primary={item.label}
          primaryTypographyProps={{ fontSize: '0.875rem' }}
        />
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
      </ListItemButton>
    </ListItem>
  )
}

export default function Sidebar(): React.JSX.Element {
  const issueCount = useValidationStore((s) => s.issues.filter((i) => i.severity === 'error' || i.severity === 'warning').length)
  const hasErrors = useValidationStore((s) => s.issues.some((i) => i.severity === 'error'))
  const trashCount = useLifecycleStore((s) => s.trashCount)

  const utilityNav: NavItem[] = [
    { label: 'Validation', to: '/validation', icon: <ValidationIcon fontSize="small" />, badge: issueCount, badgeColor: hasErrors ? 'error.main' : 'warning.main' },
    { label: 'Recycle Bin', to: '/recycle-bin', icon: <RecycleBinIcon fontSize="small" />, badge: trashCount, badgeColor: 'text.secondary' },
    { label: 'Export', to: '/export', icon: <ExportIcon fontSize="small" /> },
    { label: 'Settings', to: '/settings', icon: <SettingsIcon fontSize="small" /> },
  ]

  return (
    <Drawer
      variant="permanent"
      sx={{
        width: DRAWER_WIDTH,
        flexShrink: 0,
        '& .MuiDrawer-paper': {
          width: DRAWER_WIDTH,
          boxSizing: 'border-box',
          position: 'relative',
          border: 'none',
          borderRight: 1,
          borderColor: 'divider',
        },
      }}
    >
      <List dense>
        <ListItem disablePadding>
          <ListItemButton
            component={NavLink}
            to="/"
            end
            sx={{
              borderRadius: 1,
              mx: 0.5,
              '&.active': {
                bgcolor: 'action.selected',
                '& .MuiListItemIcon-root': { color: 'primary.main' },
                '& .MuiListItemText-primary': { color: 'primary.main', fontWeight: 600 },
              },
            }}
          >
            <ListItemIcon sx={{ minWidth: 36 }}>
              <DashboardIcon fontSize="small" />
            </ListItemIcon>
            <ListItemText
              primary="Dashboard"
              primaryTypographyProps={{ fontSize: '0.875rem' }}
            />
          </ListItemButton>
        </ListItem>
      </List>

      <Divider sx={{ my: 0.5 }} />

      <List dense>
        {DOMAIN_NAV.map((item) => (
          <NavListItem key={item.to} item={item} />
        ))}
      </List>

      <Divider sx={{ my: 0.5 }} />

      <List dense>
        {utilityNav.map((item) => (
          <NavListItem key={item.to} item={item} />
        ))}
      </List>
    </Drawer>
  )
}

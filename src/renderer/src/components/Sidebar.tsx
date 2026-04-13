import {
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Divider,
  Tooltip,
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

const DRAWER_WIDTH = 220

interface NavItem {
  label: string
  to: string
  icon: React.ReactNode
}

const DOMAIN_NAV: NavItem[] = [
  { label: 'Classes', to: '/classes', icon: <ClassesIcon fontSize="small" /> },
  { label: 'Abilities', to: '/abilities', icon: <AbilitiesIcon fontSize="small" /> },
  { label: 'Items', to: '/items', icon: <ItemsIcon fontSize="small" /> },
  { label: 'Recipes', to: '/recipes', icon: <RecipesIcon fontSize="small" /> },
  { label: 'NPCs', to: '/npcs', icon: <NpcsIcon fontSize="small" /> },
  { label: 'Loot Tables', to: '/loot-tables', icon: <LootIcon fontSize="small" /> },
]

const UTILITY_NAV: NavItem[] = [
  { label: 'Validation', to: '/validation', icon: <ValidationIcon fontSize="small" /> },
  { label: 'Recycle Bin', to: '/recycle-bin', icon: <RecycleBinIcon fontSize="small" /> },
  { label: 'Export', to: '/export', icon: <ExportIcon fontSize="small" /> },
  { label: 'Settings', to: '/settings', icon: <SettingsIcon fontSize="small" /> },
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
      </ListItemButton>
    </ListItem>
  )
}

export default function Sidebar(): React.JSX.Element {
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
        {UTILITY_NAV.map((item) => (
          <NavListItem key={item.to} item={item} />
        ))}
      </List>
    </Drawer>
  )
}

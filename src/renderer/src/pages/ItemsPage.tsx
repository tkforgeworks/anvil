import {
  Box,
  Divider,
  List,
  ListItemButton,
  ListItemText,
  Stack,
  Typography,
} from '@mui/material'
import { useEffect, useState } from 'react'
import { itemsApi } from '../../api/items.api'
import type { ItemRecord } from '../../../shared/domain-types'
import CustomFieldsPanel from '../components/CustomFieldsPanel'

/**
 * Items page — custom fields test harness (full editor in ANV-10).
 *
 * Loads all items, lets the user select one, then renders CustomFieldsPanel
 * for that item's category. This exercises the full custom-field round-trip:
 *   define fields in Settings → pick an item here → enter values → verify persistence.
 */
export default function ItemsPage(): React.JSX.Element {
  const [items, setItems] = useState<ItemRecord[]>([])
  const [selectedItem, setSelectedItem] = useState<ItemRecord | null>(null)

  useEffect(() => {
    void itemsApi.list().then(setItems)
  }, [])

  return (
    <Box sx={{ display: 'flex', height: '100%' }}>
      {/* Item list */}
      <Box
        sx={{
          width: 260,
          flexShrink: 0,
          borderRight: 1,
          borderColor: 'divider',
          overflow: 'auto',
          p: 2,
        }}
      >
        <Typography variant="h6" gutterBottom>
          Items
        </Typography>
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
          Custom fields test harness — full editor in ANV-10
        </Typography>
        <Divider sx={{ mb: 1 }} />
        {items.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            No items yet. Create a project, add items via the DevTools console, then return here
            to test custom field values.
          </Typography>
        ) : (
          <List dense disablePadding>
            {items.map((item) => (
              <ListItemButton
                key={item.id}
                selected={selectedItem?.id === item.id}
                onClick={() => setSelectedItem(item)}
                sx={{ borderRadius: 1 }}
              >
                <ListItemText
                  primary={item.displayName}
                  secondary={item.itemCategoryId}
                  secondaryTypographyProps={{ noWrap: true }}
                />
              </ListItemButton>
            ))}
          </List>
        )}
      </Box>

      {/* Custom fields panel */}
      <Box sx={{ flex: 1, p: 3, overflow: 'auto' }}>
        {selectedItem ? (
          <Stack spacing={2}>
            <Box>
              <Typography variant="h6">{selectedItem.displayName}</Typography>
              <Typography variant="body2" color="text.secondary">
                Category: {selectedItem.itemCategoryId}
              </Typography>
            </Box>
            <Divider />
            <CustomFieldsPanel
              domain="items"
              recordId={selectedItem.id}
              scopeType="item_category"
              scopeId={selectedItem.itemCategoryId}
            />
          </Stack>
        ) : (
          <Typography color="text.secondary">Select an item to view its custom fields.</Typography>
        )}
      </Box>
    </Box>
  )
}

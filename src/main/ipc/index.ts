import { registerProjectHandlers } from './project.handlers'
import { registerClassesHandlers } from './classes.handlers'
import { registerAbilitiesHandlers } from './abilities.handlers'
import { registerItemsHandlers } from './items.handlers'
import { registerRecipesHandlers } from './recipes.handlers'
import { registerNpcsHandlers } from './npcs.handlers'
import { registerLootTablesHandlers } from './loot-tables.handlers'
import { registerValidationHandlers } from './validation.handlers'
import { registerExportHandlers } from './export.handlers'
import { registerSettingsHandlers } from './settings.handlers'
import { registerMetaHandlers } from './meta.handlers'
import { registerCustomFieldsHandlers } from './custom-fields.handlers'
import { registerFormulaHandlers } from './formula.handlers'

/**
 * Registers all IPC handlers for all domains.
 * Called once from the main process entry inside app.whenReady().
 */
export function registerAllIpcHandlers(): void {
  registerProjectHandlers()
  registerClassesHandlers()
  registerAbilitiesHandlers()
  registerItemsHandlers()
  registerRecipesHandlers()
  registerNpcsHandlers()
  registerLootTablesHandlers()
  registerValidationHandlers()
  registerExportHandlers()
  registerSettingsHandlers()
  registerMetaHandlers()
  registerCustomFieldsHandlers()
  registerFormulaHandlers()
}

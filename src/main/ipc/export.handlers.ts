import { ipcMain, dialog, BrowserWindow } from 'electron'
import { writeFile, mkdir } from 'fs/promises'
import { join } from 'path'
import { randomUUID } from 'crypto'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { getDb } from '../db/connection'
import { assembleExportContext, type ExportScope } from '../export/context-assembler'
import { BUILT_IN_PRESETS, renderExport, renderCustomTemplate, type ExportPreset, type RenderResult } from '../export/renderer'
import { validateProject } from '../validation/engine'

export interface ExportPresetInfo {
  id: string
  name: string
  description: string
  format: string
  builtIn: boolean
}

interface CustomTemplate {
  id: string
  name: string
  description: string
  template_source: string
  format: string
  created_at: string
  updated_at: string
}

function getCustomTemplates(): CustomTemplate[] {
  const db = getDb()
  return db.prepare(
    'SELECT id, name, description, template_source, format, created_at, updated_at FROM custom_templates ORDER BY name COLLATE NOCASE',
  ).all() as CustomTemplate[]
}

function runValidationGate(): { blocked: boolean; error?: string } {
  const db = getDb()
  const issues = validateProject(db)
  const errors = issues.filter((i) => i.severity === 'error')
  if (errors.length > 0) {
    return {
      blocked: true,
      error: `Export blocked: ${errors.length} validation ${errors.length === 1 ? 'error' : 'errors'} must be resolved before exporting.`,
    }
  }
  return { blocked: false }
}

function renderForPresetOrTemplate(
  presetId: string,
  scope: ExportScope,
): RenderResult {
  const db = getDb()
  const context = assembleExportContext(db, scope)

  const builtIn = BUILT_IN_PRESETS.find((p) => p.id === presetId)
  if (builtIn) {
    return renderExport(presetId, context)
  }

  const template = db.prepare(
    'SELECT template_source FROM custom_templates WHERE id = ?',
  ).get(presetId) as { template_source: string } | undefined

  if (!template) {
    throw new Error(`Template not found: ${presetId}`)
  }

  return renderCustomTemplate(template.template_source, context)
}

export function registerExportHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.EXPORT_GET_TEMPLATES,
    (): ExportPresetInfo[] => {
      const builtIn = BUILT_IN_PRESETS.map((p: ExportPreset) => ({
        id: p.id,
        name: p.name,
        description: p.description,
        format: p.format,
        builtIn: p.builtIn,
      }))

      const custom = getCustomTemplates().map((t) => ({
        id: t.id,
        name: t.name,
        description: t.description,
        format: t.format,
        builtIn: false,
      }))

      return [...builtIn, ...custom]
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.EXPORT_LIST_CUSTOM_TEMPLATES,
    (): CustomTemplate[] => getCustomTemplates(),
  )

  ipcMain.handle(
    IPC_CHANNELS.EXPORT_CREATE_TEMPLATE,
    (_event, data: { name: string; description?: string; template_source: string; format?: string }): CustomTemplate => {
      const db = getDb()
      const id = randomUUID()
      const now = new Date().toISOString()
      db.prepare(
        `INSERT INTO custom_templates (id, name, description, template_source, format, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ).run(id, data.name, data.description ?? '', data.template_source, data.format ?? 'text', now, now)
      return db.prepare('SELECT * FROM custom_templates WHERE id = ?').get(id) as CustomTemplate
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.EXPORT_UPDATE_TEMPLATE,
    (_event, id: string, data: { name?: string; description?: string; template_source?: string; format?: string }): CustomTemplate => {
      const db = getDb()
      const existing = db.prepare('SELECT * FROM custom_templates WHERE id = ?').get(id) as CustomTemplate | undefined
      if (!existing) throw new Error(`Template not found: ${id}`)

      db.prepare(
        `UPDATE custom_templates SET name = ?, description = ?, template_source = ?, format = ?, updated_at = datetime('now')
         WHERE id = ?`,
      ).run(
        data.name ?? existing.name,
        data.description ?? existing.description,
        data.template_source ?? existing.template_source,
        data.format ?? existing.format,
        id,
      )
      return db.prepare('SELECT * FROM custom_templates WHERE id = ?').get(id) as CustomTemplate
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.EXPORT_DELETE_TEMPLATE,
    (_event, id: string): { success: boolean } => {
      const db = getDb()
      db.prepare('DELETE FROM custom_templates WHERE id = ?').run(id)
      return { success: true }
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.EXPORT_PREVIEW,
    (_event, presetId: string, scope: ExportScope): { output: string; files?: { filename: string; content: string }[]; error?: string } => {
      try {
        const gate = runValidationGate()
        if (gate.blocked) return { output: '', error: gate.error }

        const result = renderForPresetOrTemplate(presetId, scope)
        return { output: result.output, files: result.files }
      } catch (cause) {
        return { output: '', error: cause instanceof Error ? cause.message : 'Export preview failed.' }
      }
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.EXPORT_EXECUTE,
    async (_event, presetId: string, scope: ExportScope): Promise<{ success: boolean; error?: string; path?: string }> => {
      try {
        const gate = runValidationGate()
        if (gate.blocked) return { success: false, error: gate.error }

        const result = renderForPresetOrTemplate(presetId, scope)
        const win = BrowserWindow.getFocusedWindow()

        if (result.files && result.files.length > 1) {
          const dialogResult = win
            ? await dialog.showOpenDialog(win, { title: 'Select Export Folder', properties: ['openDirectory', 'createDirectory'] })
            : await dialog.showOpenDialog({ title: 'Select Export Folder', properties: ['openDirectory', 'createDirectory'] })

          if (dialogResult.canceled || !dialogResult.filePaths[0]) {
            return { success: false, error: 'Export canceled.' }
          }
          const folder = dialogResult.filePaths[0]
          await mkdir(folder, { recursive: true })
          for (const file of result.files) {
            await writeFile(join(folder, file.filename), file.content, 'utf-8')
          }
          return { success: true, path: folder }
        }

        const preset = BUILT_IN_PRESETS.find((p) => p.id === presetId)
        const defaultExt = preset?.format === 'json' ? 'json' : 'txt'
        const dialogResult = win
          ? await dialog.showSaveDialog(win, {
              title: 'Export Project Data',
              defaultPath: `export.${defaultExt}`,
              filters: [
                { name: 'JSON Files', extensions: ['json'] },
                { name: 'Text Files', extensions: ['txt'] },
                { name: 'All Files', extensions: ['*'] },
              ],
            })
          : await dialog.showSaveDialog({
              title: 'Export Project Data',
              defaultPath: `export.${defaultExt}`,
              filters: [
                { name: 'JSON Files', extensions: ['json'] },
                { name: 'Text Files', extensions: ['txt'] },
                { name: 'All Files', extensions: ['*'] },
              ],
            })

        if (dialogResult.canceled || !dialogResult.filePath) {
          return { success: false, error: 'Export canceled.' }
        }

        await writeFile(dialogResult.filePath, result.output, 'utf-8')
        return { success: true, path: dialogResult.filePath }
      } catch (cause) {
        return { success: false, error: cause instanceof Error ? cause.message : 'Export failed.' }
      }
    },
  )
}

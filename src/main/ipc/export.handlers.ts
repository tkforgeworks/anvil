import { ipcMain, dialog, BrowserWindow } from 'electron'
import { writeFile, mkdir } from 'fs/promises'
import { join } from 'path'
import { IPC_CHANNELS } from '../../shared/ipc-channels'
import { getDb } from '../db/connection'
import { assembleExportContext, type ExportScope } from '../export/context-assembler'
import { BUILT_IN_PRESETS, renderExport, type ExportPreset, type RenderResult } from '../export/renderer'
import { validateProject } from '../validation/engine'

export interface ExportPresetInfo {
  id: string
  name: string
  description: string
  format: string
  builtIn: boolean
}

export function registerExportHandlers(): void {
  ipcMain.handle(
    IPC_CHANNELS.EXPORT_GET_TEMPLATES,
    (): ExportPresetInfo[] => {
      return BUILT_IN_PRESETS.map((p: ExportPreset) => ({
        id: p.id,
        name: p.name,
        description: p.description,
        format: p.format,
        builtIn: p.builtIn,
      }))
    },
  )

  ipcMain.handle(
    IPC_CHANNELS.EXPORT_PREVIEW,
    (_event, presetId: string, scope: ExportScope): { output: string; files?: { filename: string; content: string }[]; error?: string } => {
      try {
        const db = getDb()
        const issues = validateProject(db)
        const errors = issues.filter((i) => i.severity === 'error')
        if (errors.length > 0) {
          return {
            output: '',
            error: `Export blocked: ${errors.length} validation ${errors.length === 1 ? 'error' : 'errors'} must be resolved before exporting.`,
          }
        }
        const context = assembleExportContext(db, scope)
        const result: RenderResult = renderExport(presetId, context)
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
        const db = getDb()
        const issues = validateProject(db)
        const errors = issues.filter((i) => i.severity === 'error')
        if (errors.length > 0) {
          return {
            success: false,
            error: `Export blocked: ${errors.length} validation ${errors.length === 1 ? 'error' : 'errors'} must be resolved before exporting.`,
          }
        }

        const context = assembleExportContext(db, scope)
        const result: RenderResult = renderExport(presetId, context)
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
                { name: 'All Files', extensions: ['*'] },
              ],
            })
          : await dialog.showSaveDialog({
              title: 'Export Project Data',
              defaultPath: `export.${defaultExt}`,
              filters: [
                { name: 'JSON Files', extensions: ['json'] },
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

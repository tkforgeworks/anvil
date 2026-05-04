import { app, BrowserWindow, ipcMain } from 'electron'
import { join } from 'path'
import { registerAllIpcHandlers } from './ipc'
import { initLogger, logError, logInfo, logWarn } from './logging/app-logger'
import { writeTelemetrySessionStart } from './logging/telemetry-writer'
import { closeActiveProject } from './project/project-service'

process.on('uncaughtException', (error) => {
  logError('Uncaught exception', error)
})

process.on('unhandledRejection', (reason) => {
  logError('Unhandled rejection', reason instanceof Error ? reason : new Error(String(reason)))
})

function createWindow(): void {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 1400,
    minHeight: 600,
    frame: false,
    icon: join(__dirname, '../../resources/icon.png'),
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      nodeIntegration: false,
      contextIsolation: true,
    },
  })

  if (!app.isPackaged && process.env['ELECTRON_RENDERER_URL']) {
    win.loadURL(process.env['ELECTRON_RENDERER_URL'])
  } else {
    win.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

function registerWindowControls(): void {
  ipcMain.handle('window:minimize', (event) => {
    BrowserWindow.fromWebContents(event.sender)?.minimize()
  })
  ipcMain.handle('window:maximize', (event) => {
    const win = BrowserWindow.fromWebContents(event.sender)
    if (win?.isMaximized()) {
      win.unmaximize()
    } else {
      win?.maximize()
    }
  })
  ipcMain.handle('window:close', (event) => {
    BrowserWindow.fromWebContents(event.sender)?.close()
  })
}

app.whenReady().then(() => {
  initLogger()

  const originalConsoleError = console.error
  console.error = (...args: unknown[]) => { logError(args.map(String).join(' ')); originalConsoleError(...args) }
  const originalConsoleWarn = console.warn
  console.warn = (...args: unknown[]) => { logWarn(args.map(String).join(' ')); originalConsoleWarn(...args) }

  logInfo('Anvil starting')
  if (__TELEMETRY_ENABLED__) writeTelemetrySessionStart()
  registerAllIpcHandlers()
  registerWindowControls()
  ipcMain.handle('ping', () => 'pong')

  createWindow()
  logInfo('Main window created')

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('before-quit', () => {
  logInfo('Anvil shutting down')
  closeActiveProject()
})

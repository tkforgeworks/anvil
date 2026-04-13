import { app, BrowserWindow, ipcMain } from 'electron'
import { join } from 'path'
import { registerAllIpcHandlers } from './ipc'
import { openDatabase, closeDatabase, getDb } from './db/connection'
import { runMigrations } from './db/migrations/runner'

function createWindow(): void {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
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

// Register all domain IPC handlers
registerAllIpcHandlers()

// IPC verification handler — confirms bridge is functional
ipcMain.handle('ping', () => 'pong')

app.whenReady().then(() => {
  // Bootstrap an in-memory DB so the connection is available during development.
  // The Project lifecycle epic (project:open / project:create) will replace this
  // with the actual project file path.
  const db = openDatabase(':memory:')
  runMigrations(db)
  createWindow()

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
  try {
    closeDatabase(getDb())
  } catch {
    // DB may not be open if the app quit before fully initialising
  }
})

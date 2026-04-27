import { existsSync, mkdirSync } from 'node:fs'
import { basename, dirname, join } from 'node:path'

export interface ProjectFolderPaths {
  root: string
  database: string
  exports: string
  temp: string
  logs: string
}

const SUBDIRS = ['database', 'exports', 'temp', 'logs'] as const

export function sanitizeFolderName(value: string): string {
  return value.replace(/[<>:"/\\|?*\x00-\x1f]+/g, '_').replace(/^_+|_+$/g, '').trim()
}

export function createProjectFolder(parentDir: string, projectName: string): ProjectFolderPaths {
  const folderName = sanitizeFolderName(projectName)
  if (!folderName) throw new Error('Project name produces an empty folder name.')

  const root = join(parentDir, folderName)
  if (existsSync(root)) throw new Error(`Folder already exists: ${root}`)

  const paths = buildPaths(root)
  for (const subdir of SUBDIRS) {
    mkdirSync(paths[subdir], { recursive: true })
  }
  return paths
}

export function detectProjectFolder(anvilFilePath: string): ProjectFolderPaths | null {
  const parentDir = dirname(anvilFilePath)
  if (basename(parentDir) !== 'database') return null

  const root = dirname(parentDir)
  const paths = buildPaths(root)

  for (const subdir of SUBDIRS) {
    if (!existsSync(paths[subdir])) return null
  }
  return paths
}

function buildPaths(root: string): ProjectFolderPaths {
  return {
    root,
    database: join(root, 'database'),
    exports: join(root, 'exports'),
    temp: join(root, 'temp'),
    logs: join(root, 'logs'),
  }
}

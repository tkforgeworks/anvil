import type { ForgeConfig } from '@electron-forge/shared-types'

const config: ForgeConfig = {
  outDir: 'dist',
  packagerConfig: {
    asar: {
      unpack: 'node_modules/better-sqlite3/**/*',
    },
    name: 'Anvil',
    executableName: 'anvil',
    icon: './resources/icon',
    ignore: (filePath: string) => {
      if (!filePath) return false
      if (/\/node_modules\/\.bin(\/|$)/.test(filePath)) return true
      if (/^\/package\.json$/.test(filePath)) return false
      if (/^\/out(\/|$)/.test(filePath)) return false
      if (/^\/node_modules(\/|$)/.test(filePath)) return false
      if (/^\/resources(\/|$)/.test(filePath)) return false
      return true
    },
  },
  makers: [
    {
      name: '@electron-forge/maker-squirrel',
      config: {
        name: 'Anvil',
      },
    },
    {
      name: '@electron-forge/maker-zip',
      platforms: ['darwin', 'linux'],
      config: {},
    },
    {
      name: '@electron-forge/maker-deb',
      config: {},
    },
    {
      name: '@electron-forge/maker-rpm',
      config: {},
    },
    {
      name: '@reforged/maker-appimage',
      config: {
        options: {
          categories: ['Game', 'Utility'],
        },
      },
    },
  ],
}

export default config

import type { ForgeConfig } from '@electron-forge/shared-types'

const config: ForgeConfig = {
  packagerConfig: {
    asar: {
      unpack: 'node_modules/better-sqlite3/**/*',
    },
    name: 'Anvil',
    executableName: 'anvil',
    ignore: [
      /^\/src/,
      /^\/design_notes/,
      /^\/archive/,
      /^\/\.claude/,
      /^\/\.git/,
      /^\/tsconfig/,
      /^\/electron\.vite\.config/,
      /^\/forge\.config/,
      /node_modules\/\.bin/,
    ],
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
  ],
}

export default config

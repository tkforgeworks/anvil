import { defineConfig, externalizeDepsPlugin } from 'electron-vite'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'
import { execSync } from 'child_process'

const appVersion = JSON.stringify(require('./package.json').version)
const gitSha = JSON.stringify(execSync('git rev-parse --short HEAD').toString().trim())
const buildDate = JSON.stringify(new Date().toISOString())

const buildDefines = {
  __APP_VERSION__: appVersion,
  __GIT_SHA__: gitSha,
  __BUILD_DATE__: buildDate,
}

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    define: buildDefines,
    build: {
      lib: {
        entry: resolve(__dirname, 'src/main/index.ts'),
      },
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    define: buildDefines,
    build: {
      lib: {
        entry: resolve(__dirname, 'src/preload/index.ts'),
      },
    },
  },
  renderer: {
    root: resolve(__dirname, 'src/renderer'),
    plugins: [react()],
    define: buildDefines,
    resolve: {
      alias: {
        '@renderer': resolve(__dirname, 'src/renderer/src'),
        '@shared': resolve(__dirname, 'src/shared'),
      },
    },
  },
})

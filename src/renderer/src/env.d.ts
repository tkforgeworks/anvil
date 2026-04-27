import type { AnvilBridge } from '../../shared/ipc-types'

declare global {
  interface Window {
    /** Typed IPC bridge exposed by the preload script via contextBridge. */
    anvil: AnvilBridge
  }
}

declare module '*.png' {
  const src: string
  export default src
}

declare module '@mui/material/styles' {
  interface TypographyVariants {
    fontFamilyMono: string
  }
  interface TypographyVariantsOptions {
    fontFamilyMono?: string
  }
}

export {}

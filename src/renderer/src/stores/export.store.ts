import { create } from 'zustand'

export type ExportScope = 'all' | 'domain' | 'selection'

interface ExportState {
  selectedTemplateId: string | null
  scope: ExportScope
  scopeDomain: string | null
  previewOutput: string | null

  setTemplate: (id: string | null) => void
  setScope: (scope: ExportScope, domain?: string) => void
  setPreviewOutput: (output: string | null) => void
  reset: () => void
}

export const useExportStore = create<ExportState>()((set) => ({
  selectedTemplateId: null,
  scope: 'all',
  scopeDomain: null,
  previewOutput: null,

  setTemplate: (id) => set({ selectedTemplateId: id }),
  setScope: (scope, domain) => set({ scope, scopeDomain: domain ?? null }),
  setPreviewOutput: (output) => set({ previewOutput: output }),
  reset: () =>
    set({ selectedTemplateId: null, scope: 'all', scopeDomain: null, previewOutput: null }),
}))

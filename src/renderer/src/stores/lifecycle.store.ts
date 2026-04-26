import { create } from 'zustand'
import { lifecycleApi } from '../../api/lifecycle.api'

interface LifecycleState {
  trashCount: number
  refreshTrashCount: () => Promise<void>
}

export const useLifecycleStore = create<LifecycleState>()((set) => ({
  trashCount: 0,
  refreshTrashCount: async () => {
    try {
      const count = await lifecycleApi.countDeleted()
      set({ trashCount: count })
    } catch {
      // silently ignore — badge is informational
    }
  },
}))

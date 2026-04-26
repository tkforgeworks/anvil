import { IPC_CHANNELS } from '../../shared/ipc-channels'
import type {
  BulkOperationInput,
  DeleteImpactSummary,
  LifecycleDomain,
} from '../../shared/domain-types'

export const lifecycleApi = {
  bulkSoftDelete: (domain: LifecycleDomain, ids: string[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.LIFECYCLE_BULK_SOFT_DELETE, { domain, ids } satisfies BulkOperationInput),

  bulkRestore: (domain: LifecycleDomain, ids: string[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.LIFECYCLE_BULK_RESTORE, { domain, ids } satisfies BulkOperationInput),

  bulkHardDelete: (domain: LifecycleDomain, ids: string[]) =>
    window.anvil.invoke<void>(IPC_CHANNELS.LIFECYCLE_BULK_HARD_DELETE, { domain, ids } satisfies BulkOperationInput),

  emptyTrash: () =>
    window.anvil.invoke<void>(IPC_CHANNELS.LIFECYCLE_EMPTY_TRASH),

  computeDeleteImpact: (domain: LifecycleDomain, ids: string[]) =>
    window.anvil.invoke<DeleteImpactSummary>(IPC_CHANNELS.LIFECYCLE_COMPUTE_DELETE_IMPACT, { domain, ids } satisfies BulkOperationInput),

  countDeleted: () =>
    window.anvil.invoke<number>(IPC_CHANNELS.LIFECYCLE_COUNT_DELETED),
}

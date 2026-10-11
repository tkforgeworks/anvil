import type { MetaInUseKind, MetaItemInput } from '../../../shared/domain-types'
import { useBufferedMetaList } from '../hooks/useBufferedMetaList'
import MetaListSection from './MetaListSection'
import type { MetaBufferItem } from './settings/meta-buffer'

interface BufferedMetaListSectionProps<T extends MetaBufferItem> {
  title: string
  singularName: string
  description?: string
  /** FK check kind used when a persisted row is deleted. */
  kind: MetaInUseKind
  items: T[]
  onChange: (next: T[]) => void
  /** Builds a new row of this list's concrete type from the dialog input. */
  create: (id: string, sortOrder: number, input: MetaItemInput) => T
}

const noop = (): void => {}

/**
 * Controlled variant of `MetaListSection` (ANVL-121). Instead of persisting each
 * add/edit/delete/reorder through the API it reports the next list via
 * `onChange`; the owner commits the whole buffer on Save. `MetaListSection`
 * itself is unchanged — this just feeds it in-memory handlers.
 */
export default function BufferedMetaListSection<T extends MetaBufferItem>({
  title,
  singularName,
  description,
  kind,
  items,
  onChange,
  create,
}: BufferedMetaListSectionProps<T>): React.JSX.Element {
  const handlers = useBufferedMetaList<T, MetaItemInput>(items, onChange, {
    kind,
    create,
    apply: (item, input) => ({ ...item, ...input }),
  })

  return (
    <MetaListSection
      title={title}
      singularName={singularName}
      description={description}
      items={items}
      onAdd={handlers.add}
      onUpdate={handlers.update}
      onDelete={handlers.delete}
      onReorder={handlers.reorder}
      onRefresh={noop}
    />
  )
}

/// Which rows a domain repository's `list` returns.
///
/// Ports the `includeDeleted` / `deletedOnly` flag pair of 0.1.6's
/// `DomainRepository.list(includeDeleted, deletedOnly)`, whose three
/// reachable states become the three values. Rows are ordered by display
/// name, case-insensitively, in every mode.
enum RecordListMode {
  /// `deleted_at IS NULL`: the active list views (0.1.6 default).
  active,

  /// Every row, soft-deleted or not (0.1.6 `includeDeleted = true`).
  all,

  /// `deleted_at IS NOT NULL`: archive views and the recycle bin (0.1.6
  /// `deletedOnly = true`).
  deletedOnly,
}

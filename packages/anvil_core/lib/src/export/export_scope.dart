/// What an export covers: the whole project, one domain, or a record
/// selection within one domain; ports 0.1.6's `ExportScope`
/// (`src/main/export/context-assembler.ts`).
library;

/// The six record domains an export scope can name, with the context key
/// of each (0.1.6 accepted `loot-tables` and normalised it to
/// `loot_tables`; here the enum makes an unknown domain impossible).
enum ExportDomain {
  classes('classes'),
  abilities('abilities'),
  items('items'),
  recipes('recipes'),
  npcs('npcs'),
  lootTables('loot_tables');

  const ExportDomain(this.contextKey);

  /// The domain's array in the export context, for example `loot_tables`.
  final String contextKey;
}

/// 0.1.6 `{mode: 'full' | 'domain' | 'selection', domain?, recordIds?}`.
sealed class ExportScope {
  const ExportScope();

  /// `{mode: 'full'}`: every domain.
  const factory ExportScope.full() = FullProjectScope;

  /// `{mode: 'domain', domain}`: every active record of [domain].
  const factory ExportScope.domain(ExportDomain domain) = DomainScope;

  /// `{mode: 'selection', domain, recordIds}`: the active records of
  /// [domain] whose ids are in [recordIds].
  factory ExportScope.selection(ExportDomain domain, List<String> recordIds) =
      SelectionScope;

  /// 0.1.6's `scope.mode === 'full'`, which the JSON presets branch on.
  bool get isFull => this is FullProjectScope;
}

final class FullProjectScope extends ExportScope {
  const FullProjectScope();

  @override
  bool operator ==(Object other) => other is FullProjectScope;

  @override
  int get hashCode => (FullProjectScope).hashCode;

  @override
  String toString() => 'ExportScope.full()';
}

final class DomainScope extends ExportScope {
  const DomainScope(this.domain);

  final ExportDomain domain;

  @override
  bool operator ==(Object other) =>
      other is DomainScope && other.domain == domain;

  @override
  int get hashCode => Object.hash(DomainScope, domain);

  @override
  String toString() => 'ExportScope.domain(${domain.name})';
}

final class SelectionScope extends ExportScope {
  SelectionScope(this.domain, List<String> recordIds)
    : recordIds = List.unmodifiable(recordIds);

  final ExportDomain domain;

  /// As 0.1.6, an empty selection exports no records at all.
  final List<String> recordIds;

  @override
  bool operator ==(Object other) =>
      other is SelectionScope &&
      other.domain == domain &&
      other.recordIds.length == recordIds.length &&
      Iterable<int>.generate(recordIds.length)
          .every((i) => other.recordIds[i] == recordIds[i]);

  @override
  int get hashCode =>
      Object.hash(SelectionScope, domain, Object.hashAll(recordIds));

  @override
  String toString() =>
      'ExportScope.selection(${domain.name}, ${recordIds.length} ids)';
}

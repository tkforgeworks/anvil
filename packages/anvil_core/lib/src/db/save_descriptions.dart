/// The six record domains, with the labels 0.1.6's `DOMAIN_LABELS` used.
enum SaveDomain {
  classes('class', 'classes'),
  abilities('ability', 'abilities'),
  items('item', 'items'),
  recipes('recipe', 'recipes'),
  npcs('NPC', 'NPCs'),
  lootTables('loot table', 'loot tables');

  const SaveDomain(this.singular, this.plural);

  final String singular;
  final String plural;
}

/// Verbs used in bulk descriptions.
enum SaveAction {
  created('created'),
  deleted('deleted'),
  restored('restored'),
  duplicated('duplicated'),
  hardDeleted('permanently deleted'),
  changed('changed');

  const SaveAction(this.label);

  final String label;
}

/// 0.1.6's `titleCase`: upper-cases the first letter of each word.
String _titleCase(String s) =>
    s.replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase());

String _record(SaveDomain domain, String name, SaveAction action) {
  final label = _titleCase(domain.singular);
  final prefix = name.isEmpty ? label : '$name - $label';
  return '$prefix ${action.label}';
}

String recordChanged(SaveDomain domain, String name) =>
    _record(domain, name, SaveAction.changed);
String recordCreated(SaveDomain domain, String name) =>
    _record(domain, name, SaveAction.created);
String recordDeleted(SaveDomain domain, String name) =>
    _record(domain, name, SaveAction.deleted);
String recordRestored(SaveDomain domain, String name) =>
    _record(domain, name, SaveAction.restored);
String recordDuplicated(SaveDomain domain, String name) =>
    _record(domain, name, SaveAction.duplicated);
String recordHardDeleted(SaveDomain domain, String name) =>
    _record(domain, name, SaveAction.hardDeleted);

/// `3 items deleted`.
String bulkChanged(SaveDomain domain, int count, SaveAction action) =>
    '$count ${domain.plural} ${action.label}';

const String projectSettingsChanged = 'Project settings changed';
const String customFieldDefinitionsChanged = 'Custom field definitions changed';

/// New in 0.2.0 (0.1.6 did not record template edits).
String templateChanged(String name) => '$name - Template changed';

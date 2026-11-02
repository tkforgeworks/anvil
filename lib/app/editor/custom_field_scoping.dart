/// The custom field values a record keeps for its category or type, shared
/// by the item and NPC editors (0.1.6 `CustomFieldsPanel.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';

/// The custom field values of [values] that belong to [definitions], then
/// each definition's default where the record has no value row at all, as
/// 0.1.6's `CustomFieldsPanel` seeded `def.defaultValue ?? ''` before
/// laying the stored rows over it. A stored `NULL` row keeps its null.
///
/// With [keepOthers] the values of other definitions stay (first load);
/// without, they are dropped (an item category or NPC type change).
Map<String, String?> scopeCustomFieldValues(
  Map<String, String?> values,
  List<CustomFieldDefinition> definitions, {
  required bool keepOthers,
}) {
  final ids = {for (final d in definitions) d.id};
  final next = <String, String?>{
    for (final MapEntry(:key, :value) in values.entries)
      if (keepOthers || ids.contains(key)) key: value,
  };
  for (final definition in definitions) {
    final fallback = definition.defaultValue;
    if (fallback != null &&
        fallback.isNotEmpty &&
        !next.containsKey(definition.id)) {
      next[definition.id] = fallback;
    }
  }
  return next;
}

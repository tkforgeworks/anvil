/// The item editor's draft controller (design §8.4; 0.1.6
/// `ItemEditorPage.tsx` and `CustomFieldsPanel.tsx`).
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_controller.dart';
import '../../shell/shell_providers.dart';

/// One item draft per open item editor, keyed by item id.
final itemsEditorProvider = AsyncNotifierProvider.autoDispose
    .family<ItemEditorController, EditorState<ItemDraft>, String>(
      ItemEditorController.new,
    );

/// The custom field values of [values] that belong to [definitions], then
/// each definition's default where the item has no value row at all, as
/// 0.1.6's `CustomFieldsPanel` seeded `def.defaultValue ?? ''` before
/// laying the stored rows over it. A stored `NULL` row keeps its null.
///
/// With [keepOthers] the values of other definitions stay (first load);
/// without, they are dropped (a category change).
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

/// The item editor: identity, category, rarity, description and the
/// category's custom field values in one draft, saved in one transaction.
///
/// The repositories are read at call time, never watched in `build()`.
class ItemEditorController extends RecordEditorController<ItemDraft> {
  ItemEditorController(super.recordId);

  ItemRepository get _items => ref.read(itemRepositoryProvider);

  CustomFieldRepository get _customFields =>
      ref.read(customFieldRepositoryProvider);

  Future<List<CustomFieldDefinition>> _definitionsFor(String categoryId) =>
      _customFields.listDefinitions(CustomFieldScope.itemCategory, categoryId);

  @override
  SaveDomain get domain => SaveDomain.items;

  /// The stored item with the defaults of its category's fields filled in
  /// where it has no value, as 0.1.6's panel showed them. The baseline
  /// carries the defaults, so they are written with the next save and the
  /// freshly opened editor is clean.
  @override
  Future<ItemDraft> loadDraft() async {
    final draft = await _items.load(recordId);
    if (draft.itemCategoryId.isEmpty) return draft;
    final definitions = await _definitionsFor(draft.itemCategoryId);
    return draft.copyWith(
      customFieldValues: scopeCustomFieldValues(
        draft.customFieldValues,
        definitions,
        keepOthers: true,
      ),
    );
  }

  /// Trims the name, key and description as 0.1.6's `handleSave` did.
  @override
  Future<ItemDraft> saveDraft(ItemDraft draft) => _items.save(
    recordId,
    draft.copyWith(
      displayName: draft.displayName.trim(),
      exportKey: draft.exportKey.trim(),
      description: draft.description.trim(),
    ),
  );

  @override
  List<SaveBlocker> blockersFor(ItemDraft draft) => itemSaveBlockers(draft);

  @override
  String displayNameOf(ItemDraft draft) => draft.displayName;

  void setDisplayName(String value) =>
      edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setExportKey(String value) =>
      edit((d) => d.copyWith(exportKey: value), coalesceKey: 'exportKey');

  void setDescription(String value) =>
      edit((d) => d.copyWith(description: value), coalesceKey: 'description');

  void setRarity(String rarityId) =>
      edit((d) => d.copyWith(rarityId: rarityId));

  /// Moves the item to [categoryId] as one undo step: the values of fields
  /// the new category defines are kept, the others dropped, and the new
  /// category's defaults fill the fields that have no value. The
  /// repository drops the same values again on save, as 0.1.6's `update`
  /// did.
  Future<void> setCategory(String categoryId) async {
    final current = state.value;
    if (current == null || current.draft.itemCategoryId == categoryId) return;
    var definitions = const <CustomFieldDefinition>[];
    try {
      definitions = await _definitionsFor(categoryId);
    } catch (_) {
      // Without the definitions no value can be shown as kept; the change
      // still applies and drops them all, as the save would.
    }
    if (!ref.mounted) return;
    edit(
      (d) => d.copyWith(
        itemCategoryId: categoryId,
        customFieldValues: scopeCustomFieldValues(
          d.customFieldValues,
          definitions,
          keepOthers: false,
        ),
      ),
    );
  }

  /// Sets custom field [definitionId] to [value]; an empty text is stored
  /// as null, as 0.1.6 saved `value || null`. Pass [typing] for a text
  /// field, so a burst of keystrokes is one undo step.
  void setCustomFieldValue(
    String definitionId,
    String? value, {
    bool typing = false,
  }) {
    final stored = value == null || value.isEmpty ? null : value;
    // An emptied field the stored item had no row for is left without one,
    // so clearing what was typed returns to the baseline.
    final hadRow =
        state.value?.baseline.customFieldValues.containsKey(definitionId) ??
        false;
    edit((d) {
      final values = {...d.customFieldValues};
      if (stored == null && !hadRow) {
        values.remove(definitionId);
      } else {
        values[definitionId] = stored;
      }
      return d.copyWith(customFieldValues: values);
    }, coalesceKey: typing ? 'custom:$definitionId' : null);
  }
}

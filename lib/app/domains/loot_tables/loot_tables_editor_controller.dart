/// The loot table editor's controller (design §8.4) over
/// [LootTableRepository].
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart';
import '../../editor/record_editor_controller.dart';
import '../../shell/shell_providers.dart';

/// One loot table draft per open record id.
final lootTableEditorProvider = AsyncNotifierProvider.autoDispose
    .family<LootTableEditorController, EditorState<LootTableDraft>, String>(
      LootTableEditorController.new,
    );

/// Loads and saves through `lootTableRepositoryProvider`, read at call
/// time so [build] watches nothing; the blockers are the core's
/// [lootTableSaveBlockers].
///
/// Every intent is one undo step, except typing: the text fields and each
/// entry's weight, minimum and maximum coalesce by field (design §8.3). A
/// reorder is one step. An entry's `conditionalFlags` are carried through
/// untouched; 0.1.6's editor had no flags UI and wiped them on every save.
class LootTableEditorController extends RecordEditorController<LootTableDraft> {
  LootTableEditorController(super.recordId);

  LootTableRepository get _repository => ref.read(lootTableRepositoryProvider);

  @override
  SaveDomain get domain => SaveDomain.lootTables;

  @override
  Future<LootTableDraft> loadDraft() => _repository.load(recordId);

  /// Trims the display name, export key and description, as 0.1.6's
  /// `handleSave` did; the read-back becomes the baseline and the draft.
  @override
  Future<LootTableDraft> saveDraft(LootTableDraft draft) => _repository.save(
    recordId,
    draft.copyWith(
      displayName: draft.displayName.trim(),
      exportKey: draft.exportKey.trim(),
      description: draft.description.trim(),
    ),
  );

  @override
  List<SaveBlocker> blockersFor(LootTableDraft draft) =>
      lootTableSaveBlockers(draft);

  @override
  String displayNameOf(LootTableDraft draft) => draft.displayName;

  /// Copies the saved loot table and its entries; the copy is a write, so
  /// the epoch is bumped once after the repository returns.
  Future<LootTableRecord> duplicate() async {
    final epoch = ref.read(writeEpochProvider.notifier);
    final copy = await _repository.duplicate(recordId);
    epoch.bump();
    return copy;
  }

  void setDisplayName(String value) =>
      edit((d) => d.copyWith(displayName: value), coalesceKey: 'displayName');

  void setExportKey(String value) =>
      edit((d) => d.copyWith(exportKey: value), coalesceKey: 'exportKey');

  void setDescription(String value) =>
      edit((d) => d.copyWith(description: value), coalesceKey: 'description');

  /// Appends [itemId] with weight 1 and quantity 1–1, as 0.1.6's
  /// `addEntry`.
  void addEntry(String itemId) => edit(
    (d) => d.copyWith(
      entries: [
        ...d.entries,
        LootTableEntryDraft(itemId: itemId, weight: 1),
      ],
    ),
  );

  void removeEntry(int index) =>
      _editEntries(index, (entries) => entries..removeAt(index));

  void setEntryItem(int index, String itemId) => _editEntries(
    index,
    (entries) => entries..[index] = entries[index].copyWith(itemId: itemId),
  );

  /// Typed into a field, so coalesced per entry row.
  void setEntryWeight(int index, int weight) => _editEntries(
    index,
    (entries) => entries..[index] = entries[index].copyWith(weight: weight),
    coalesceKey: 'entries[$index].weight',
  );

  /// Typed into a field, so coalesced per entry row.
  void setEntryQuantityMin(int index, int quantity) => _editEntries(
    index,
    (entries) =>
        entries..[index] = entries[index].copyWith(quantityMin: quantity),
    coalesceKey: 'entries[$index].quantityMin',
  );

  /// Typed into a field, so coalesced per entry row.
  void setEntryQuantityMax(int index, int quantity) => _editEntries(
    index,
    (entries) =>
        entries..[index] = entries[index].copyWith(quantityMax: quantity),
    coalesceKey: 'entries[$index].quantityMax',
  );

  /// Moves the entry at [from] to [to] (both indexes in the current list),
  /// one undo step; out-of-range or equal indexes do nothing.
  void moveEntry(int from, int to) {
    final count = state.value?.draft.entries.length ?? 0;
    if (from == to || from < 0 || to < 0 || from >= count || to >= count) {
      return;
    }
    edit((d) {
      final entries = [...d.entries];
      entries.insert(to, entries.removeAt(from));
      return d.copyWith(entries: entries);
    });
  }

  void _editEntries(
    int index,
    List<LootTableEntryDraft> Function(List<LootTableEntryDraft> entries)
    change, {
    String? coalesceKey,
  }) {
    final count = state.value?.draft.entries.length ?? 0;
    if (index < 0 || index >= count) return;
    edit(
      (d) => d.copyWith(entries: change([...d.entries])),
      coalesceKey: coalesceKey,
    );
  }
}

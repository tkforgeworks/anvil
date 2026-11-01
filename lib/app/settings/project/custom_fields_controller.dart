/// The state behind the Project Settings dialog's Custom Fields tab, which
/// persists every change immediately, as 0.1.6's `CustomFieldsSection`
/// did: the item category and NPC type lists of its left rail (ANVL-123)
/// go straight to `MetaRepository`, the field definitions to
/// `CustomFieldRepository`. Save and Cancel of the dialog do not touch it.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/editor_state.dart' show saveErrorMessage;
import '../../shell/shell_providers.dart';

/// An item category or NPC type that custom fields are scoped to.
typedef CustomFieldScopeRef = ({CustomFieldScope type, String id});

/// One row of the rail: what `MetaListSection` shows.
final class ScopeRow {
  const ScopeRow({
    required this.id,
    required this.displayName,
    required this.exportKey,
  });

  final String id;
  final String displayName;
  final String exportKey;
}

final class CustomFieldsTabState {
  const CustomFieldsTabState({
    required this.itemCategories,
    required this.npcTypes,
    required this.selected,
  });

  final List<ScopeRow> itemCategories;
  final List<ScopeRow> npcTypes;

  /// The scope whose fields the right side lists; null when there is
  /// nothing to select.
  final CustomFieldScopeRef? selected;

  List<ScopeRow> rowsOf(CustomFieldScope type) => switch (type) {
    CustomFieldScope.itemCategory => itemCategories,
    CustomFieldScope.npcType => npcTypes,
  };

  /// The selected row, resolved against the current lists so a rename
  /// shows at once.
  ScopeRow? get selectedRow {
    final s = selected;
    if (s == null) return null;
    for (final r in rowsOf(s.type)) {
      if (r.id == s.id) return r;
    }
    return null;
  }

  CustomFieldsTabState copyWith({
    List<ScopeRow>? itemCategories,
    List<ScopeRow>? npcTypes,
    CustomFieldScopeRef? selected,
  }) => CustomFieldsTabState(
    itemCategories: itemCategories ?? this.itemCategories,
    npcTypes: npcTypes ?? this.npcTypes,
    selected: selected ?? this.selected,
  );
}

final customFieldsTabProvider =
    AsyncNotifierProvider.autoDispose<
      CustomFieldsTabController,
      CustomFieldsTabState
    >(CustomFieldsTabController.new);

/// The field definitions of one scope, re-read after every write.
final customFieldDefinitionsProvider = FutureProvider.autoDispose
    .family<List<CustomFieldDefinition>, CustomFieldScopeRef>((ref, scope) {
      ref.watch(writeEpochProvider);
      return ref
          .watch(customFieldRepositoryProvider)
          .listDefinitions(scope.type, scope.id);
    });

/// Every write returns null on success or the message to show inline, and
/// bumps the write epoch once after a write that returned.
class CustomFieldsTabController extends AsyncNotifier<CustomFieldsTabState> {
  @override
  Future<CustomFieldsTabState> build() async {
    final meta = ref.watch(metaRepositoryProvider);
    return _resolve(await _lists(meta), null);
  }

  MetaRepository get _meta => ref.read(metaRepositoryProvider);

  CustomFieldRepository get _fields => ref.read(customFieldRepositoryProvider);

  static Future<(List<ScopeRow>, List<ScopeRow>)> _lists(
    MetaRepository meta,
  ) async {
    final categories = await meta.listItemCategories();
    final types = await meta.listNpcTypes();
    return (
      [
        for (final c in categories)
          ScopeRow(
            id: c.id,
            displayName: c.displayName,
            exportKey: c.exportKey,
          ),
      ],
      [
        for (final t in types)
          ScopeRow(
            id: t.id,
            displayName: t.displayName,
            exportKey: t.exportKey,
          ),
      ],
    );
  }

  /// Keeps [selected] while it exists; otherwise falls back to the first
  /// item category, as 0.1.6's effect did.
  static CustomFieldsTabState _resolve(
    (List<ScopeRow>, List<ScopeRow>) lists,
    CustomFieldScopeRef? selected,
  ) {
    final (categories, types) = lists;
    final state = CustomFieldsTabState(
      itemCategories: categories,
      npcTypes: types,
      selected: selected,
    );
    if (state.selectedRow != null) return state;
    return CustomFieldsTabState(
      itemCategories: categories,
      npcTypes: types,
      selected: categories.isEmpty
          ? null
          : (type: CustomFieldScope.itemCategory, id: categories.first.id),
    );
  }

  void select(CustomFieldScopeRef scope) {
    final s = state.value;
    if (s != null) state = AsyncData(s.copyWith(selected: scope));
  }

  Future<String?> addScopeRow(CustomFieldScope type, MetaItemInput input) =>
      _write(() async {
        switch (type) {
          case CustomFieldScope.itemCategory:
            await _meta.addItemCategory(input);
          case CustomFieldScope.npcType:
            await _meta.addNpcType(input);
        }
      });

  Future<String?> updateScopeRow(
    CustomFieldScope type,
    String id,
    MetaItemInput input,
  ) => _write(() async {
    switch (type) {
      case CustomFieldScope.itemCategory:
        await _meta.updateItemCategory(id, input);
      case CustomFieldScope.npcType:
        await _meta.updateNpcType(id, input);
    }
  });

  /// Refused with the core's `checkInUse` reason while items or NPCs use the
  /// row or fields are scoped to it (0.1.6's `meta:delete-*` reason).
  Future<String?> deleteScopeRow(CustomFieldScope type, String id) async {
    final kind = switch (type) {
      CustomFieldScope.itemCategory => MetaInUseKind.itemCategory,
      CustomFieldScope.npcType => MetaInUseKind.npcType,
    };
    final MetaInUseResult check;
    try {
      check = await _meta.checkInUse(kind, id);
    } on Object catch (e) {
      return saveErrorMessage(e);
    }
    if (check.inUse) return check.reason;
    return _write(() async {
      switch (type) {
        case CustomFieldScope.itemCategory:
          await _meta.deleteItemCategory(id);
        case CustomFieldScope.npcType:
          await _meta.deleteNpcType(id);
      }
    });
  }

  /// Moves a rail row from [from] to [to] and stores the whole order.
  Future<String?> moveScopeRow(CustomFieldScope type, int from, int to) {
    final s = state.value;
    if (s == null) return Future.value();
    final ids = [for (final r in s.rowsOf(type)) r.id];
    if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) {
      return Future.value();
    }
    ids.insert(to, ids.removeAt(from));
    return _write(() async {
      switch (type) {
        case CustomFieldScope.itemCategory:
          await _meta.reorderItemCategories(ids);
        case CustomFieldScope.npcType:
          await _meta.reorderNpcTypes(ids);
      }
    });
  }

  Future<String?> createField(CreateCustomFieldDefinitionInput input) =>
      _write(() async {
        await _fields.createDefinition(input);
      });

  Future<String?> updateField(
    String id,
    UpdateCustomFieldDefinitionInput input,
  ) => _write(() async {
    await _fields.updateDefinition(id, input);
  });

  /// Refused with the repository's `SaveBlocked` message while records hold
  /// values for the field.
  Future<String?> deleteField(String id) => _write(() async {
    await _fields.deleteDefinition(id);
  });

  /// Runs [write]; on success bumps the epoch, re-reads the rail lists
  /// (keeping the selection while it exists) and returns null; on failure
  /// returns the message and changes nothing.
  Future<String?> _write(Future<void> Function() write) async {
    final epoch = ref.read(writeEpochProvider.notifier);
    final meta = _meta;
    try {
      await write();
    } on Object catch (e) {
      return saveErrorMessage(e);
    }
    epoch.bump();
    final lists = await _lists(meta);
    if (ref.mounted) state = AsyncData(_resolve(lists, state.value?.selected));
    return null;
  }
}

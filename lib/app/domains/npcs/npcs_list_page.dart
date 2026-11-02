/// The NPCs list page (0.1.6 `NpcsPage.tsx`) on the shared list scaffold.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editor/widgets/draft_picker.dart';
import '../../lists/record_list_page.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import 'npcs_create_dialog.dart';
import 'npcs_list_adapter.dart';
import 'npcs_providers.dart';

/// The NPCs page: the scaffold's toolbar with 0.1.6's NPC Type filter
/// (`All NPC Types` first) in its filter slot, applied by the page through
/// `RecordListPage.filter`; `+ New NPC` opens the New NPC dialog and then
/// the new NPC, and Duplicate opens the copy (0.1.6 only listed it).
///
/// [onOpen] opens an NPC; `openEditor` by default, so the editing mode
/// applies.
class NpcListPage extends ConsumerStatefulWidget {
  const NpcListPage({super.key, this.onOpen});

  static const typeFilterKey = ValueKey('npcs-type-filter');

  /// 0.1.6's `minWidth: 190` on the filter.
  static const typeFilterWidth = 190.0;

  final ValueChanged<String>? onOpen;

  @override
  ConsumerState<NpcListPage> createState() => _NpcListPageState();
}

class _NpcListPageState extends ConsumerState<NpcListPage> {
  late final _adapter = NpcListAdapter(ref);
  String? _typeId;

  void _open(String id) {
    if (widget.onOpen case final onOpen?) {
      onOpen(id);
    } else {
      openEditor(context, ref, ShellDomain.npcs, id);
    }
  }

  Future<void> _create() async {
    final record = await showCreateNpcDialog(context);
    if (record != null && mounted) _open(record.id);
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(npcTypesProvider).value ?? const [];
    // A filter whose type has gone shows everything.
    final typeId = types.any((t) => t.id == _typeId) ? _typeId : null;
    // Watched so the Loot Table cells and the search have their names.
    ref.watch(npcLootTablesProvider);

    return RecordListPage<NpcRecord>(
      adapter: _adapter,
      newLabel: '+ New NPC',
      onNew: () => unawaited(_create()),
      filterSlot: SizedBox(
        width: NpcListPage.typeFilterWidth,
        child: DraftPicker<String?>(
          key: NpcListPage.typeFilterKey,
          label: 'NPC Type',
          dense: true,
          value: typeId,
          options: [
            (value: null, label: 'All NPC Types'),
            for (final t in types) (value: t.id, label: t.displayName),
          ],
          onChanged: (id) => setState(() => _typeId = id),
        ),
      ),
      filter: typeId == null ? null : (row) => row.npcTypeId == typeId,
      onOpen: _open,
      onDuplicated: (copy) => _open(copy.id),
    );
  }
}

/// The loot tables list page (0.1.6 `LootTablesPage.tsx`) on the shared
/// list scaffold.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lists/record_list_page.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import 'loot_tables_create_dialog.dart';
import 'loot_tables_list_adapter.dart';

/// The list with `+ New Loot Table`, which creates through
/// [showCreateLootTableDialog] and opens the new loot table; Duplicate
/// opens the copy (0.1.6 only appended it to the list).
///
/// [onOpen] opens a loot table; `openEditor` by default, so the editing
/// mode applies.
class LootTableListPage extends ConsumerStatefulWidget {
  const LootTableListPage({super.key, this.onOpen});

  final ValueChanged<String>? onOpen;

  @override
  ConsumerState<LootTableListPage> createState() => _LootTableListPageState();
}

class _LootTableListPageState extends ConsumerState<LootTableListPage> {
  late final _adapter = LootTableListAdapter(ref);

  void _open(String id) {
    if (widget.onOpen case final onOpen?) {
      onOpen(id);
    } else {
      openEditor(context, ref, ShellDomain.lootTables, id);
    }
  }

  Future<void> _create() async {
    final record = await showCreateLootTableDialog(context);
    if (record != null && mounted) _open(record.id);
  }

  @override
  Widget build(BuildContext context) => RecordListPage<LootTableRecord>(
    adapter: _adapter,
    onNew: () => unawaited(_create()),
    onOpen: _open,
    onDuplicated: (copy) => _open(copy.id),
  );
}

/// The Abilities list page (0.1.6 `AbilitiesPage.tsx`) on the shared list
/// scaffold.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lists/record_list_page.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import 'abilities_list_adapter.dart';
import 'create_ability_dialog.dart';

/// The list with `+ New Ability`, which creates through
/// [showCreateAbilityDialog] and opens the new ability; Duplicate opens the
/// copy (0.1.6 only appended it to the list).
class AbilityListPage extends ConsumerStatefulWidget {
  const AbilityListPage({super.key});

  @override
  ConsumerState<AbilityListPage> createState() => _AbilityListPageState();
}

class _AbilityListPageState extends ConsumerState<AbilityListPage> {
  late final _adapter = AbilityListAdapter(ref.read);

  void _open(String id) => openEditor(context, ref, ShellDomain.abilities, id);

  Future<void> _create() async {
    final record = await showCreateAbilityDialog(context);
    if (record != null && mounted) _open(record.id);
  }

  @override
  Widget build(BuildContext context) => RecordListPage<AbilityRecord>(
    adapter: _adapter,
    onNew: () => unawaited(_create()),
    onDuplicated: (copy) => _open(copy.id),
  );
}

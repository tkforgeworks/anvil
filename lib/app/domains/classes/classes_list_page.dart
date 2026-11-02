/// The Classes list page (0.1.6 `ClassesPage.tsx`) on the shared list
/// scaffold.
library;

import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lists/record_list_page.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import 'classes_create_dialog.dart';
import 'classes_list_adapter.dart';

/// The list with `+ New Class`, which creates through
/// [showCreateClassDialog] and opens the new class; Duplicate opens the
/// copy (0.1.6 only appended it to the list).
class ClassListPage extends ConsumerStatefulWidget {
  const ClassListPage({super.key});

  @override
  ConsumerState<ClassListPage> createState() => _ClassListPageState();
}

class _ClassListPageState extends ConsumerState<ClassListPage> {
  late final _adapter = ClassListAdapter(ref.read);

  void _open(String id) => openEditor(context, ref, ShellDomain.classes, id);

  Future<void> _create() async {
    final record = await showCreateClassDialog(context);
    if (record != null && mounted) _open(record.id);
  }

  @override
  Widget build(BuildContext context) => RecordListPage<ClassRecord>(
    adapter: _adapter,
    onNew: () => unawaited(_create()),
    onDuplicated: (copy) => _open(copy.id),
    // 0.1.6's empty-state body.
    emptyBody: 'Create your first character class to get started.',
  );
}

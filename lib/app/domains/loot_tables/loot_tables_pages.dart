/// The loot table pages as the shell's registry builds them
/// (`listPageBuilders[ShellDomain.lootTables]` and
/// `editorBuilders[ShellDomain.lootTables]` in `placeholders.dart`).
library;

import 'package:flutter/widgets.dart';

import 'loot_tables_editor_page.dart';
import 'loot_tables_list_page.dart';

/// The list at `/loot-tables`.
Widget lootTablesListPage() => const LootTableListPage();

/// The editor of loot table [id]: the `/loot-tables/:id` page and the
/// modal editor dialog's body.
Widget lootTableEditor(String id) => LootTableEditorPage(id, key: ValueKey(id));

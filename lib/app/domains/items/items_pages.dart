/// The items domain's two pages for the shell's registry
/// (`listPageBuilders[ShellDomain.items]` and
/// `editorBuilders[ShellDomain.items]` in `shell/placeholders.dart`).
library;

import 'package:flutter/widgets.dart';

import 'items_editor_page.dart';
import 'items_list_page.dart';

/// The list at `/items`.
Widget itemsListPage() => const ItemListPage();

/// The editor of item [id], at `/items/:id` and in the editor dialog.
Widget itemEditor(String id) => ItemEditorPage(id, key: ValueKey(id));

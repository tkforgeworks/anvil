/// The NPCs domain's two pages for the shell's registry
/// (`listPageBuilders[ShellDomain.npcs]` and
/// `editorBuilders[ShellDomain.npcs]` in `shell/placeholders.dart`).
library;

import 'package:flutter/widgets.dart';

import 'npcs_editor_page.dart';
import 'npcs_list_page.dart';

/// The list at `/npcs`.
Widget npcsListPage() => const NpcListPage();

/// The editor of NPC [id], at `/npcs/:id` and in the editor dialog.
Widget npcEditor(String id) => NpcEditorPage(id, key: ValueKey(id));

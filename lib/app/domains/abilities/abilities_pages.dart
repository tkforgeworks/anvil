/// The Abilities pages for the shell's registry (`placeholders.dart`
/// `listPageBuilders` and `editorBuilders`).
library;

import 'package:flutter/widgets.dart';

import 'abilities_editor_page.dart';
import 'abilities_list_page.dart';

/// The list at `/abilities`.
Widget abilitiesListPage() => const AbilityListPage();

/// The editor of ability [id], at `/abilities/:id` and in the editor
/// dialog.
Widget abilityEditor(String id) => AbilityEditorPage(id, key: ValueKey(id));

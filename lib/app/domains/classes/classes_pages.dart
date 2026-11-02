/// The Classes pages for the shell's registry (`placeholders.dart`
/// `listPageBuilders` and `editorBuilders`).
library;

import 'package:flutter/widgets.dart';

import 'classes_editor_page.dart';
import 'classes_list_page.dart';

/// The list at `/classes`.
Widget classesListPage() => const ClassListPage();

/// The editor of class [id], at `/classes/:id` and in the editor dialog.
Widget classEditor(String id) => ClassEditorPage(id, key: ValueKey(id));

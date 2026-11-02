/// The recipe pages as the shell's registry builds them
/// (`listPageBuilders[ShellDomain.recipes]` and
/// `editorBuilders[ShellDomain.recipes]` in `placeholders.dart`).
library;

import 'package:flutter/widgets.dart';

import 'recipes_editor_page.dart';
import 'recipes_list_page.dart';

/// The list at `/recipes`.
Widget recipesListPage() => const RecipeListPage();

/// The editor of recipe [id]: the `/recipes/:id` page and the modal editor
/// dialog's body.
Widget recipeEditor(String id) => RecipeEditorPage(id: id, key: ValueKey(id));

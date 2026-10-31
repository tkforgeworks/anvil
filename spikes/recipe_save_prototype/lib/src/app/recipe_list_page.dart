import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'recipe_editor_page.dart';

class RecipeListPage extends ConsumerWidget {
  const RecipeListPage({super.key, required this.workingCopyPath});

  final String workingCopyPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipeListProvider);
    final history = ref.watch(saveHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: ListView(
        children: [
          ListTile(
            dense: true,
            title: const Text('Working copy'),
            subtitle: Text(workingCopyPath),
          ),
          const Divider(),
          ...switch (recipes) {
            AsyncValue(:final value?) => [
              for (final recipe in value)
                ListTile(
                  key: Key('recipe-${recipe.id}'),
                  title: Text(recipe.displayName),
                  subtitle: Text(recipe.exportKey),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecipeEditorPage(recipeId: recipe.id),
                    ),
                  ),
                ),
            ],
            AsyncValue(:final error?) => [
              Text('Could not list recipes: $error'),
            ],
            _ => [const LinearProgressIndicator()],
          },
          const Divider(),
          const ListTile(
            dense: true,
            title: Text('Recent saves (save_history)'),
          ),
          ...switch (history) {
            AsyncValue(:final value?) => [
              for (final (i, entry) in value.indexed)
                ListTile(
                  key: Key('history-$i'),
                  dense: true,
                  title: Text(entry.description),
                  subtitle: Text(
                    '${entry.savedAt}${entry.isAutoSave ? ' (auto-save)' : ''}',
                  ),
                ),
            ],
            _ => const <Widget>[],
          },
        ],
      ),
    );
  }
}

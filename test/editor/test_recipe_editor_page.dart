/// A minimal record editor page over [RecipeEditorControllerForTest], the
/// shape a domain editor (ANVL-191 to 197) wraps in [RecordEditorScope]:
/// a display-name field whose text follows the draft, a structural edit
/// button and a dirty marker.
library;

import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/record_editor_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'test_recipe_editor.dart';

class TestRecipeEditorPage extends ConsumerWidget {
  const TestRecipeEditorPage({
    super.key,
    required this.recordId,
    this.onSaveOutcome,
  });

  final String recordId;
  final ValueChanged<SaveOutcome>? onSaveOutcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = testRecipeEditorProvider(recordId);
    final state = ref.watch(provider).value;
    final controller = ref.read(provider.notifier);
    return RecordEditorScope(
      provider: provider,
      onSaveOutcome: onSaveOutcome,
      child: state == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(state.draft.displayName, key: const Key('title')),
                    if (state.isDirty)
                      const Icon(
                        Icons.circle,
                        key: Key('dirty-marker'),
                        size: 10,
                      ),
                  ],
                ),
                _DraftField(
                  key: const Key('field-displayName'),
                  value: state.draft.displayName,
                  onChanged: controller.setDisplayName,
                ),
                // A non-interactive target for a click outside the fields.
                const Text('Ingredients'),
                Text(
                  '${state.draft.ingredients.length}',
                  key: const Key('ingredient-count'),
                ),
                TextButton(
                  key: const Key('add-ingredient'),
                  onPressed: () => controller.addIngredient(
                    'item-extra-${state.draft.ingredients.length}',
                  ),
                  child: const Text('Add ingredient'),
                ),
              ],
            ),
    );
  }
}

/// The spike's `DraftTextField`: typing goes out through [onChanged]
/// (which also carries the field's own undo, applied as a user edit);
/// draft changes are written into the controller when they differ.
class _DraftField extends StatefulWidget {
  const _DraftField({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_DraftField> createState() => _DraftFieldState();
}

class _DraftFieldState extends State<_DraftField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_DraftField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: _controller, onChanged: widget.onChanged);
}

/// The class editor's Abilities tab (0.1.6 `AbilityAssignmentPanel.tsx`)
/// over the draft's ordered `abilityIds`.
library;

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../../editor/widgets/draft_picker.dart';
import '../../shell/open_editor.dart';
import '../../shell/shell_domain.dart';
import '../../theme/anvil_metrics.dart';
import 'classes_editor_controller.dart';
import 'classes_providers.dart';

/// The assigned abilities in order, each with up / down / remove and its
/// name as a link to the ability editor (through [openEditor], so the
/// editing mode applies), a `Deleted` warning on a soft-deleted ability,
/// and below them a picker of the active abilities not yet assigned with
/// an Add button. 0.1.6's search-as-you-type `Autocomplete` becomes a
/// [DraftPicker] (design §8.7), and every change is a draft edit saved
/// with the class instead of an immediate IPC write.
class ClassAbilityPanel extends ConsumerStatefulWidget {
  const ClassAbilityPanel({
    super.key,
    required this.abilityIds,
    required this.controller,
  });

  final List<String> abilityIds;
  final ClassEditorController controller;

  static const pickerKey = ValueKey('class-ability-picker');
  static const addKey = ValueKey('class-ability-add');
  static const emptyKey = ValueKey('class-ability-empty');

  /// 0.1.6's tooltip on the `Deleted` chip.
  static const deletedTooltip = 'This ability has been soft-deleted';

  static const emptyMessage =
      'No abilities assigned. Use the picker below to add one.';

  static Key rowKey(String abilityId) =>
      ValueKey('class-ability-row-$abilityId');
  static Key linkKey(String abilityId) =>
      ValueKey('class-ability-link-$abilityId');
  static Key deletedKey(String abilityId) =>
      ValueKey('class-ability-deleted-$abilityId');
  static Key upKey(int index) => ValueKey('class-ability-$index-up');
  static Key downKey(int index) => ValueKey('class-ability-$index-down');
  static Key removeKey(int index) => ValueKey('class-ability-$index-remove');

  @override
  ConsumerState<ClassAbilityPanel> createState() => _ClassAbilityPanelState();
}

class _ClassAbilityPanelState extends ConsumerState<ClassAbilityPanel> {
  /// The ability chosen in the picker, added by the Add button.
  String? _pending;

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(classAbilitiesProvider);
    final abilities = loaded.value;
    if (abilities == null) {
      if (loaded.hasError) {
        return Text(
          'Failed to load the project\'s abilities.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.error),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final byId = {for (final a in abilities) a.id: a};
    final ids = widget.abilityIds;
    final assigned = ids.toSet();
    final active = [
      for (final a in abilities)
        if (a.deletedAt == null) a,
    ];
    final options = <PickerOption<String?>>[
      for (final a in active)
        if (!assigned.contains(a.id)) (value: a.id, label: a.displayName),
    ];
    // A choice that was assigned meanwhile (undo, redo) is no longer one.
    final pending = options.any((o) => o.value == _pending) ? _pending : null;
    final c = context.colors;
    final border = BorderSide(color: c.outlineVariant);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(border),
              borderRadius: BorderRadius.circular(AnvilRadii.panel),
            ),
            child: ids.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AnvilSpacing.lg),
                    child: Text(
                      ClassAbilityPanel.emptyMessage,
                      key: ClassAbilityPanel.emptyKey,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, id) in ids.indexed) ...[
                        if (i > 0) Divider(height: 1, color: c.outlineVariant),
                        _AbilityRow(
                          key: ClassAbilityPanel.rowKey(id),
                          index: i,
                          count: ids.length,
                          abilityId: id,
                          ability: byId[id],
                          controller: widget.controller,
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AnvilSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 400,
                child: DraftPicker<String?>(
                  key: ClassAbilityPanel.pickerKey,
                  label: 'Add ability',
                  dense: true,
                  value: pending,
                  options: options,
                  onChanged: options.isEmpty
                      ? null
                      : (v) => setState(() => _pending = v),
                  helperText: options.isNotEmpty
                      ? null
                      : active.isEmpty
                      ? 'No abilities exist yet'
                      : 'All abilities are assigned',
                ),
              ),
              const SizedBox(width: AnvilSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: AnvilSpacing.xs),
                child: OutlinedButton(
                  key: ClassAbilityPanel.addKey,
                  onPressed: pending == null
                      ? null
                      : () {
                          widget.controller.addAbility(pending);
                          setState(() => _pending = null);
                        },
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbilityRow extends ConsumerWidget {
  const _AbilityRow({
    super.key,
    required this.index,
    required this.count,
    required this.abilityId,
    required this.ability,
    required this.controller,
  });

  final int index;
  final int count;
  final String abilityId;

  /// Null for an id no ability has (0.1.6's `[Unknown: id]`).
  final AbilityRecord? ability;
  final ClassEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final forge = context.forge;
    final ability = this.ability;
    final deleted = ability?.deletedAt != null;
    final name = Text(
      ability?.displayName ?? '[Unknown: $abilityId]',
      style: context.text.bodyMedium?.copyWith(
        color: deleted || ability == null ? c.onSurfaceVariant : c.onSurface,
      ),
      overflow: TextOverflow.ellipsis,
    );
    final i = index;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AnvilSpacing.md,
        vertical: AnvilSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: ability == null
                      ? name
                      : InkWell(
                          key: ClassAbilityPanel.linkKey(abilityId),
                          onTap: () => openEditor(
                            context,
                            ref,
                            ShellDomain.abilities,
                            abilityId,
                          ),
                          child: name,
                        ),
                ),
                if (deleted) ...[
                  const SizedBox(width: AnvilSpacing.sm),
                  Tooltip(
                    message: ClassAbilityPanel.deletedTooltip,
                    child: Chip(
                      key: ClassAbilityPanel.deletedKey(abilityId),
                      avatar: Icon(
                        Icons.warning,
                        size: 16,
                        color: forge.warning,
                      ),
                      label: const Text('Deleted'),
                      labelStyle: context.text.labelSmall?.copyWith(
                        color: forge.warning,
                      ),
                      side: BorderSide(color: forge.warning),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: ClassAbilityPanel.upKey(i),
            tooltip: 'Move up',
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: i == 0 ? null : () => controller.moveAbility(i, i - 1),
          ),
          IconButton(
            key: ClassAbilityPanel.downKey(i),
            tooltip: 'Move down',
            icon: const Icon(Icons.arrow_downward, size: 18),
            onPressed: i == count - 1
                ? null
                : () => controller.moveAbility(i, i + 1),
          ),
          IconButton(
            key: ClassAbilityPanel.removeKey(i),
            tooltip: 'Remove assignment',
            color: c.error,
            icon: const Icon(Icons.delete, size: 18),
            onPressed: () => controller.removeAbility(abilityId),
          ),
        ],
      ),
    );
  }
}

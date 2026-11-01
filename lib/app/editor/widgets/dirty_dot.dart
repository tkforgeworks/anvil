/// The per-tab unsaved-changes marker (0.1.6 `DirtyDot.tsx` and
/// `useTabDirtyTracking.ts`, design §13.7).
library;

import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

/// A 7 px warning-coloured dot after a tab label whose fields differ from
/// the saved record, as 0.1.6 drew it (`width: 7`, `warning.main`, 6 px
/// left margin). Builds nothing while [visible] is false.
class DirtyDot extends StatelessWidget {
  const DirtyDot({super.key, required this.visible});

  static const size = 7.0;

  /// 0.1.6's `ml: 0.75`.
  static const gap = 6.0;

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: gap),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.forge.warning,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The tabs whose fields differ between [baseline] and [draft]: the keys of
/// [tabFields] whose equality test returns false. Each test compares the
/// fields its tab edits, for example
///
/// ```dart
/// final dirty = dirtyTabs<AbilityDraft>(state.baseline, state.draft, {
///   'details': (a, b) => a.description == b.description,
///   'modifiers': (a, b) => listEquals(a.statModifiers, b.statModifiers),
/// });
/// Tab(child: Row(children: [
///   const Text('Details'),
///   DirtyDot(visible: dirty.contains('details')),
/// ]));
/// ```
///
/// Pass the type argument: the closures sit inside a map literal, where
/// Dart does not infer their parameter types from [baseline].
///
/// 0.1.6 compared the listed fields through `JSON.stringify`; drafts are
/// value-equal, so `==` on the fields does the same.
Set<String> dirtyTabs<T>(
  T baseline,
  T draft,
  Map<String, bool Function(T a, T b)> tabFields,
) => {
  for (final MapEntry(key: tab, value: same) in tabFields.entries)
    if (!same(baseline, draft)) tab,
};

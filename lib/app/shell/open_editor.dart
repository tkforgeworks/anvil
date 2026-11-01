import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import 'editor_dialog.dart';
import 'placeholders.dart';
import 'shell_domain.dart';

/// Opens record [id] of [domain] the way the editing mode setting says
/// (design §13.2; 0.1.6's `openEditor` in each list page): full page
/// navigates to the editor route, modal shows the same editor widget in an
/// [EditorDialog] over the current page, whose location does not change.
///
/// The setting is read at call time, so a change applies to the next open.
/// Leaving a dirty editor is guarded where it is left, not here: by the
/// editor route's `onExit` in full page (another record included), by the
/// dialog's `PopScope` in modal.
void openEditor(
  BuildContext context,
  WidgetRef ref,
  ShellDomain domain,
  String id,
) {
  switch (ref.read(appSettingsProvider).editingMode) {
    case EditingMode.fullPage:
      context.go(domain.editorLocation(id));
    case EditingMode.modal:
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => EditorDialog(
            domain: domain,
            id: id,
            child: editorBuilders[domain]!(id),
          ),
        ),
      );
  }
}

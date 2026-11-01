/// The Application Settings dialog's Shortcuts tab (0.1.6 `ShortcutsTab` in
/// `AppSettingsModal.tsx`, design §13.5): every registry entry with the
/// binding in effect, click-to-capture rebinding, a per-row reset and Reset
/// All, all written through the app settings notifier at once.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';

import '../menu/kbd_pill.dart';
import '../menu/shortcut_registry.dart';
import '../providers.dart';
import '../theme/anvil_metrics.dart';

/// What one key press during a capture means.
sealed class ShortcutCapture {
  const ShortcutCapture();
}

/// A modifier on its own: keep waiting for the key.
final class CaptureIgnored extends ShortcutCapture {
  const CaptureIgnored();
}

/// Escape: stop capturing without a change.
final class CaptureCancelled extends ShortcutCapture {
  const CaptureCancelled();
}

/// A press that cannot become a binding; [message] says why.
final class CaptureRefused extends ShortcutCapture {
  const CaptureRefused(this.message);

  final String message;
}

/// A binding string [parseBinding] accepts, such as `Ctrl+Shift+Z`.
final class CaptureBinding extends ShortcutCapture {
  const CaptureBinding(this.binding);

  final String binding;
}

/// 0.1.6's refusal for a key pressed with no modifier.
const mustIncludeModifierMessage = 'Shortcut must include Ctrl, Shift, or Alt';

/// The refusal for a key the binding grammar has no name for.
const unsupportedKeyMessage = 'This key cannot be used in a shortcut';

final _modifierKeys = {
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.altGraph,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
};

/// The named keys, by the 0.1.6 `KeyboardEvent.key` name `formatKeyCombo`
/// wrote and [parseBinding] reads back.
final Map<LogicalKeyboardKey, String> _keyNames = {
  LogicalKeyboardKey.enter: 'Enter',
  LogicalKeyboardKey.tab: 'Tab',
  LogicalKeyboardKey.backspace: 'Backspace',
  LogicalKeyboardKey.delete: 'Delete',
  LogicalKeyboardKey.insert: 'Insert',
  LogicalKeyboardKey.home: 'Home',
  LogicalKeyboardKey.end: 'End',
  LogicalKeyboardKey.pageUp: 'PageUp',
  LogicalKeyboardKey.pageDown: 'PageDown',
  LogicalKeyboardKey.arrowUp: 'ArrowUp',
  LogicalKeyboardKey.arrowDown: 'ArrowDown',
  LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
  LogicalKeyboardKey.arrowRight: 'ArrowRight',
  ..._functionKeys,
};

final Map<LogicalKeyboardKey, String> _functionKeys = {
  for (final (i, key) in const [
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
    LogicalKeyboardKey.f9,
    LogicalKeyboardKey.f10,
    LogicalKeyboardKey.f11,
    LogicalKeyboardKey.f12,
  ].indexed)
    key: 'F${i + 1}',
};

/// The printable keys a binding may end in (the registry's grammar).
final _printable = RegExp(r"^[a-z0-9=\-/,.;'\[\]\\`]$");

/// Turns a key pressed during a capture into a [ShortcutCapture], as
/// 0.1.6's `handleCapture` + `formatKeyCombo` did: modifiers alone are
/// ignored, Escape cancels (with or without modifiers), a key needs Ctrl,
/// Shift or Alt unless it is F1-F12, and the binding is written
/// `Ctrl+Shift+Alt+Key` with a printable key upper-cased.
///
/// [control] means the Control key only; 0.1.6 also counted Meta, which
/// [parseBinding] does not. A key the binding grammar cannot name (Space,
/// the keypad, media keys) is refused where 0.1.6 stored a binding the
/// shortcut layer then ignored.
ShortcutCapture captureBinding(
  LogicalKeyboardKey key, {
  required bool control,
  required bool shift,
  required bool alt,
}) {
  if (_modifierKeys.contains(key)) return const CaptureIgnored();
  if (key == LogicalKeyboardKey.escape) return const CaptureCancelled();
  if (!control && !shift && !alt && !_functionKeys.containsKey(key)) {
    return const CaptureRefused(mustIncludeModifierMessage);
  }
  final String? name;
  final id = key.keyId;
  if (id < 0x80 && _printable.hasMatch(String.fromCharCode(id))) {
    name = String.fromCharCode(id).toUpperCase();
  } else {
    name = _keyNames[key];
  }
  if (name == null) return const CaptureRefused(unsupportedKeyMessage);
  final binding = [
    if (control) 'Ctrl',
    if (shift) 'Shift',
    if (alt) 'Alt',
    name,
  ].join('+');
  return parseBinding(binding) == null
      ? const CaptureRefused(unsupportedKeyMessage)
      : CaptureBinding(binding);
}

/// 0.1.6's `Conflicts with "<label>"` when [binding] is already in effect
/// for an entry other than [id], or null. Bindings are compared by the key
/// they mean, so `Ctrl+z` and `Ctrl+Z` collide.
String? captureConflict(
  String id,
  String binding,
  List<ShortcutBinding> bindings,
) {
  final activator = parseBinding(binding);
  if (activator == null) return null;
  for (final b in bindings) {
    if (b.entry.id != id && sameKey(b.activator, activator)) {
      return 'Conflicts with "${b.entry.label}"';
    }
  }
  return null;
}

/// Whether [a] and [b] are the same key with the same modifiers
/// (`SingleActivator` has no value equality).
bool sameKey(SingleActivator a, SingleActivator b) =>
    a.trigger == b.trigger &&
    a.control == b.control &&
    a.shift == b.shift &&
    a.alt == b.alt &&
    a.meta == b.meta;

/// The Shortcuts tab. Clicking a binding starts a capture; the next key
/// press (with Ctrl, Shift or Alt) becomes the override, a press equal to
/// the default removes it, Escape or moving focus away cancels.
class ShortcutOverridesSection extends ConsumerStatefulWidget {
  const ShortcutOverridesSection({super.key});

  @override
  ConsumerState<ShortcutOverridesSection> createState() =>
      _ShortcutOverridesSectionState();
}

class _ShortcutOverridesSectionState
    extends ConsumerState<ShortcutOverridesSection> {
  final _captureFocus = FocusNode(debugLabel: 'shortcut capture');
  String? _capturingId;
  String? _error;

  @override
  void dispose() {
    _captureFocus.dispose();
    super.dispose();
  }

  void _startCapture(String id) {
    setState(() {
      _capturingId = id;
      _error = null;
    });
    _captureFocus.requestFocus();
  }

  void _stopCapture() {
    if (_capturingId == null) return;
    setState(() => _capturingId = null);
    if (_captureFocus.hasFocus) _captureFocus.unfocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final id = _capturingId;
    if (id == null) return KeyEventResult.ignored;
    // Swallow every event while capturing, so no other shortcut runs.
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final keyboard = HardwareKeyboard.instance;
    final capture = captureBinding(
      event.logicalKey,
      control: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
    );
    switch (capture) {
      case CaptureIgnored():
        break;
      case CaptureCancelled():
        setState(() => _error = null);
        _stopCapture();
      case CaptureRefused(:final message):
        setState(() => _error = message);
      case CaptureBinding(:final binding):
        final conflict = captureConflict(
          id,
          binding,
          ref.read(shortcutBindingsProvider),
        );
        if (conflict != null) {
          setState(() => _error = conflict);
          break;
        }
        final entry = shortcutRegistry.firstWhere((e) => e.id == id);
        final isDefault = sameKey(
          parseBinding(entry.defaultBinding)!,
          parseBinding(binding)!,
        );
        ref
            .read(appSettingsProvider.notifier)
            .setCustomShortcut(id, isDefault ? null : binding);
        setState(() => _error = null);
        _stopCapture();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final bindings = ref.watch(shortcutBindingsProvider);
    final custom = ref.watch(
      appSettingsProvider.select((s) => s.customShortcuts),
    );
    final notifier = ref.read(appSettingsProvider.notifier);
    final hasOverride = custom != null && custom.isNotEmpty;
    final text = context.text;

    return Focus(
      focusNode: _captureFocus,
      // Focused only by a click on a binding, never by Tab.
      skipTraversal: true,
      onKeyEvent: _onKey,
      onFocusChange: (focused) {
        if (!focused) _stopCapture();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Keyboard Shortcuts', style: text.titleSmall),
              ),
              if (hasOverride)
                TextButton.icon(
                  key: const ValueKey('shortcuts-reset-all'),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset All'),
                  onPressed: () {
                    _stopCapture();
                    notifier.clearCustomShortcuts();
                  },
                ),
            ],
          ),
          const SizedBox(height: AnvilSpacing.sm),
          Text(
            'Click a binding to re-assign it. Press Escape to cancel.',
            style: text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: AnvilSpacing.md),
            ForgeErrorCard(
              key: const ValueKey('shortcut-capture-error'),
              message: error,
              retryLabel: 'Dismiss',
              onRetry: () => setState(() => _error = null),
            ),
          ],
          for (final group in ShortcutGroup.values)
            if (bindings.where((b) => b.entry.group == group).toList()
                case final entries when entries.isNotEmpty) ...[
              const SizedBox(height: AnvilSpacing.md),
              Padding(
                padding: const EdgeInsets.only(bottom: AnvilSpacing.xs),
                child: Text(
                  group.label.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              for (final b in entries)
                _ShortcutRow(
                  binding: b,
                  overridden: custom?[b.entry.id] != null,
                  capturing: _capturingId == b.entry.id,
                  onCapture: () => _startCapture(b.entry.id),
                  onReset: () {
                    _stopCapture();
                    notifier.setCustomShortcut(b.entry.id, null);
                  },
                ),
            ],
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.binding,
    required this.overridden,
    required this.capturing,
    required this.onCapture,
    required this.onReset,
  });

  /// Room for the reset button, kept on rows without one so the bindings
  /// line up.
  static const _resetWidth = 40.0;

  final ShortcutBinding binding;
  final bool overridden;
  final bool capturing;
  final VoidCallback onCapture;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final id = binding.entry.id;
    final colors = context.colors;
    return DecoratedBox(
      key: ValueKey('shortcut-row-$id'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AnvilSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(binding.entry.label, style: context.text.bodyMedium),
            ),
            InkWell(
              key: ValueKey('shortcut-binding-$id'),
              onTap: onCapture,
              borderRadius: BorderRadius.circular(AnvilRadii.control),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: capturing || overridden
                        ? colors.primary
                        : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(AnvilRadii.control),
                ),
                child: KbdPill(capturing ? 'Press keys…' : binding.binding),
              ),
            ),
            SizedBox(
              width: _resetWidth,
              child: overridden
                  ? IconButton(
                      key: ValueKey('shortcut-reset-$id'),
                      tooltip: 'Reset to ${binding.entry.defaultBinding}',
                      iconSize: 18,
                      icon: const Icon(Icons.restart_alt),
                      onPressed: onReset,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

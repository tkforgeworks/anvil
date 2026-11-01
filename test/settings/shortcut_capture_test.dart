import 'package:anvil/app/menu/shortcut_registry.dart';
import 'package:anvil/app/settings/shortcut_overrides_section.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ShortcutCapture press(
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
  bool alt = false,
}) => captureBinding(key, control: control, shift: shift, alt: alt);

String? bound(ShortcutCapture c) => c is CaptureBinding ? c.binding : null;

void main() {
  group('captureBinding', () {
    test('a modifier on its own keeps waiting', () {
      for (final key in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftRight,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        expect(press(key, control: true), isA<CaptureIgnored>());
      }
    });

    test('Escape cancels, with or without modifiers', () {
      expect(press(LogicalKeyboardKey.escape), isA<CaptureCancelled>());
      expect(
        press(LogicalKeyboardKey.escape, control: true),
        isA<CaptureCancelled>(),
      );
    });

    test('a key without Ctrl, Shift or Alt is refused unless it is F1-F12', () {
      final refused = press(LogicalKeyboardKey.keyK);
      expect(refused, isA<CaptureRefused>());
      expect(
        (refused as CaptureRefused).message,
        'Shortcut must include Ctrl, Shift, or Alt',
      );
      expect(bound(press(LogicalKeyboardKey.f5)), 'F5');
      expect(bound(press(LogicalKeyboardKey.f12)), 'F12');
    });

    test(
      'writes modifiers in 0.1.6 order with a printable key upper-cased',
      () {
        expect(
          bound(press(LogicalKeyboardKey.keyZ, control: true, shift: true)),
          'Ctrl+Shift+Z',
        );
        expect(
          bound(
            press(
              LogicalKeyboardKey.keyE,
              control: true,
              shift: true,
              alt: true,
            ),
          ),
          'Ctrl+Shift+Alt+E',
        );
        expect(bound(press(LogicalKeyboardKey.digit3, alt: true)), 'Alt+3');
        expect(bound(press(LogicalKeyboardKey.equal, control: true)), 'Ctrl+=');
        expect(bound(press(LogicalKeyboardKey.comma, control: true)), 'Ctrl+,');
        expect(bound(press(LogicalKeyboardKey.slash, control: true)), 'Ctrl+/');
        expect(
          bound(press(LogicalKeyboardKey.arrowUp, control: true)),
          'Ctrl+ArrowUp',
        );
        expect(
          bound(press(LogicalKeyboardKey.pageDown, shift: true)),
          'Shift+PageDown',
        );
      },
    );

    test('every binding it produces parses to the key that was pressed', () {
      final keys = [
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.bracketLeft,
        LogicalKeyboardKey.backslash,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.delete,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.f1,
      ];
      for (final key in keys) {
        final binding = bound(press(key, control: true, alt: true))!;
        final activator = parseBinding(binding)!;
        expect(activator.trigger, key, reason: binding);
        expect(activator.control && activator.alt && !activator.shift, isTrue);
      }
    });

    test('a key the binding grammar cannot name is refused', () {
      final refused = press(LogicalKeyboardKey.space, control: true);
      expect(refused, isA<CaptureRefused>());
      expect(
        (refused as CaptureRefused).message,
        'This key cannot be used in a shortcut',
      );
      expect(
        press(LogicalKeyboardKey.numpad1, control: true),
        isA<CaptureRefused>(),
      );
    });
  });

  group('captureConflict', () {
    final bindings = effectiveBindings(shortcutRegistry, {
      'export': 'Ctrl+Shift+E',
    });

    test('names the entry that already has the binding', () {
      expect(
        captureConflict('export', 'Ctrl+B', bindings),
        'Conflicts with "Toggle Sidebar"',
      );
      expect(
        captureConflict('save', 'Ctrl+Shift+E', bindings),
        'Conflicts with "Export…"',
      );
    });

    test('compares keys, not strings', () {
      expect(
        captureConflict('export', 'Ctrl+b', bindings),
        'Conflicts with "Toggle Sidebar"',
      );
    });

    test('the entry\'s own binding and a free one do not conflict', () {
      expect(captureConflict('export', 'Ctrl+Shift+E', bindings), isNull);
      // The default Ctrl+E is free again once export is overridden.
      expect(captureConflict('save', 'Ctrl+E', bindings), isNull);
      expect(captureConflict('export', 'Ctrl+Alt+Q', bindings), isNull);
    });
  });
}

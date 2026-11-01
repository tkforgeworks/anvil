import 'package:anvil/app/menu/menu_commands.dart';
import 'package:anvil/app/menu/shortcut_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the registry holds the 0.1.6 entries with their ids, labels, groups '
      'and default bindings, in order', () {
    expect(
      [
        for (final e in shortcutRegistry)
          '${e.id}|${e.label}|${e.group.label}|${e.defaultBinding}',
      ],
      [
        'new-project|New Project…|File|Ctrl+N',
        'open-project|Open Project…|File|Ctrl+O',
        'save|Save|File|Ctrl+S',
        'save-as|Save As…|File|Ctrl+Shift+S',
        'close-project|Close Project|File|Ctrl+W',
        'nav-dashboard|Dashboard|Navigation|Ctrl+1',
        'nav-classes|Classes|Navigation|Ctrl+2',
        'nav-abilities|Abilities|Navigation|Ctrl+3',
        'nav-items|Items|Navigation|Ctrl+4',
        'nav-recipes|Recipes|Navigation|Ctrl+5',
        'nav-npcs|NPCs|Navigation|Ctrl+6',
        'nav-loot-tables|Loot Tables|Navigation|Ctrl+7',
        'undo|Undo|Editing|Ctrl+Z',
        'redo|Redo|Editing|Ctrl+Shift+Z',
        'toggle-sidebar|Toggle Sidebar|View|Ctrl+B',
        'validation-panel|Validation Panel|View|Ctrl+Shift+V',
        'zoom-in|Zoom In|View|Ctrl+=',
        'zoom-out|Zoom Out|View|Ctrl+-',
        'zoom-reset|Reset Zoom|View|Ctrl+0',
        'project-settings|Project Settings|Project|Ctrl+,',
        'export|Export…|Project|Ctrl+E',
        'documentation|Documentation|Help|F1',
        'keyboard-shortcuts|Keyboard Shortcuts|Help|Ctrl+/',
      ],
    );
  });

  group('parseBinding', () {
    void expectBinding(
      String binding,
      LogicalKeyboardKey key, {
      bool control = false,
      bool shift = false,
      bool alt = false,
    }) {
      final a = parseBinding(binding);
      expect(a, isNotNull, reason: binding);
      expect(a!.trigger, key, reason: binding);
      expect(
        (a.control, a.shift, a.alt, a.meta),
        (control, shift, alt, false),
        reason: binding,
      );
    }

    test('parses every default binding', () {
      for (final e in shortcutRegistry) {
        expect(parseBinding(e.defaultBinding), isNotNull, reason: e.id);
      }
      expectBinding('Ctrl+S', LogicalKeyboardKey.keyS, control: true);
      expectBinding(
        'Ctrl+Shift+Z',
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      );
      expectBinding('Ctrl+=', LogicalKeyboardKey.equal, control: true);
      expectBinding('Ctrl+-', LogicalKeyboardKey.minus, control: true);
      expectBinding('Ctrl+0', LogicalKeyboardKey.digit0, control: true);
      expectBinding('Ctrl+,', LogicalKeyboardKey.comma, control: true);
      expectBinding('Ctrl+/', LogicalKeyboardKey.slash, control: true);
      expectBinding('F1', LogicalKeyboardKey.f1);
    });

    test('the key is case-insensitive and modifiers come in any order, as '
        'useGlobalShortcuts compared them', () {
      expectBinding('Ctrl+z', LogicalKeyboardKey.keyZ, control: true);
      expectBinding(
        'Shift+Ctrl+Z',
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      );
      expectBinding('Alt+f12', LogicalKeyboardKey.f12, alt: true);
      expectBinding('Ctrl+Enter', LogicalKeyboardKey.enter, control: true);
      expectBinding('Ctrl+ArrowUp', LogicalKeyboardKey.arrowUp, control: true);
    });

    test('rejects what is not a binding', () {
      for (final bad in [
        '',
        'Ctrl+',
        'Ctrl++',
        'Cmd+S',
        'ctrl+S',
        'Ctrl+Ctrl+S',
        'Ctrl+Space',
        'Ctrl+SS',
        'Ctrl+?',
        'F13',
      ]) {
        expect(parseBinding(bad), isNull, reason: bad);
      }
    });
  });

  group('effectiveBindings', () {
    test('applies overrides by id and keeps the defaults otherwise', () {
      final bindings = effectiveBindings(shortcutRegistry, {
        'save': 'Ctrl+Shift+S',
        'unknown-id': 'Ctrl+K',
      });
      expect(bindings, hasLength(shortcutRegistry.length));
      final save = bindingFor(bindings, MenuCommand.save)!;
      expect(save.binding, 'Ctrl+Shift+S');
      expect(save.activator.trigger, LogicalKeyboardKey.keyS);
      expect(save.activator.shift, isTrue);
      expect(bindingFor(bindings, MenuCommand.undo)!.binding, 'Ctrl+Z');
    });

    test('ignores empty and unparsable overrides, reporting the latter', () {
      final invalid = <String>[];
      final bindings = effectiveBindings(shortcutRegistry, {
        'save': '',
        'undo': 'Hyper+Z',
      }, onInvalid: (id, binding) => invalid.add('$id=$binding'));
      expect(bindingFor(bindings, MenuCommand.save)!.binding, 'Ctrl+S');
      expect(bindingFor(bindings, MenuCommand.undo)!.binding, 'Ctrl+Z');
      expect(invalid, ['undo=Hyper+Z']);
    });

    test('on a collision the first entry in registry order keeps the key', () {
      final map = shortcutMap(
        effectiveBindings(shortcutRegistry, {'save': 'Ctrl+Shift+S'}),
      );
      final ctrlShiftS = map.entries.where((e) {
        final a = e.key as SingleActivator;
        return a.trigger == LogicalKeyboardKey.keyS && a.control && a.shift;
      }).toList();
      expect(ctrlShiftS, hasLength(1));
      expect(
        (ctrlShiftS.single.value as MenuCommandIntent).command,
        MenuCommand.save,
      );
      // The plain Ctrl+S is no longer bound at app level.
      expect(
        map.keys.whereType<SingleActivator>().where(
          (a) => a.trigger == LogicalKeyboardKey.keyS && !a.shift,
        ),
        isEmpty,
      );
    });
  });
}

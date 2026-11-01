import 'dart:io';

import 'package:anvil/app/editor/editor_state.dart';
import 'package:anvil/app/editor/widgets/record_validation.dart';
import 'package:anvil/app/providers.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dialogs/fakes.dart' show copyFixture;

/// The single-record pass over a copy of the 0.1.6 fixture, opened with
/// the real `ProjectService`.
void main() {
  late String path;
  late ProjectService service;
  late ProjectSession session;
  late ProviderContainer container;

  setUp(() async {
    path = copyFixture();
    final support = Directory.systemTemp.createTempSync('anvil-support');
    addTearDown(() => support.deleteSync(recursive: true));
    service = ProjectService(supportDirectory: support.path);
    session = switch (await service.open(path)) {
      ProjectOpened(:final session) => session,
      final other => throw StateError('fixture did not open: $other'),
    };
    addTearDown(() async {
      if (session.isOpen) await service.close(session);
    });
    container = ProviderContainer.test(
      overrides: [
        appLoggerProvider.overrideWithValue(
          AppLogger(
            directory: '${support.path}/logs',
            minimumLevel: LogLevel.debug,
          ),
        ),
      ],
    );
    container.read(projectSessionProvider.notifier).set(session);
  });

  /// A recipe whose output item has been soft-deleted since: a reference
  /// issue on that recipe only.
  Future<String> recipeWithArchivedOutput() async {
    final recipe = (await session.recipes.list()).first;
    final draft = await session.recipes.load(recipe.id);
    await session.items.softDelete(draft.outputItemId);
    return recipe.id;
  }

  test('starts empty and runs the record pass on refresh', () async {
    final id = await recipeWithArchivedOutput();
    final key = (ValidationDomain.recipes, id);
    final provider = recordValidationProvider(key);
    container.listen(provider, (_, _) {});

    // 0.1.6 showed nothing before the first save.
    expect(container.read(provider), isEmpty);

    final issues = container.read(provider.notifier).refresh();
    expect(issues, isNotEmpty);
    expect(container.read(provider), issues);
    expect(issues.every((i) => i.recordId == id), isTrue);
    expect(issues.map((i) => i.field), contains('outputItemId'));

    // The same issues the project pass reports for that record.
    final project = await ValidationService(projectPath: path).runProject();
    expect(issues, [
      for (final i in project)
        if (i.domain == ValidationDomain.recipes && i.recordId == id) i,
    ]);
  });

  test('afterSave refreshes only on a completed save', () async {
    final id = await recipeWithArchivedOutput();
    final provider = recordValidationProvider((ValidationDomain.recipes, id));
    container.listen(provider, (_, _) {});
    final notifier = container.read(provider.notifier);

    for (final outcome in [
      SaveOutcome.nothingToSave,
      SaveOutcome.blocked,
      SaveOutcome.failed,
      SaveOutcome.busy,
    ]) {
      notifier.afterSave(outcome);
      expect(container.read(provider), isEmpty, reason: '$outcome');
    }
    notifier.afterSave(SaveOutcome.saved);
    expect(container.read(provider), isNotEmpty);
  });

  test('a record without issues and the domain mapping', () async {
    final provider = recordValidationProvider((
      ValidationDomain.recipes,
      'no-such-recipe',
    ));
    container.listen(provider, (_, _) {});
    expect(container.read(provider.notifier).refresh(), isEmpty);

    for (final domain in SaveDomain.values) {
      expect(validationDomainOf(domain).name, domain.name);
    }
    expect(validationDomainOf(SaveDomain.lootTables).value, 'loot-tables');
  });

  test('a replaced session resets the issues', () async {
    final id = await recipeWithArchivedOutput();
    final provider = recordValidationProvider((ValidationDomain.recipes, id));
    container.listen(provider, (_, _) {});
    container.read(provider.notifier).refresh();
    expect(container.read(provider), isNotEmpty);

    await service.close(session);
    session = switch (await service.open(path)) {
      ProjectOpened(:final session) => session,
      final other => throw StateError('fixture did not reopen: $other'),
    };
    container.read(projectSessionProvider.notifier).set(session);
    expect(container.read(provider), isEmpty);
  });
}

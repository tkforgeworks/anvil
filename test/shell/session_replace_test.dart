import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/shell_domain.dart';
import 'package:anvil/app/shell/shell_providers.dart';
import 'package:anvil/app/shell/sidebar.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show ProviderBase, ProviderException;
import 'package:flutter_test/flutter_test.dart';

import '../app_bootstrap_test.dart' show AppHarness;
import '../dialogs/fakes.dart';
import 'shell_harness.dart';

/// Counts how often each provider was built and disposed (`Ref.onDispose`
/// ran, which happens on every rebuild as well as on removal).
final class BuildCounter extends ProviderObserver {
  final added = <ProviderBase<Object?>, int>{};
  final disposed = <ProviderBase<Object?>, int>{};

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) =>
      added.update(context.provider, (n) => n + 1, ifAbsent: () => 1);

  @override
  void didDisposeProvider(ProviderObserverContext context) =>
      disposed.update(context.provider, (n) => n + 1, ifAbsent: () => 1);
}

void main() {
  testWidgets(
    'replacing the session disposes and rebuilds everything over it',
    (tester) async {
      final counter = BuildCounter();
      final harness = await ShellHarness.pump(tester, observers: [counter]);
      await harness.openProject(tester);
      final first = harness.container.read(projectSessionProvider)!;
      final disposedBefore = counter.disposed[recordCountsProvider] ?? 0;
      expect(harness.container.read(recordCountsProvider).value?.items, 5);

      // A second copy, opened directly and with one more item soft-deleted,
      // so its counts differ from the first.
      final second = await tester.runAsync(() async {
        final result = await harness.service.open(copyFixture(name: 'second'));
        final session = (result as ProjectOpened).session;
        final items = await session.items.list();
        await session.items.softDelete(items.first.id);
        return session;
      });
      harness.track(second!);

      harness.container.read(projectSessionProvider.notifier).set(second);
      await tester.pump();
      await harness.settleShell(tester);

      expect(
        counter.disposed[recordCountsProvider] ?? 0,
        greaterThan(disposedBefore),
      );
      expect(harness.container.read(requireSessionProvider), same(second));
      expect(
        harness.container.read(itemRepositoryProvider),
        same(second.items),
      );
      expect(
        harness.container.read(lifecycleRepositoryProvider),
        same(second.lifecycle),
      );
      expect(harness.container.read(recordCountsProvider).value?.items, 4);
      expect(harness.container.read(trashCountProvider).value, 3);
      // The location is kept; the shell shows the new project.
      expect(harness.location, '/');
      expect(
        tester
            .widget<Text>(find.byKey(Sidebar.countKey(ShellDomain.items)))
            .data,
        '4',
      );
      expect(first.isOpen, isTrue, reason: 'set() does not close');
    },
    variant: linux,
  );

  test(
    'without a session the shell providers fail instead of guessing',
    () async {
      final container = ProviderContainer.test(
        overrides: AppHarness.create().overrides,
        retry: (_, _) => null,
      );
      Object? error;
      try {
        container.read(requireSessionProvider);
      } catch (e) {
        error = e;
      }
      expect(
        error,
        anyOf(
          isStateError,
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isStateError,
          ),
        ),
      );
      await expectLater(
        container.read(recordCountsProvider.future),
        throwsA(anything),
      );
      expect(container.read(recordCountsProvider).hasError, isTrue);
    },
  );
}

import 'dart:async';
import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge_ui/forge_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'app/bootstrap/app_lifecycle.dart';
import 'app/bootstrap/error_hooks.dart';
import 'app/menu/global_shortcuts.dart';
import 'app/menu/ui_scale.dart';
import 'app/providers.dart';
import 'app/shell/app_router.dart';
import 'app/theme/theme_selection.dart';

/// Bootstrap (design §4.2, §14.2): everything runs inside one guarded zone
/// so an error anywhere after the logger exists is logged once.
void main() {
  AppLogger? logger;
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      registerForgeFontLicenses();

      final support = await getApplicationSupportDirectory();
      final log = logger = AppLogger(
        directory: _join(support.path, 'logs'),
        minimumLevel: kReleaseMode ? LogLevel.info : LogLevel.debug,
      );
      installErrorHooks(log);
      log.info(
        'Anvil starting (support directory ${anonymizePath(support.path)})',
      );

      final store = AppSettingsStore(
        filePath: _join(support.path, AppSettingsStore.fileName),
      );
      // Read once, before the first frame, so the first frame has the theme.
      final initial = store.read();

      runApp(
        ProviderScope(
          overrides: rootOverrides(
            supportDirectory: support,
            logger: log,
            store: store,
            initial: initial,
          ),
          child: const AnvilApp(),
        ),
      );
    },
    (error, stack) {
      final log = logger;
      if (log != null) {
        zoneErrorHandler(log)(error, stack);
      } else {
        // Failed before the logger existed (no support directory).
        stderr.writeln('Anvil failed to start: $error\n$stack');
      }
    },
  );
}

String _join(String directory, String name) =>
    '$directory${Platform.pathSeparator}$name';

/// Root widget: the persisted theme drives one `MaterialApp.router`, whose
/// router shows the welcome page while no project is open and the shell
/// while one is (`app/shell/app_router.dart`).
class AnvilApp extends ConsumerWidget {
  const AnvilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppExitHandler(
      child: MaterialApp.router(
        title: 'Anvil',
        debugShowCheckedModeBanner: false,
        theme: ref.watch(themeDataProvider),
        routerConfig: ref.watch(routerProvider),
        // The app-level shortcuts (design §8.7 layer 2) above every route,
        // and the View menu's zoom over the whole UI (design §13.4).
        builder: (context, child) => GlobalShortcuts(
          child: Consumer(
            builder: (context, ref, _) =>
                UiScale(scale: ref.watch(uiScaleProvider), child: child!),
          ),
        ),
      ),
    );
  }
}

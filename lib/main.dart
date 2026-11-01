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
import 'app/providers.dart';
import 'app/shell/project_open_placeholder.dart';
import 'app/theme/theme_selection.dart';
import 'app/welcome/welcome_page.dart';

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

/// Root widget: the persisted theme drives one `MaterialApp`, whose home is
/// the welcome page while no project is open and the open-project
/// placeholder while one is, until the shell (ANVL-185) replaces it.
class AnvilApp extends ConsumerWidget {
  const AnvilApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppExitHandler(
      child: MaterialApp(
        title: 'Anvil',
        debugShowCheckedModeBanner: false,
        theme: ref.watch(themeDataProvider),
        home: const AnvilHome(),
      ),
    );
  }
}

/// The welcome page when no project is open, else the open project.
class AnvilHome extends ConsumerWidget {
  const AnvilHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(projectSessionProvider) == null
      ? const WelcomePage()
      : const ProjectOpenPlaceholder();
}

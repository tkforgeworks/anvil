/// The root providers (design §4.2, §6.6). Values only `main()` can know,
/// the support directory, the logger, the settings store and the settings
/// read before the first frame, are root overrides built by
/// [rootOverrides]; reading one without its override throws. Feature
/// providers live beside the feature they serve, not here.
library;

import 'dart:io';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'settings/app_settings_notifier.dart';

/// The application support directory (`getApplicationSupportDirectory()`):
/// settings, recent projects and logs live under it.
final appSupportDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('appSupportDirectoryProvider'),
);

/// The one file logger, writing `<support dir>/logs/anvil.log`.
final appLoggerProvider = Provider<AppLogger>(
  (ref) => throw UnimplementedError('appLoggerProvider'),
);

/// The store over `<support dir>/app-settings.json`.
final appSettingsStoreProvider = Provider<AppSettingsStore>(
  (ref) => throw UnimplementedError('appSettingsStoreProvider'),
);

/// The settings `main()` read once before the first frame. Only
/// [AppSettingsNotifier.build] reads it; everything else watches
/// [appSettingsProvider].
final initialAppSettingsProvider = Provider<AppSettings>(
  (ref) => throw UnimplementedError('initialAppSettingsProvider'),
);

/// The current app settings; every change is written to the file first.
final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

/// Creates, opens and closes projects (core `ProjectService`).
final projectServiceProvider = Provider<ProjectService>(
  (ref) => ProjectService(
    supportDirectory: ref.watch(appSupportDirectoryProvider).path,
  ),
);

/// The open project, or null when none is open (design §6.6). The welcome
/// page and project lifecycle UI (S2) set and clear it.
final projectSessionProvider =
    NotifierProvider<ProjectSessionNotifier, ProjectSession?>(
      ProjectSessionNotifier.new,
    );

class ProjectSessionNotifier extends Notifier<ProjectSession?> {
  @override
  ProjectSession? build() => null;

  /// Makes [session] the open project. Replacing a session disposes every
  /// provider that watches this one.
  void set(ProjectSession session) => state = session;

  /// Marks no project as open. Closing the session itself is the caller's
  /// job (`ProjectService.close`).
  void clear() => state = null;
}

/// The root overrides `main()` passes to `ProviderScope`; tests call it with
/// a temporary directory.
List<Override> rootOverrides({
  required Directory supportDirectory,
  required AppLogger logger,
  required AppSettingsStore store,
  required AppSettings initial,
}) => [
  appSupportDirectoryProvider.overrideWithValue(supportDirectory),
  appLoggerProvider.overrideWithValue(logger),
  appSettingsStoreProvider.overrideWithValue(store),
  initialAppSettingsProvider.overrideWithValue(initial),
];

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:anvil/app/providers.dart';
import 'package:anvil/app/shell/placeholder_home_page.dart';
import 'package:anvil/app/theme/theme_gallery_page.dart';
import 'package:anvil/main.dart';
import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// A temporary application support directory with the root overrides
/// `main()` would build over it. Shared by the app-side tests.
class AppHarness {
  AppHarness._(this.directory, this.logger, this.store);

  /// Creates the directory, writes [settingsJson] (when given) as
  /// `app-settings.json`, and deletes everything at tear-down.
  factory AppHarness.create({String? settingsJson}) {
    final dir = Directory.systemTemp.createTempSync('anvil-app');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = AppSettingsStore(
      filePath: '${dir.path}/${AppSettingsStore.fileName}',
    );
    if (settingsJson != null) {
      File(store.filePath).writeAsStringSync(settingsJson);
    }
    final logger = AppLogger(
      directory: '${dir.path}/logs',
      minimumLevel: LogLevel.debug,
    );
    return AppHarness._(dir, logger, store);
  }

  final Directory directory;
  final AppLogger logger;
  final AppSettingsStore store;

  List<Override> get overrides => rootOverrides(
    supportDirectory: directory,
    logger: logger,
    store: store,
    initial: store.read(),
  );

  /// The settings file as JSON, as the store last wrote it.
  Map<String, Object?> get settingsFile =>
      jsonDecode(File(store.filePath).readAsStringSync())
          as Map<String, Object?>;

  /// Every line of `anvil.log` (empty when nothing was logged).
  List<String> get logLines {
    final file = File(logger.filePath);
    return file.existsSync() ? file.readAsLinesSync() : const [];
  }

  /// The app as `main()` mounts it, retries off (design §8.1).
  Widget app() => ProviderScope(
    overrides: overrides,
    retry: (_, _) => null,
    child: const AnvilApp(),
  );
}

void main() {
  Future<AppHarness> pumpApp(WidgetTester tester, {String? settings}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = AppHarness.create(settingsJson: settings);
    await tester.pumpWidget(harness.app());
    return harness;
  }

  Brightness appBrightness(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness;

  testWidgets(
    'the persisted theme applies on the first frame and the switch writes it',
    (tester) async {
      final harness = await pumpApp(tester, settings: '{"theme":"light"}');

      // First frame, before any settling or interaction.
      expect(appBrightness(tester), Brightness.light);
      expect(find.byType(PlaceholderHomePage), findsOneWidget);
      expect(find.byType(ThemeGalleryPage), findsNothing);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(appBrightness(tester), Brightness.dark);
      expect(harness.settingsFile['theme'], 'dark');
      expect(
        harness.logLines.where((l) => l.contains('App settings updated')),
        hasLength(1),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('no settings file means dark, and Custom is unavailable', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(appBrightness(tester), Brightness.dark);
    final custom = tester.widget<SegmentedButton<AppThemeMode>>(
      find.byType(SegmentedButton<AppThemeMode>),
    );
    expect(custom.segments.last.enabled, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('an exit request is allowed and logs the shutdown line once', (
    tester,
  ) async {
    final harness = await pumpApp(tester);

    final response = await tester.binding.handleRequestAppExit();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);

    expect(response, AppExitResponse.exit);
    expect(
      harness.logLines.where((l) => l.endsWith('Anvil shutting down')),
      hasLength(1),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}

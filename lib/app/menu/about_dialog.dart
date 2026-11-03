/// Help > About Anvil (ANVL-203): the app name, the running version, the
/// licence and copyright line, the repository and issue links, and the
/// framework's licence page.
///
/// 0.1.6's `AboutModal.tsx` showed the version, build SHA and date, the
/// author, a tkforgeworks.com link and an Open Log Folder button; 0.2.0
/// keeps its `RPG Data Management Tool` line and uses Flutter's
/// `showAboutDialog`, whose View licenses button lists the bundled fonts'
/// licences registered in `main()`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../editor/clock.dart';
import '../theme/anvil_metrics.dart';
import 'external_links.dart';

/// The source repository and its issue tracker.
const repositoryUrl = 'https://github.com/tkforgeworks/anvil';
const issuesUrl = 'https://github.com/tkforgeworks/anvil/issues';

/// The running version without the `+build` part (`0.2.0`, `0.2.0-rc.1`),
/// from the platform: `version.json` in the bundle on Linux, the
/// executable's `ProductVersion` resource on Windows. Tests override it.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return stripBuildNumber(info.version);
});

/// [version] without anything from the first `+` on.
String stripBuildNumber(String version) => version.split('+').first;

/// The copyright and licence line for [year].
String aboutLegalese(int year) => '© $year TK ForgeWorks · Apache-2.0';

/// Shows the About dialog on [context]. The version is read before the
/// dialog opens; when the platform cannot tell it, the dialog shows none.
Future<void> showAnvilAboutDialog(BuildContext context, WidgetRef ref) async {
  // Read everything up front: the menu that opened the dialog may unmount
  // while it is showing (the project closes), and its ref with it.
  final launch = ref.read(urlLauncherProvider);
  final year = ref.read(clockProvider)().year;
  String? version;
  try {
    version = await ref.read(appVersionProvider.future);
  } on Object {
    version = null;
  }
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: 'Anvil',
    applicationVersion: (version == null || version.isEmpty) ? null : version,
    applicationLegalese: aboutLegalese(year),
    children: [
      const SizedBox(height: AnvilSpacing.md),
      const Text('RPG Data Management Tool'),
      const SizedBox(height: AnvilSpacing.sm),
      Wrap(
        spacing: AnvilSpacing.sm,
        children: [
          TextButton.icon(
            key: const ValueKey('about-repository'),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Repository'),
            onPressed: () => openExternal(repositoryUrl, launch: launch),
          ),
          TextButton.icon(
            key: const ValueKey('about-report-issue'),
            icon: const Icon(Icons.bug_report_outlined, size: 16),
            label: const Text('Report an issue'),
            onPressed: () => openExternal(issuesUrl, launch: launch),
          ),
        ],
      ),
    ],
  );
}

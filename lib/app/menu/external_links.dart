/// External links (design §13.4): the Help menu's documentation and bug
/// report pages. The only file that imports `url_launcher`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// The 0.1.6 Help menu targets (`useCommandDispatch.ts`).
const documentationUrl = 'https://anvil.tkforgeworks.com/docs';
const reportBugUrl = 'https://anvil.tkforgeworks.com/bugs';

/// Hands a URL to the platform; returns whether it was opened.
typedef UrlLauncher = Future<bool> Function(Uri uri);

/// The platform launcher (the default browser); tests override it.
final urlLauncherProvider = Provider<UrlLauncher>(
  (ref) =>
      (uri) => launcher.launchUrl(
        uri,
        mode: launcher.LaunchMode.externalApplication,
      ),
);

/// Opens [url] through [launch] when it is an absolute `https` URL with a
/// host, and refuses anything else without calling it. Returns whether the
/// URL was handed over and opened.
///
/// 0.1.6's `shell:open-external` accepted `http` too; 0.2.0 allows `https`
/// only (design §13.4).
Future<bool> openExternal(String url, {required UrlLauncher launch}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
  try {
    return await launch(uri);
  } on Object {
    return false;
  }
}

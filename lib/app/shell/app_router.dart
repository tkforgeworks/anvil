import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../welcome/welcome_page.dart';
import 'app_shell.dart';
import 'placeholders.dart';
import 'shell_domain.dart';

/// Where the welcome page lives, outside the shell.
const welcomeLocation = '/welcome';

/// The app's one router (design §13.2): `/welcome` while no project is
/// open, and the shell with the 0.1.6 routes (`App.tsx`) while one is.
///
/// The redirect follows `projectSessionProvider`: every location goes to
/// [welcomeLocation] while it is null, and [welcomeLocation] goes to the
/// dashboard once a session exists. The provider never watches the session,
/// so the router lives as long as the app; a listener feeds the session
/// into [GoRouter.refreshListenable] instead.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<ProjectSession?>(
    ref.read(projectSessionProvider),
  );
  ref.listen(projectSessionProvider, (_, next) => session.value = next);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (_, state) {
      final atWelcome = state.uri.path == welcomeLocation;
      if (session.value == null) return atWelcome ? null : welcomeLocation;
      return atWelcome ? '/' : null;
    },
    routes: [
      GoRoute(
        path: welcomeLocation,
        pageBuilder: (_, _) => const NoTransitionPage(child: WelcomePage()),
      ),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          _page('/', dashboardPage),
          for (final domain in ShellDomain.values) ...[
            _page(domain.location, listPageBuilders[domain]!),
            GoRoute(
              path: '${domain.location}/:id',
              pageBuilder: (_, state) => NoTransitionPage(
                child: editorBuilders[domain]!(state.pathParameters['id']!),
              ),
            ),
          ],
          _page('/validation', validationPage),
          _page('/recycle-bin', recycleBinPage),
          _page('/export', exportPage),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});

/// A shell page without a transition: 0.1.6 switched pages instantly.
GoRoute _page(String path, Widget Function() build) => GoRoute(
  path: path,
  pageBuilder: (_, _) => NoTransitionPage(child: build()),
);

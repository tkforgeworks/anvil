import 'dart:async';

import 'package:anvil_core/anvil_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../editor/dirty_editors.dart';
import '../editor/exit_prompt.dart';
import '../providers.dart';
import '../welcome/welcome_page.dart';
import 'app_shell.dart';
import 'placeholders.dart';
import 'shell_domain.dart';

/// Where the welcome page lives, outside the shell.
const welcomeLocation = '/welcome';

/// The key of the router's root navigator, above the shell's. Code outside
/// the widget tree below the router, such as `AppExitHandler` (which sits
/// above `MaterialApp.router`), shows dialogs through its context. One key
/// per container, so test apps never share a `GlobalKey`.
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'root'),
);

/// The app's one router (design §13.2): `/welcome` while no project is
/// open, and the shell with the 0.1.6 routes (`App.tsx`) while one is.
///
/// The redirect follows `projectSessionProvider`: every location goes to
/// [welcomeLocation] while it is null, and [welcomeLocation] goes to the
/// dashboard once a session exists. The provider never watches the session,
/// so the router lives as long as the app; a listener feeds the session
/// into [GoRouter.refreshListenable] instead.
///
/// Each full-page editor route has the leave guard (design §8.8) as its
/// `onExit`: go_router calls it whenever the route leaves the match list,
/// including for another record of the same domain (the matched location
/// differs), and a false answer keeps the editor.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<ProjectSession?>(
    ref.read(projectSessionProvider),
  );
  ref.listen(projectSessionProvider, (_, next) => session.value = next);

  final router = GoRouter(
    navigatorKey: ref.read(rootNavigatorKeyProvider),
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
              onExit: (context, state) => _leaveEditorRoute(
                ref,
                context,
                domain,
                state.pathParameters['id']!,
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

/// The full-page editor's leave guard: true at once (keeping the route
/// change synchronous) when the editor for [id] is clean, else the answer
/// of `confirmLeaveEditor`. Also true at once once the session is gone,
/// because closing the project ran the project-level guard first and the
/// redirect to the welcome page must not be held up.
FutureOr<bool> _leaveEditorRoute(
  Ref ref,
  BuildContext context,
  ShellDomain domain,
  String id,
) {
  if (ref.read(projectSessionProvider) == null) return true;
  final entry = findDirtyEditor(
    ref.read(dirtyEditorsProvider),
    domain.saveDomain,
    id,
  );
  if (entry == null) return true;
  return confirmLeaveEditor(context, entry);
}

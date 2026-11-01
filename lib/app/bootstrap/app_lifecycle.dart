import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Listens for the platform's exit request, which both runners forward to
/// the framework when the window is closed (design §8.8), and logs the
/// 0.1.6 shutdown line once. Exit is always allowed for now; the shared
/// editor scaffold (S5) puts the dirty-editor prompt in front of it.
class AppExitHandler extends ConsumerStatefulWidget {
  const AppExitHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppExitHandler> createState() => _AppExitHandlerState();
}

class _AppExitHandlerState extends ConsumerState<AppExitHandler> {
  late final AppLifecycleListener _listener;
  var _shutdownLogged = false;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: _onExitRequested,
      onDetach: _logShutdown,
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _onExitRequested() async {
    _logShutdown();
    return AppExitResponse.exit;
  }

  // An exit request is followed by detach on some platforms; log once.
  void _logShutdown() {
    if (_shutdownLogged) return;
    _shutdownLogged = true;
    ref.read(appLoggerProvider).info('Anvil shutting down');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

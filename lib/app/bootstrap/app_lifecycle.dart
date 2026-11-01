import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/exit_prompt.dart';
import '../providers.dart';
import '../shell/app_router.dart';

/// Listens for the platform's exit request, which both runners forward to
/// the framework when the window is closed (design §8.8), puts the
/// dirty-editor prompt (`confirmLeaveAll`) in front of it, and logs the
/// 0.1.6 shutdown line once the exit goes ahead.
///
/// It sits above `MaterialApp.router`, so it shows the prompt through the
/// router's root navigator ([rootNavigatorKeyProvider]). Cancel in the
/// prompt, or a Save all that leaves an editor unsaved, answers
/// [AppExitResponse.cancel] and the window stays open. A second exit
/// request while the prompt is open is cancelled.
class AppExitHandler extends ConsumerStatefulWidget {
  const AppExitHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppExitHandler> createState() => _AppExitHandlerState();
}

class _AppExitHandlerState extends ConsumerState<AppExitHandler> {
  late final AppLifecycleListener _listener;
  var _shutdownLogged = false;
  var _prompting = false;

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
    if (_prompting) return AppExitResponse.cancel;
    final context = ref.read(rootNavigatorKeyProvider).currentContext;
    if (context != null) {
      _prompting = true;
      final bool leave;
      try {
        leave = await confirmLeaveAll(context, ref);
      } finally {
        _prompting = false;
      }
      if (!leave) return AppExitResponse.cancel;
    }
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

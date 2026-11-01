/// The View menu's zoom (design §13.4) as a scale factor over the whole UI.
/// 0.1.6 zoomed the page with Chromium's `webFrame` zoom levels
/// (`src/preload/index.ts`); the same levels apply here.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The UI scale factor, 1.0 at start. Session-only, as 0.1.6's zoom was
/// not persisted by Anvil.
final uiScaleProvider = NotifierProvider<UiScaleNotifier, double>(
  UiScaleNotifier.new,
);

/// Steps a Chromium zoom level: the factor is `1.2^level`, Zoom In and Out
/// move the level by 0.5 (`setZoomLevel(getZoomLevel() ± 0.5)`), Zoom Out
/// stops at level -3 (factor 0.579) as 0.1.6 clamped it, and Zoom In stops
/// at Chromium's maximum factor of 5.0 (level 8.83).
class UiScaleNotifier extends Notifier<double> {
  static const step = 0.5;
  static const minLevel = -3.0;

  /// Chromium's `kMaximumZoomFactor` as a level.
  static final maxLevel = math.log(5) / math.log(1.2);

  double _level = 0;

  /// The current zoom level (0 is 100 %).
  double get level => _level;

  @override
  double build() {
    _level = 0;
    return 1;
  }

  void zoomIn() => _setLevel(math.min(_level + step, maxLevel));

  void zoomOut() => _setLevel(math.max(_level - step, minLevel));

  void reset() => _setLevel(0);

  void _setLevel(double level) {
    _level = level;
    state = math.pow(1.2, level).toDouble();
  }
}

/// Lays [child] out at the available size divided by [scale] and paints it
/// scaled back up, so the whole UI zooms like a browser page: text, hit
/// targets and overlays together. `MediaQuery.size` below is the scaled
/// size, so dialogs size themselves to what they get.
///
/// The structure is the same at every scale, including 1.0, so changing
/// the zoom never rebuilds [child]'s subtree from scratch (which would lose
/// the router's state).
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth / scale,
          constraints.maxHeight / scale,
        );
        // The overflow box sizes itself to the constraints and the child to
        // the scaled size; the transform sits inside it, so a pointer
        // anywhere in the window hit-tests within the child's own bounds
        // at every scale.
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: size.width,
          maxWidth: size.width,
          minHeight: size.height,
          maxHeight: size.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: size),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

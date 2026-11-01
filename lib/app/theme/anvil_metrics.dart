import 'package:flutter/painting.dart';

import 'package:forge_ui/forge_ui.dart';

/// Anvil's layout constants beyond what `forge_ui` fixes (`ForgeRadii`,
/// `ForgeType`). Defined once here; widgets never carry their own numbers.
///
/// Spacing follows the 8 px grid the Electron app used (MUI `spacing(n)`),
/// so ported layouts keep their measurements.
abstract final class AnvilSpacing {
  static const unit = 8.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Corner radii Anvil uses that `ForgeRadii` has no name for. Cards,
/// buttons, inputs and chips keep `ForgeRadii.card`.
abstract final class AnvilRadii {
  /// Small inline controls and badges (MUI's default shape radius).
  static const control = 4.0;

  /// Panels, dialogs and the sticky edit header.
  static const panel = ForgeRadii.card;
}

/// Fixed dimensions of the desktop shell, carried over from the Electron app.
abstract final class AnvilLayout {
  /// The minimum 0.1.6 enforced (`minWidth`/`minHeight` in `src/main/index.ts`);
  /// the runners set it natively (design §13.3).
  static const minWindowSize = Size(1400, 600);
  static const titleBarHeight = 36.0;
  static const sidebarWidth = 220.0;
  static const sidebarCollapsedWidth = 56.0;
  static const inspectorRailWidth = 260.0;
}

/// Type styles Anvil needs beyond the `forge_ui` scale. Code and identifiers
/// (export keys, formulas, paths, log lines) are `ForgeType.code`; this adds
/// tabular figures for numeric grid cells.
abstract final class AnvilType {
  /// Numbers that line up in columns: stat grids, weights, counts.
  static TextStyle numeric({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => ForgeType.ui(
    size: size,
    weight: weight,
    color: color,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

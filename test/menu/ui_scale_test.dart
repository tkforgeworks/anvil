import 'dart:math' as math;

import 'package:anvil/app/menu/ui_scale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zoom follows the Chromium levels 0.1.6 used: 1.2^level in 0.5 '
      'steps, down to level -3 and up to a factor of 5', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final zoom = container.read(uiScaleProvider.notifier);
    expect(container.read(uiScaleProvider), 1);

    zoom.zoomIn();
    expect(container.read(uiScaleProvider), closeTo(math.pow(1.2, 0.5), 1e-9));
    zoom.zoomIn();
    expect(container.read(uiScaleProvider), closeTo(1.2, 1e-9));

    zoom.reset();
    expect(container.read(uiScaleProvider), 1);

    for (var i = 0; i < 10; i++) {
      zoom.zoomOut();
    }
    expect(zoom.level, -3);
    expect(container.read(uiScaleProvider), closeTo(math.pow(1.2, -3), 1e-9));

    for (var i = 0; i < 40; i++) {
      zoom.zoomIn();
    }
    expect(container.read(uiScaleProvider), closeTo(5, 1e-9));
  });
}

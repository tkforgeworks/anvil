import 'package:flutter/material.dart';
import 'package:forge_ui/forge_ui.dart';

import 'app/theme/theme_controller.dart';
import 'app/theme/theme_gallery_page.dart';

void main() {
  registerForgeFontLicenses();
  runApp(AnvilApp(controller: ThemeController()));
}

/// Root widget: the current theme selection drives one `MaterialApp`. The
/// shell (ANVL-148) replaces the gallery as home.
class AnvilApp extends StatelessWidget {
  const AnvilApp({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, selection, _) => MaterialApp(
        title: 'Anvil',
        debugShowCheckedModeBanner: false,
        theme: selection.themeData,
        home: ThemeGalleryPage(controller: controller),
      ),
    );
  }
}

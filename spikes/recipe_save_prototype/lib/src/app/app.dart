import 'package:flutter/material.dart';

import 'recipe_list_page.dart';

class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key, required this.workingCopyPath});

  final String workingCopyPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANVL-158 save prototype',
      home: RecipeListPage(workingCopyPath: workingCopyPath),
    );
  }
}

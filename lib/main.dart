import 'package:flutter/material.dart';

void main() {
  runApp(const AnvilApp());
}

/// Root widget. The theme comes in ANVL-154 and the shell in ANVL-148; until
/// then this is a placeholder so the desktop runners have something to show.
class AnvilApp extends StatelessWidget {
  const AnvilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Anvil',
      home: Scaffold(body: Center(child: Text('Anvil'))),
    );
  }
}

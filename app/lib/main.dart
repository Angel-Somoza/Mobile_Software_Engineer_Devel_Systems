import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/catalog/presentation/catalog_screen.dart';

void main() {
  runApp(const ProviderScope(child: FlashOrdersApp()));
}

class FlashOrdersApp extends StatelessWidget {
  const FlashOrdersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash Orders',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      home: const CatalogScreen(),
    );
  }
}
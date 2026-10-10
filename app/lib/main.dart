import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/catalog/presentation/catalog_screen.dart';
import 'features/outbox/presentation/outbox_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container.read(outboxRepositoryProvider).recoverInterruptedSends();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FlashOrdersApp(),
    ),
  );
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
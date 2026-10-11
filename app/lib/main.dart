import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/theme/app_theme.dart';
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
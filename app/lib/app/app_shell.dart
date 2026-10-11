import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/presentation/catalog_screen.dart';
import '../features/order/presentation/order_providers.dart';
import '../features/order/presentation/scan_feedback.dart';
import '../features/outbox/presentation/outbox_providers.dart';
import '../features/outbox/presentation/outbox_screen.dart';
import 'nav_item.dart';
import 'scan_button.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  Future<void> _scan() async {
    final outcome = await ref.read(cartControllerProvider.notifier).scanAndAdd();
    if (mounted) showScanFeedback(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final sendable = ref.watch(sendableCountProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _tab,
          children: const [CatalogScreen(), OutboxScreen()],
        ),
        floatingActionButton: ScanButton(onPressed: _scan),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 72,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shadowColor: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Catalogo',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              NavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Historial',
                selected: _tab == 1,
                badgeCount: sendable,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
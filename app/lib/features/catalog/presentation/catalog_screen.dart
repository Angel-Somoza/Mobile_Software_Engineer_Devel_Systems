import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../scanner/domain/scan_failure.dart';
import '../../scanner/presentation/scanner_providers.dart';
import 'catalog_providers.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(catalogRefreshProvider.notifier).refresh());
  }

  Future<void> _scan() async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final productId = await ref.read(scannerBridgeProvider).scanProduct();
      final product =
      await ref.read(catalogRepositoryProvider).findById(productId);
      message = product == null
          ? 'Producto $productId no esta en el catalogo'
          : 'Escaneado: ${product.title}';
    } on ScanFailure catch (failure) {
      message = 'Escaneo sin resultado: ${failure.reason.name}';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final refreshState = ref.watch(catalogRefreshProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshState.isLoading
                ? null
                : () => ref.read(catalogRefreshProvider.notifier).refresh(),
          ),
        ],
      ),
      // NUEVO
      floatingActionButton: FloatingActionButton(
        onPressed: _scan,
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: Column(
        children: [
          if (refreshState.isLoading) const LinearProgressIndicator(),
          if (refreshState.hasError)
            MaterialBanner(
              content: Text('No se pudo actualizar: ${refreshState.error}'),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('Catalogo vacio'))
                  : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final product = items[index];
                  return ListTile(
                    leading: Text('${product.id}'),
                    title: Text(product.title),
                    trailing: Text('USD ${product.price.toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
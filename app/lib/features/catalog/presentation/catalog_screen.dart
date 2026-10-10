import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../order/presentation/order_providers.dart';
import '../../order/presentation/order_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final refreshState = ref.watch(catalogRefreshProvider);
    final itemCount = ref.watch(cartControllerProvider).itemCount;

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
          IconButton(
            icon: Badge(
              isLabelVisible: itemCount > 0,
              label: Text('$itemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderScreen()),
            ),
          ),
        ],
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
                    trailing:
                    Text('USD ${product.price.toStringAsFixed(2)}'),
                    onTap: () {
                      ref.read(cartControllerProvider.notifier).add(product);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text('Agregado: ${product.title}')),
                        );
                    },
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/scan_outcome.dart';
import 'order_providers.dart';

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(cartControllerProvider.notifier).scanAndAdd();
    final message = switch (outcome) {
      ScanAdded(:final product) => 'Agregado: ${product.title}',
      ScanProductNotFound(:final productId) =>
      'Producto $productId no encontrado',
      ScanProductOffline(:final productId) =>
      'Producto $productId no disponible sin conexion',
      ScanLookupError(:final message) => 'Error al buscar: $message',
      ScanFailed(:final reason) => 'Escaneo sin resultado: ${reason.name}',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final orderId = await ref.read(cartControllerProvider.notifier).save();
    if (orderId != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Pedido #$orderId guardado como pendiente')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedido actual')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _scan(context, ref),
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: cart.isEmpty
          ? const Center(child: Text('Escanea un QR o toca un producto del catalogo'))
          : ListView(
        children: [
          for (final line in cart.lines)
            ListTile(
              title: Text(line.title),
              subtitle: Text('USD ${line.price.toStringAsFixed(2)} c/u'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => controller.decrease(line.productId),
                  ),
                  Text('${line.quantity}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => controller.increase(line.productId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => controller.remove(line.productId),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total estimado: USD ${cart.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton(
                onPressed: cart.isEmpty ? null : () => _save(context, ref),
                child: const Text('Guardar pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
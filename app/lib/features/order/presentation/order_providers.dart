import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/domain/product_lookup.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../scanner/domain/scan_failure.dart';
import '../../scanner/presentation/scanner_providers.dart';
import '../data/order_repository.dart';
import '../domain/cart.dart';
import '../domain/scan_outcome.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(appDatabaseProvider));
});

class CartController extends Notifier<Cart> {
  bool _saving = false;

  @override
  Cart build() => const Cart();

  void add(Product product) => state = state.add(product);
  void increase(int productId) => state = state.increase(productId);
  void decrease(int productId) => state = state.decrease(productId);
  void remove(int productId) => state = state.remove(productId);

  Future<ScanOutcome> scanAndAdd() async {
    final int productId;
    try {
      productId = await ref.read(scannerBridgeProvider).scanProduct();
    } on ScanFailure catch (failure) {
      return ScanFailed(failure.reason);
    }

    final lookup = await ref.read(catalogRepositoryProvider).lookup(productId);
    switch (lookup) {
      case ProductFound(:final product):
        add(product);
        return ScanAdded(product);
      case ProductNotFound():
        return ScanProductNotFound(productId);
      case ProductUnavailableOffline():
        return ScanProductOffline(productId);
      case ProductLookupError(:final message):
        return ScanLookupError(message);
    }
  }


  Future<int?> save() async {
    if (_saving || state.isEmpty) return null;
    _saving = true;
    try {
      final orderId =
      await ref.read(orderRepositoryProvider).saveOrder(state.lines);
      state = const Cart();
      return orderId;
    } finally {
      _saving = false;
    }
  }
}

final cartControllerProvider = NotifierProvider<CartController, Cart>(
  CartController.new,
);
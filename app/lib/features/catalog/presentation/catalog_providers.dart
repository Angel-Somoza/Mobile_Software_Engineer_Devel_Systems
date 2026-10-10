import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/network/http_client_provider.dart';
import '../data/catalog_api.dart';
import '../data/catalog_repository.dart';
import '../domain/product.dart';

final catalogApiProvider = Provider<CatalogApi>((ref) {
  return CatalogApi(ref.watch(httpClientProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    ref.watch(catalogApiProvider),
    ref.watch(appDatabaseProvider),
  );
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchProducts();
});

class CatalogRefreshController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> refresh() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
          () => ref.read(catalogRepositoryProvider).refresh(),
    );
  }
}

final catalogRefreshProvider =
NotifierProvider<CatalogRefreshController, AsyncValue<void>>(
  CatalogRefreshController.new,
);
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../domain/product.dart';
import 'catalog_api.dart';

class CatalogRepository {
  CatalogRepository(this._api, this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final CatalogApi _api;
  final db.AppDatabase _database;
  final DateTime Function() _clock;

  Stream<List<Product>> watchProducts() {
    final query = _database.select(_database.products)
      ..orderBy([(p) => OrderingTerm.asc(p.id)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<Product?> findById(int id) async {
    final query = _database.select(_database.products)
      ..where((p) => p.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<void> refresh() async {
    final products = await _api.fetchProducts();
    final now = _clock();

    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _database.products,
        products.map(
              (p) => db.ProductsCompanion.insert(
            id: Value(p.id),
            title: p.title,
            price: p.price,
            thumbnailUrl: Value(p.thumbnailUrl),
            updatedAt: now,
          ),
        ),
      );
    });
  }

  Product _toDomain(db.Product row) {
    return Product(
      id: row.id,
      title: row.title,
      price: row.price,
      thumbnailUrl: row.thumbnailUrl,
    );
  }
}
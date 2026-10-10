import '../../../core/database/app_database.dart' as db;
import '../domain/cart.dart';

class OrderRepository {
  OrderRepository(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final db.AppDatabase _database;
  final DateTime Function() _clock;


  Future<int> saveOrder(List<CartLine> lines) {
    if (lines.isEmpty) {
      throw ArgumentError('El pedido no tiene lineas');
    }
    final now = _clock();

    return _database.transaction(() async {
      final orderId = await _database.into(_database.orders).insert(
        db.OrdersCompanion.insert(
          status: db.OrderStatus.pending,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _database.batch((batch) {
        batch.insertAll(
          _database.orderLines,
          lines.map(
                (line) => db.OrderLinesCompanion.insert(
              orderId: orderId,
              productId: line.productId,
              productTitle: line.title,
              price: line.price,
              quantity: line.quantity,
            ),
          ),
        );
      });

      return orderId;
    });
  }
}
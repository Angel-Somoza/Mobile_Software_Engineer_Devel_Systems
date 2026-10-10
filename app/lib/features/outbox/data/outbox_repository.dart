import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' as db;
import '../../order/domain/cart.dart';
import '../domain/saved_order.dart';

class OutboxRepository {
  OutboxRepository(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const batchStatuses = [db.OrderStatus.pending, db.OrderStatus.failed];

  final db.AppDatabase _database;
  final DateTime Function() _clock;

  Stream<List<SavedOrder>> watchOrders() {
    final query = _database.select(_database.orders).join([
      leftOuterJoin(
        _database.orderLines,
        _database.orderLines.orderId.equalsExp(_database.orders.id),
      ),
    ])
      ..orderBy([
        OrderingTerm.desc(_database.orders.id),
        OrderingTerm.asc(_database.orderLines.id),
      ]);
    return query.watch().map(_groupByOrder);
  }

  Future<List<int>> idsReadyForBatch() async {
    final query = _database.select(_database.orders)
      ..where((o) => o.status.isIn(batchStatuses.map((s) => s.name)))
      ..orderBy([(o) => OrderingTerm.asc(o.id)]);
    final rows = await query.get();
    return rows.map((row) => row.id).toList();
  }

  Future<List<CartLine>?> claimForSending(
      int orderId, {
        required List<db.OrderStatus> from,
      }) {
    return _database.transaction(() async {
      final claimed = await (_database.update(_database.orders)
        ..where((o) =>
        o.id.equals(orderId) & o.status.isIn(from.map((s) => s.name))))
          .write(
        db.OrdersCompanion.custom(
          status: Constant(db.OrderStatus.sending.name),
          attempts: _database.orders.attempts + const Constant(1),
          updatedAt: Variable(_clock()),
        ),
      );
      if (claimed == 0) return null;

      final rows = await (_database.select(_database.orderLines)
        ..where((l) => l.orderId.equals(orderId)))
          .get();
      return rows.map(_toCartLine).toList();
    });
  }

  Future<void> markConfirmed(int orderId, int reference) {
    return _finishSending(
      orderId,
      db.OrdersCompanion(
        status: const Value(db.OrderStatus.confirmed),
        lastError: const Value(null),
        remoteReference: Value(reference),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> markFailed(int orderId, String error) {
    return _finishSending(
      orderId,
      db.OrdersCompanion(
        status: const Value(db.OrderStatus.failed),
        lastError: Value(error),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> markUnknown(int orderId, String error) {
    return _finishSending(
      orderId,
      db.OrdersCompanion(
        status: const Value(db.OrderStatus.unknown),
        lastError: Value(error),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<int> recoverInterruptedSends() {
    return (_database.update(_database.orders)
      ..where((o) => o.status.equals(db.OrderStatus.sending.name)))
        .write(
      db.OrdersCompanion(
        status: const Value(db.OrderStatus.unknown),
        lastError: const Value(
          'La app se cerro durante el envio; se desconoce si llego al servidor',
        ),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> _finishSending(int orderId, db.OrdersCompanion values) {
    return (_database.update(_database.orders)
      ..where((o) =>
      o.id.equals(orderId) &
      o.status.equals(db.OrderStatus.sending.name)))
        .write(values);
  }

  List<SavedOrder> _groupByOrder(List<TypedResult> rows) {
    final orders = <int, db.Order>{};
    final lines = <int, List<CartLine>>{};
    for (final row in rows) {
      final order = row.readTable(_database.orders);
      orders[order.id] = order;
      final orderLines = lines.putIfAbsent(order.id, () => []);
      final line = row.readTableOrNull(_database.orderLines);
      if (line != null) orderLines.add(_toCartLine(line));
    }
    return [
      for (final order in orders.values)
        SavedOrder(
          id: order.id,
          status: order.status,
          createdAt: order.createdAt,
          updatedAt: order.updatedAt,
          attempts: order.attempts,
          lastError: order.lastError,
          remoteReference: order.remoteReference,
          lines: lines[order.id]!,
        ),
    ];
  }

  CartLine _toCartLine(db.OrderLine row) {
    return CartLine(
      productId: row.productId,
      title: row.productTitle,
      price: row.price,
      quantity: row.quantity,
    );
  }
}
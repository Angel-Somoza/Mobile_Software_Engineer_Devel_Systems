import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> insertOrder() {
    final now = DateTime(2026, 10, 10);
    return database.into(database.orders).insert(
      OrdersCompanion.insert(
        status: OrderStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('guarda un pedido con sus lineas y lo recupera', () async {
    final orderId = await insertOrder();
    await database.into(database.orderLines).insert(
      OrderLinesCompanion.insert(
        orderId: orderId,
        productId: 1,
        productTitle: 'Producto de prueba',
        price: 9.99,
        quantity: 2,
      ),
    );

    final order = await (database.select(database.orders)
      ..where((o) => o.id.equals(orderId)))
        .getSingle();
    final lines = await (database.select(database.orderLines)
      ..where((l) => l.orderId.equals(orderId)))
        .get();

    expect(order.status, OrderStatus.pending);
    expect(order.attempts, 0);
    expect(lines, hasLength(1));
    expect(lines.single.quantity, 2);
    expect(lines.single.price, 9.99);
  });

  test('rechaza una linea con cantidad cero', () async {
    final orderId = await insertOrder();

    expect(
          () => database.into(database.orderLines).insert(
        OrderLinesCompanion.insert(
          orderId: orderId,
          productId: 1,
          productTitle: 'Producto de prueba',
          price: 9.99,
          quantity: 0,
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
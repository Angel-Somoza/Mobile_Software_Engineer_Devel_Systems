import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/database/app_database.dart';
import 'package:app/features/order/data/order_repository.dart';
import 'package:app/features/order/domain/cart.dart';

void main() {
  late AppDatabase database;
  late OrderRepository repository;
  final fixedNow = DateTime(2026, 10, 10, 12);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = OrderRepository(database, clock: () => fixedNow);
  });

  tearDown(() async {
    await database.close();
  });

  test('guarda el pedido como pendiente con copia de nombre y precio', () async {
    final orderId = await repository.saveOrder(const [
      CartLine(productId: 1, title: 'A', price: 9.99, quantity: 2),
      CartLine(productId: 2, title: 'B', price: 10, quantity: 1),
    ]);

    final order = await (database.select(database.orders)
      ..where((o) => o.id.equals(orderId)))
        .getSingle();
    final lines = await database.select(database.orderLines).get();

    expect(order.status, OrderStatus.pending);
    expect(order.createdAt, fixedNow);
    expect(lines, hasLength(2));
    expect(lines.first.productTitle, 'A');
    expect(lines.first.price, 9.99);
    expect(lines.every((l) => l.orderId == orderId), isTrue);
  });

  test('si una linea falla no se guarda nada', () async {
    await expectLater(
      repository.saveOrder(const [
        CartLine(productId: 1, title: 'A', price: 9.99, quantity: 1),
        CartLine(productId: 2, title: 'B', price: 10, quantity: 0),
      ]),
      throwsA(isA<SqliteException>()),
    );

    expect(await database.select(database.orders).get(), isEmpty);
    expect(await database.select(database.orderLines).get(), isEmpty);
  });

  test('no permite guardar un pedido vacio', () {
    expect(() => repository.saveOrder(const []), throwsArgumentError);
  });
}
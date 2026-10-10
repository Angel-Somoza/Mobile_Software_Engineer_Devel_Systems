import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/core/database/app_database.dart';
import 'package:app/core/database/database_provider.dart';
import 'package:app/core/network/http_client_provider.dart';
import 'package:app/features/order/data/order_repository.dart';
import 'package:app/features/order/domain/cart.dart';
import 'package:app/features/outbox/data/order_api.dart';
import 'package:app/features/outbox/data/outbox_repository.dart';
import 'package:app/features/outbox/data/outbox_service.dart';
import 'package:app/features/outbox/presentation/outbox_providers.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository outbox;
  late OrderRepository orders;
  late Future<http.Response> Function(http.Request) respond;
  late int postCount;
  late http.Request? lastRequest;

  http.Response confirmedResponse() =>
      http.Response(jsonEncode({'id': 51, 'total': 19.98}), 201);

  final client = MockClient((request) {
    postCount++;
    lastRequest = request;
    return respond(request);
  });

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(database);
    orders = OrderRepository(database);
    postCount = 0;
    lastRequest = null;
    respond = (_) async => confirmedResponse();
  });

  tearDown(() async {
    await database.close();
  });

  OutboxService buildService({Duration timeout = const Duration(milliseconds: 100)}) {
    return OutboxService(outbox, OrderApi(client, timeout: timeout));
  }

  Future<int> seedOrder() {
    return orders.saveOrder(const [
      CartLine(productId: 1, title: 'A', price: 9.99, quantity: 2),
    ]);
  }

  Future<Order> readOrder(int id) {
    return (database.select(database.orders)..where((o) => o.id.equals(id)))
        .getSingle();
  }

  test('exito confirma, guarda la referencia y envia el formato esperado', () async {
    final id = await seedOrder();

    await buildService().sendPending();

    final order = await readOrder(id);
    expect(order.status, OrderStatus.confirmed);
    expect(order.remoteReference, 51);
    expect(order.attempts, 1);
    expect(order.lastError, isNull);
    expect(lastRequest!.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(lastRequest!.body), {
      'userId': 1,
      'products': [
        {'id': 1, 'quantity': 2},
      ],
    });
  });

  test('error HTTP marca error con explicacion', () async {
    final id = await seedOrder();
    respond = (_) async => http.Response('error', 500);

    await buildService().sendPending();

    final order = await readOrder(id);
    expect(order.status, OrderStatus.failed);
    expect(order.lastError, contains('500'));
  });

  test('sin conexion antes de enviar marca error', () async {
    final id = await seedOrder();
    respond = (_) async =>
    throw http.ClientException("Failed host lookup: 'dummyjson.com'");

    await buildService().sendPending();

    expect((await readOrder(id)).status, OrderStatus.failed);
  });

  test('timeout marca resultado desconocido', () async {
    final id = await seedOrder();
    respond = (_) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      return confirmedResponse();
    };

    await buildService().sendPending();

    final order = await readOrder(id);
    expect(order.status, OrderStatus.unknown);
    expect(order.lastError, contains('pudo haber llegado'));
  });

  test('conexion perdida durante el envio marca resultado desconocido', () async {
    final id = await seedOrder();
    respond = (_) async => throw http.ClientException('Connection reset by peer');

    await buildService().sendPending();

    expect((await readOrder(id)).status, OrderStatus.unknown);
  });

  test('JSON invalido en una respuesta exitosa marca resultado desconocido', () async {
    final id = await seedOrder();
    respond = (_) async => http.Response('ok', 200);

    await buildService().sendPending();

    expect((await readOrder(id)).status, OrderStatus.unknown);
  });

  test('un pedido confirmado no se vuelve a enviar', () async {
    await seedOrder();
    final service = buildService();
    await service.sendPending();

    final second = await service.sendPending();

    expect(postCount, 1);
    expect(second.total, 0);
  });

  test('reintento conserva el mismo pedido y suma intentos', () async {
    final id = await seedOrder();
    final service = buildService();
    respond = (_) async => http.Response('error', 503);
    await service.sendPending();

    respond = (_) async => confirmedResponse();
    await service.send(id);

    final order = await readOrder(id);
    expect(order.status, OrderStatus.confirmed);
    expect(order.attempts, 2);
    expect(await database.select(database.orders).get(), hasLength(1));
  });

  test('desconocido no entra al lote pero se puede reintentar manualmente', () async {
    final id = await seedOrder();
    final service = buildService();
    respond = (_) async => throw http.ClientException('Connection reset by peer');
    await service.sendPending();

    respond = (_) async => confirmedResponse();
    final batch = await service.sendPending();
    expect(batch.total, 0);
    expect(postCount, 1);

    final status = await service.send(id, includeUnknown: true);
    expect(status, OrderStatus.confirmed);
    expect(postCount, 2);
  });

  test('doble ejecucion no envia dos veces el mismo pedido', () async {
    final first = await seedOrder();
    final second = await seedOrder();
    respond = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return confirmedResponse();
    };
    final service = buildService();

    await Future.wait([service.sendPending(), service.sendPending()]);

    expect(postCount, 2);
    expect((await readOrder(first)).attempts, 1);
    expect((await readOrder(second)).attempts, 1);
    expect((await readOrder(first)).status, OrderStatus.confirmed);
    expect((await readOrder(second)).status, OrderStatus.confirmed);
  });

  test('doble toque en el boton no inicia un segundo lote', () async {
    await seedOrder();
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(database),
      httpClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(outboxControllerProvider.notifier);

    final results =
    await Future.wait([controller.sendPending(), controller.sendPending()]);

    expect(results.whereType<Object>(), hasLength(1));
    expect(postCount, 1);
  });

  test('un envio interrumpido se recupera como resultado desconocido', () async {
    final id = await seedOrder();
    await outbox.claimForSending(id, from: OutboxRepository.batchStatuses);
    expect((await readOrder(id)).status, OrderStatus.sending);

    final recovered = await outbox.recoverInterruptedSends();

    final order = await readOrder(id);
    expect(recovered, 1);
    expect(order.status, OrderStatus.unknown);
    expect(order.lastError, contains('se cerro'));
  });
}
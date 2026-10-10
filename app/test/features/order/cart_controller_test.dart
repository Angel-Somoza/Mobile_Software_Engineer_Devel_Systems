import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/core/database/app_database.dart';
import 'package:app/core/database/database_provider.dart';
import 'package:app/core/network/http_client_provider.dart';
import 'package:app/features/order/domain/scan_outcome.dart';
import 'package:app/features/order/presentation/order_providers.dart';
import 'package:app/features/scanner/data/scanner_bridge.dart';
import 'package:app/features/scanner/domain/scan_failure.dart';
import 'package:app/features/scanner/presentation/scanner_providers.dart';

class FakeScannerBridge implements ScannerBridge {
  FakeScannerBridge(this.onScan);

  final Future<int> Function() onScan;

  @override
  Future<int> scanProduct() => onScan();

  @override
  Future<void> cancelScan() async {}
}

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.into(database.products).insert(
      ProductsCompanion.insert(
        id: const Value(1),
        title: 'Producto local',
        price: 9.99,
        updatedAt: DateTime(2026, 10, 10),
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  ProviderContainer buildContainer({
    required Future<int> Function() onScan,
    required http.Client client,
  }) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        httpClientProvider.overrideWithValue(client),
        scannerBridgeProvider.overrideWithValue(FakeScannerBridge(onScan)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final neverCalled = MockClient((_) async => fail('No deberia usar la red'));

  test('producto en la base se agrega sin usar la red', () async {
    final container = buildContainer(onScan: () async => 1, client: neverCalled);

    final outcome =
    await container.read(cartControllerProvider.notifier).scanAndAdd();

    expect(outcome, isA<ScanAdded>());
    expect(container.read(cartControllerProvider).lines.single.productId, 1);
  });

  test('producto inexistente no agrega ninguna linea', () async {
    final container = buildContainer(
      onScan: () async => 999999,
      client: MockClient((_) async => http.Response('{}', 404)),
    );

    final outcome =
    await container.read(cartControllerProvider.notifier).scanAndAdd();

    expect(outcome, isA<ScanProductNotFound>());
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('producto no guardado y sin red informa no disponible offline', () async {
    final container = buildContainer(
      onScan: () async => 2,
      client: MockClient((_) async => throw http.ClientException('sin red')),
    );

    final outcome =
    await container.read(cartControllerProvider.notifier).scanAndAdd();

    expect(outcome, isA<ScanProductOffline>());
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('producto remoto se agrega y queda guardado en la base', () async {
    final remote = jsonEncode({'id': 2, 'title': 'Remoto', 'price': 5, 'thumbnail': null});
    final container = buildContainer(
      onScan: () async => 2,
      client: MockClient((_) async => http.Response(remote, 200)),
    );

    final outcome =
    await container.read(cartControllerProvider.notifier).scanAndAdd();

    expect(outcome, isA<ScanAdded>());
    final saved = await database.select(database.products).get();
    expect(saved.map((p) => p.id), containsAll([1, 2]));
  });

  test('escaneo cancelado no modifica el carrito', () async {
    final container = buildContainer(
      onScan: () async => throw const ScanFailure(ScanFailureReason.cancelled),
      client: neverCalled,
    );

    final outcome =
    await container.read(cartControllerProvider.notifier).scanAndAdd();

    expect(
      outcome,
      isA<ScanFailed>().having((o) => o.reason, 'reason', ScanFailureReason.cancelled),
    );
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('guardar dos veces seguidas crea un solo pedido y vacia el carrito', () async {
    final container = buildContainer(onScan: () async => 1, client: neverCalled);
    final controller = container.read(cartControllerProvider.notifier);
    await controller.scanAndAdd();

    final results = await Future.wait([controller.save(), controller.save()]);

    expect(results.whereType<int>(), hasLength(1));
    expect(await database.select(database.orders).get(), hasLength(1));
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });
}
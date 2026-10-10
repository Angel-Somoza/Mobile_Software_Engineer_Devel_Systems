import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/core/database/app_database.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/features/catalog/data/catalog_api.dart';
import 'package:app/features/catalog/data/catalog_repository.dart';

void main() {
  late AppDatabase database;
  final fixedNow = DateTime(2026, 10, 10, 12);

  final validBody = jsonEncode({
    'products': [
      {'id': 1, 'title': 'Producto 1', 'price': 9.99, 'thumbnail': 'https://x/1.png'},
      {'id': 2, 'title': 'Producto 2', 'price': 10, 'thumbnail': 'https://x/2.png'},
    ],
  });

  CatalogRepository buildRepository(MockClient client) {
    final api = CatalogApi(client, timeout: const Duration(milliseconds: 100));
    return CatalogRepository(api, database, clock: () => fixedNow);
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('refresh guarda los productos y se leen desde la base', () async {
    final repository = buildRepository(
      MockClient((_) async => http.Response(validBody, 200)),
    );

    await repository.refresh();
    final products = await repository.watchProducts().first;

    expect(products.map((p) => p.id), [1, 2]);
    expect(products[1].price, 10.0);final rows = await database.select(database.products).get();
    expect(rows.every((r) => r.updatedAt == fixedNow), isTrue);
  });

  test('sin conexion conserva la copia anterior', () async {
    await buildRepository(
      MockClient((_) async => http.Response(validBody, 200)),
    ).refresh();

    final offline = buildRepository(
      MockClient((_) async => throw http.ClientException('sin red')),
    );

    await expectLater(offline.refresh(), throwsA(isA<NoConnectionException>()));
    final products = await offline.watchProducts().first;
    expect(products, hasLength(2));
  });

  test('error HTTP no modifica la base', () async {
    final repository = buildRepository(
      MockClient((_) async => http.Response('error', 500)),
    );

    await expectLater(
      repository.refresh(),
      throwsA(isA<HttpStatusException>().having((e) => e.statusCode, 'statusCode', 500)),
    );
    expect(await repository.watchProducts().first, isEmpty);
  });

  test('JSON invalido lanza InvalidResponseException', () async {
    final repository = buildRepository(
      MockClient((_) async => http.Response('{"productos": 1}', 200)),
    );

    await expectLater(repository.refresh(), throwsA(isA<InvalidResponseException>()));
    expect(await repository.watchProducts().first, isEmpty);
  });

  test('timeout lanza RequestTimeoutException', () async {
    final repository = buildRepository(
      MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return http.Response(validBody, 200);
      }),
    );

    await expectLater(repository.refresh(), throwsA(isA<RequestTimeoutException>()));
  });

  test('refrescar actualiza un producto existente sin duplicarlo', () async {
    await buildRepository(
      MockClient((_) async => http.Response(validBody, 200)),
    ).refresh();

    final updatedBody = jsonEncode({
      'products': [
        {'id': 1, 'title': 'Producto 1 nuevo', 'price': 5.5, 'thumbnail': null},
      ],
    });
    final repository = buildRepository(
      MockClient((_) async => http.Response(updatedBody, 200)),
    );
    await repository.refresh();

    final products = await repository.watchProducts().first;
    expect(products, hasLength(2));
    expect(products.first.title, 'Producto 1 nuevo');
    expect(products.first.price, 5.5);
  });
}
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

enum OrderStatus { pending, sending, confirmed, failed, unknown }

class Products extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  RealColumn get price => real()();
  TextColumn get thumbnailUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get status => textEnum<OrderStatus>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get remoteReference => integer().nullable()();
}

class OrderLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer()();
  IntColumn get productId => integer()();
  TextColumn get productTitle => text()();
  RealColumn get price => real()();
  IntColumn get quantity => integer().check(quantity.isBiggerThanValue(0))();
}

@DriftDatabase(tables: [Products, Orders, OrderLines])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'flash_orders'));

  @override
  int get schemaVersion => 1;
}
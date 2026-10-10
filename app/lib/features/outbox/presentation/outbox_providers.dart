import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' show OrderStatus;
import '../../../core/database/database_provider.dart';
import '../../../core/network/http_client_provider.dart';
import '../data/order_api.dart';
import '../data/outbox_repository.dart';
import '../data/outbox_service.dart';
import '../domain/saved_order.dart';
import '../domain/send_summary.dart';

final orderApiProvider = Provider<OrderApi>((ref) {
  return OrderApi(ref.watch(httpClientProvider));
});

final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  return OutboxRepository(ref.watch(appDatabaseProvider));
});

final outboxServiceProvider = Provider<OutboxService>((ref) {
  return OutboxService(
    ref.watch(outboxRepositoryProvider),
    ref.watch(orderApiProvider),
  );
});

final savedOrdersProvider = StreamProvider<List<SavedOrder>>((ref) {
  return ref.watch(outboxRepositoryProvider).watchOrders();
});

class OutboxController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<SendSummary?> sendPending() async {
    if (state) return null;
    state = true;
    try {
      return await ref.read(outboxServiceProvider).sendPending();
    } finally {
      state = false;
    }
  }

  Future<OrderStatus?> retry(int orderId, {bool includeUnknown = false}) {
    return ref
        .read(outboxServiceProvider)
        .send(orderId, includeUnknown: includeUnknown);
  }
}

final outboxControllerProvider = NotifierProvider<OutboxController, bool>(
  OutboxController.new,
);
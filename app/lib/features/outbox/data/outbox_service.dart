import '../../../core/database/app_database.dart' show OrderStatus;
import '../../../core/network/api_exception.dart';
import '../domain/send_summary.dart';
import 'order_api.dart';
import 'outbox_repository.dart';

class OutboxService {
  OutboxService(this._repository, this._api);

  final OutboxRepository _repository;
  final OrderApi _api;
  
  Future<OrderStatus?> send(int orderId, {bool includeUnknown = false}) async {
    final from = [
      ...OutboxRepository.batchStatuses,
      if (includeUnknown) OrderStatus.unknown,
    ];
    final lines = await _repository.claimForSending(orderId, from: from);
    if (lines == null) return null;

    try {
      final reference = await _api.submitOrder(lines);
      await _repository.markConfirmed(orderId, reference);
      return OrderStatus.confirmed;
    } on ApiException catch (error) {
      switch (error) {
        case NoConnectionException() || HttpStatusException():
          await _repository.markFailed(orderId, error.message);
          return OrderStatus.failed;
        case RequestTimeoutException() ||
        ConnectionLostException() ||
        InvalidResponseException():
          await _repository.markUnknown(
            orderId,
            '${error.message}. El pedido pudo haber llegado al servidor',
          );
          return OrderStatus.unknown;
      }
    }
  }

  Future<SendSummary> sendPending() async {
    final ids = await _repository.idsReadyForBatch();
    final results = <OrderStatus>[];
    for (final id in ids) {
      final status = await send(id);
      if (status != null) results.add(status);
    }
    return SendSummary.from(results);
  }
}
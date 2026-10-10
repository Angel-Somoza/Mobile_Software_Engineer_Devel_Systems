import '../../../core/database/app_database.dart' show OrderStatus;

class SendSummary {
  const SendSummary({this.confirmed = 0, this.failed = 0, this.unknown = 0});

  factory SendSummary.from(List<OrderStatus> results) {
    int count(OrderStatus status) => results.where((s) => s == status).length;
    return SendSummary(
      confirmed: count(OrderStatus.confirmed),
      failed: count(OrderStatus.failed),
      unknown: count(OrderStatus.unknown),
    );
  }

  final int confirmed;
  final int failed;
  final int unknown;

  int get total => confirmed + failed + unknown;
}
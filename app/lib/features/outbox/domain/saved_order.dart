import '../../../core/database/app_database.dart' show OrderStatus;
import '../../order/domain/cart.dart';

class SavedOrder {
  const SavedOrder({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.attempts,
    required this.lines,
    this.lastError,
    this.remoteReference,
  });

  final int id;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attempts;
  final String? lastError;
  final int? remoteReference;
  final List<CartLine> lines;

  double get total => lines.fold(0.0, (sum, line) => sum + line.subtotal);
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
}
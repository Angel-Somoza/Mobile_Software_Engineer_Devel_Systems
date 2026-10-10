import '../../catalog/domain/product.dart';
import '../../scanner/domain/scan_failure.dart';

sealed class ScanOutcome {
  const ScanOutcome();
}

class ScanAdded extends ScanOutcome {
  const ScanAdded(this.product);
  final Product product;
}

class ScanProductNotFound extends ScanOutcome {
  const ScanProductNotFound(this.productId);
  final int productId;
}

class ScanProductOffline extends ScanOutcome {
  const ScanProductOffline(this.productId);
  final int productId;
}

class ScanLookupError extends ScanOutcome {
  const ScanLookupError(this.message);
  final String message;
}

class ScanFailed extends ScanOutcome {
  const ScanFailed(this.reason);
  final ScanFailureReason reason;
}
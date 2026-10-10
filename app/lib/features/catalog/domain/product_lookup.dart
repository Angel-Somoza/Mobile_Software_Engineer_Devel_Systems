import 'product.dart';

sealed class ProductLookup {
  const ProductLookup();
}

class ProductFound extends ProductLookup {
  const ProductFound(this.product);
  final Product product;
}

class ProductNotFound extends ProductLookup {
  const ProductNotFound();
}

class ProductUnavailableOffline extends ProductLookup {
  const ProductUnavailableOffline();
}

class ProductLookupError extends ProductLookup {
  const ProductLookupError(this.message);
  final String message;
}
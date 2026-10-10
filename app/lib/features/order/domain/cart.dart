import '../../catalog/domain/product.dart';

class CartLine {
  const CartLine({
    required this.productId,
    required this.title,
    required this.price,
    required this.quantity,
  });

  final int productId;
  final String title;
  final double price;
  final int quantity;

  double get subtotal => price * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(
      productId: productId,
      title: title,
      price: price,
      quantity: quantity ?? this.quantity,
    );
  }
}

class Cart {
  const Cart([this.lines = const []]);

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
  double get total => lines.fold(0.0, (sum, line) => sum + line.subtotal);

  Cart add(Product product) {
    final existing = lines.where((l) => l.productId == product.id).firstOrNull;
    if (existing != null) {
      return _withQuantity(product.id, existing.quantity + 1);
    }
    return Cart([
      ...lines,
      CartLine(
        productId: product.id,
        title: product.title,
        price: product.price,
        quantity: 1,
      ),
    ]);
  }

  Cart increase(int productId) =>
      _withQuantity(productId, _quantityOf(productId) + 1);

  Cart decrease(int productId) =>
      _withQuantity(productId, _quantityOf(productId) - 1);

  Cart remove(int productId) =>
      Cart(lines.where((l) => l.productId != productId).toList());

  int _quantityOf(int productId) =>
      lines.firstWhere((l) => l.productId == productId).quantity;

  Cart _withQuantity(int productId, int quantity) {
    if (quantity <= 0) return remove(productId);
    return Cart([
      for (final line in lines)
        line.productId == productId ? line.copyWith(quantity: quantity) : line,
    ]);
  }
}
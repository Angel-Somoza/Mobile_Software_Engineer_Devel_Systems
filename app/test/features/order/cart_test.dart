import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/catalog/domain/product.dart';
import 'package:app/features/order/domain/cart.dart';

void main() {
  const productA = Product(id: 1, title: 'A', price: 9.99);
  const productB = Product(id: 2, title: 'B', price: 10);

  test('agregar el mismo producto aumenta su cantidad', () {
    final cart = const Cart().add(productA).add(productA);

    expect(cart.lines, hasLength(1));
    expect(cart.lines.single.quantity, 2);
  });

  test('bajar la cantidad a cero elimina la linea', () {
    final cart = const Cart().add(productA).decrease(1);

    expect(cart.isEmpty, isTrue);
  });

  test('el total suma precio por cantidad', () {
    final cart = const Cart().add(productA).add(productA).add(productB);

    expect(cart.total, closeTo(29.98, 0.001));
    expect(cart.total.toStringAsFixed(2), '29.98');
    expect(cart.itemCount, 3);
  });

  test('quitar un producto deja los demas', () {
    final cart = const Cart().add(productA).add(productB).remove(1);

    expect(cart.lines.map((l) => l.productId), [2]);
  });
}
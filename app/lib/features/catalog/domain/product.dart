class Product {
  const Product({
    required this.id,
    required this.title,
    required this.price,
    this.thumbnailUrl,
  });

  final int id;
  final String title;
  final double price;
  final String? thumbnailUrl;
}
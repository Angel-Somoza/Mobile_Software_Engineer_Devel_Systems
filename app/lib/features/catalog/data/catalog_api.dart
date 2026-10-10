import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../domain/product.dart';

class CatalogApi {
  CatalogApi(this._client, {this.timeout = const Duration(seconds: 10)});

  static final Uri _productsUri =
  Uri.parse('https://dummyjson.com/products?limit=30');

  final http.Client _client;
  final Duration timeout;

  Future<List<Product>> fetchProducts() async {
    final http.Response response;
    try {
      response = await _client.get(_productsUri).timeout(timeout);
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on http.ClientException {
      throw const NoConnectionException();
    }

    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode);
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = body['products'] as List<dynamic>;
      return items
          .map((item) => _parseProduct(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const InvalidResponseException();
    }
  }

  Product _parseProduct(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      title: json['title'] as String,
      price: (json['price'] as num).toDouble(),
      thumbnailUrl: json['thumbnail'] as String?,
    );
  }
}
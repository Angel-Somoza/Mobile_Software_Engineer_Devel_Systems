import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../domain/product.dart';

class CatalogApi {
  CatalogApi(this._client, {this.timeout = const Duration(seconds: 10)});

  static const _baseUrl = 'https://dummyjson.com';

  final http.Client _client;
  final Duration timeout;

  Future<List<Product>> fetchProducts() async {
    final response = await _get(
      Uri.parse('$_baseUrl/products?limit=30&select=id,title,price,thumbnail'),);
    _ensureOk(response);
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

  Future<Product?> fetchProductById(int id) async {
    final response = await _get(Uri.parse('$_baseUrl/products/$id'));
    if (response.statusCode == 404){
      return null; }
    _ensureOk(response);
    try {
      return _parseProduct(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const InvalidResponseException();
    }
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on http.ClientException {
      throw const NoConnectionException();
    }
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode != 200) {
      throw HttpStatusException(response.statusCode);
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
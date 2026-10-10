import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../../order/domain/cart.dart';

class OrderApi {
  OrderApi(this._client, {this.timeout = const Duration(seconds: 15)});

  static final Uri _addCartUri = Uri.parse('https://dummyjson.com/carts/add');
  static const demoUserId = 1;

  final http.Client _client;
  final Duration timeout;

  Future<int> submitOrder(List<CartLine> lines) async {
    final body = jsonEncode({
      'userId': demoUserId,
      'products': [
        for (final line in lines) {'id': line.productId, 'quantity': line.quantity},
      ],
    });

    final http.Response response;
    try {
      response = await _client
          .post(
        _addCartUri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(timeout);
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on http.ClientException catch (error) {
      throw _neverReachedServer(error)
          ? const NoConnectionException()
          : const ConnectionLostException();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpStatusException(response.statusCode);
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['id'] as int;
    } catch (_) {
      throw const InvalidResponseException();
    }
  }

  static bool _neverReachedServer(http.ClientException error) {
    final Object raw = error;
    final osMessage = raw is SocketException ? raw.osError?.message ?? '' : '';
    final text = '${error.message} $osMessage'.toLowerCase();
    return const [
      'failed host lookup',
      'network is unreachable',
      'connection refused',
      'connection failed',
    ].any(text.contains);
  }
}
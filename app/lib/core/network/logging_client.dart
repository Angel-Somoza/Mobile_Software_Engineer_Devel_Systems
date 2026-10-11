import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LoggingClient extends http.BaseClient {
  LoggingClient(this._inner);

  static const _maxBodyLength = 500;

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();
    _log('--> ${request.method} ${request.url}');
    if (request is http.Request && request.body.isNotEmpty) {
      _log('    body: ${_shorten(request.body)}');
    }

    try {
      final response = await _inner.send(request);
      final bytes = await response.stream.toBytes();
      _log('<-- ${response.statusCode} ${request.method} ${request.url} '
          '(${stopwatch.elapsedMilliseconds} ms)');
      _log('    body: ${_shorten(utf8.decode(bytes, allowMalformed: true))}');

      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (error) {
      _log('<-- ERROR ${request.method} ${request.url} '
          '(${stopwatch.elapsedMilliseconds} ms): $error');
      rethrow;
    }
  }

  @override
  void close() => _inner.close();

  static String _shorten(String text) => text.length <= _maxBodyLength
      ? text
      : '${text.substring(0, _maxBodyLength)}... (${text.length} caracteres)';

  static void _log(String message) => debugPrint('[HTTP] $message');
}
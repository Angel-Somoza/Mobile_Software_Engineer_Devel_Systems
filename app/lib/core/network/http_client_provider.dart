import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'logging_client.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final http.Client base = http.Client();
  final client = kDebugMode ? LoggingClient(base) : base;
  ref.onDispose(client.close);
  return client;
});
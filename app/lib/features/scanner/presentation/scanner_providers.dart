import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scanner_bridge.dart';

final scannerBridgeProvider = Provider<ScannerBridge>((ref) {
  return MethodChannelScannerBridge();
});
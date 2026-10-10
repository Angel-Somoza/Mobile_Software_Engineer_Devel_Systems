import 'package:flutter/services.dart';

import '../domain/scan_failure.dart';

abstract interface class ScannerBridge {

  Future<int> scanProduct();

  Future<void> cancelScan();
}

class MethodChannelScannerBridge implements ScannerBridge {
  MethodChannelScannerBridge([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.asomoza.flash_orders/qr_scanner';

  final MethodChannel _channel;

  @override
  Future<int> scanProduct() async {
    try {
      final productId = await _channel.invokeMethod<int>('startScan');
      if (productId == null) {
        throw const ScanFailure(ScanFailureReason.unknown);
      }
      return productId;
    } on PlatformException catch (e) {
      throw ScanFailure(_reasonFor(e.code));
    } on MissingPluginException {
      throw const ScanFailure(ScanFailureReason.unknown);
    }
  }

  @override
  Future<void> cancelScan() => _channel.invokeMethod<void>('cancelScan');

  static ScanFailureReason _reasonFor(String code) {
    return switch (code) {
      'permissionDenied' => ScanFailureReason.permissionDenied,
      'cameraUnavailable' => ScanFailureReason.cameraUnavailable,
      'invalidQr' => ScanFailureReason.invalidQr,
      'cancelled' => ScanFailureReason.cancelled,
      'scanInProgress' => ScanFailureReason.scanInProgress,
      _ => ScanFailureReason.unknown,
    };
  }
}
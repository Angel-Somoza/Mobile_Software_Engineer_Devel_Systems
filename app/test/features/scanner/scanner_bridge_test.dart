import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/scanner/data/scanner_bridge.dart';
import 'package:app/features/scanner/domain/scan_failure.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelScannerBridge.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final bridge = MethodChannelScannerBridge();
  final calls = <String>[];

  void mockNative(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      return handler(call);
    });
  }

  setUp(calls.clear);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('convierte el productId del canal en un tipo int', () async {
    mockNative((_) async => 42);

    expect(await bridge.scanProduct(), 42);
    expect(calls, ['startScan']);
  });

  final cases = {
    'permissionDenied': ScanFailureReason.permissionDenied,
    'cameraUnavailable': ScanFailureReason.cameraUnavailable,
    'invalidQr': ScanFailureReason.invalidQr,
    'cancelled': ScanFailureReason.cancelled,
    'scanInProgress': ScanFailureReason.scanInProgress,
    'algoNuevo': ScanFailureReason.unknown,
  };

  cases.forEach((code, reason) {
    test('el codigo $code se propaga como $reason', () async {
      mockNative((_) async => throw PlatformException(code: code));

      await expectLater(
        bridge.scanProduct(),
        throwsA(isA<ScanFailure>().having((f) => f.reason, 'reason', reason)),
      );
    });
  });

  test('canal no registrado se propaga como unknown', () async {
    await expectLater(
      bridge.scanProduct(),
      throwsA(isA<ScanFailure>()
          .having((f) => f.reason, 'reason', ScanFailureReason.unknown)),
    );
  });

  test('cancelScan invoca el metodo nativo cancelScan', () async {
    mockNative((_) async => null);

    await bridge.cancelScan();

    expect(calls, ['cancelScan']);
  });
}
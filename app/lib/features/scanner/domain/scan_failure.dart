enum ScanFailureReason {
  permissionDenied,
  cameraUnavailable,
  invalidQr,
  cancelled,
  scanInProgress,
  unknown,
}

class ScanFailure implements Exception {
  const ScanFailure(this.reason);

  final ScanFailureReason reason;

  @override
  String toString() => 'ScanFailure(${reason.name})';
}
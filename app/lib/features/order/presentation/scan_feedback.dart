import 'package:flutter/material.dart';

import '../../../core/widgets/feedback.dart';
import '../../scanner/domain/scan_failure.dart';
import '../domain/scan_outcome.dart';

void showScanFeedback(BuildContext context, ScanOutcome outcome) {
  final (icon, message) = switch (outcome) {
    ScanAdded(:final product) => (Icons.check_circle_outline, 'Agregado: ${product.title}'),
    ScanProductNotFound(:final productId) =>
    (Icons.search_off, 'El producto $productId no existe en el catalogo'),
    ScanProductOffline(:final productId) => (
    Icons.cloud_off_outlined,
    'El producto $productId no esta guardado y no hay conexion',
    ),
    ScanLookupError(:final message) =>
    (Icons.error_outline, 'No se pudo buscar el producto: $message'),
    ScanFailed(:final reason) => (_failureIcon(reason), _failureMessage(reason)),
  };
  showFeedback(context, message, icon: icon);
}

IconData _failureIcon(ScanFailureReason reason) => switch (reason) {
  ScanFailureReason.permissionDenied => Icons.no_photography_outlined,
  ScanFailureReason.cameraUnavailable => Icons.videocam_off_outlined,
  ScanFailureReason.invalidQr => Icons.qr_code_2,
  ScanFailureReason.cancelled => Icons.close,
  ScanFailureReason.scanInProgress => Icons.hourglass_top,
  ScanFailureReason.unknown => Icons.error_outline,
};

String _failureMessage(ScanFailureReason reason) => switch (reason) {
  ScanFailureReason.permissionDenied =>
  'Sin permiso de camara. Activalo en Ajustes para escanear.',
  ScanFailureReason.cameraUnavailable => 'No se pudo abrir la camara.',
  ScanFailureReason.invalidQr => 'QR no valido.',
  ScanFailureReason.cancelled => 'Escaneo cancelado.',
  ScanFailureReason.scanInProgress => 'Ya hay un escaneo en curso.',
  ScanFailureReason.unknown => 'No se pudo completar el escaneo.',
};
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart' show OrderStatus;

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pendiente',
    OrderStatus.sending => 'Enviando',
    OrderStatus.confirmed => 'Confirmado simulado',
    OrderStatus.failed => 'Error',
    OrderStatus.unknown => 'Resultado desconocido',
  };

  IconData get icon => switch (this) {
    OrderStatus.pending => Icons.schedule,
    OrderStatus.sending => Icons.sync,
    OrderStatus.confirmed => Icons.check_circle_outline,
    OrderStatus.failed => Icons.error_outline,
    OrderStatus.unknown => Icons.help_outline,
  };
}
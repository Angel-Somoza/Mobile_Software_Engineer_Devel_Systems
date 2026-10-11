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

  Color get color => switch (this) {
    OrderStatus.pending => const Color(0xFF8A5300),
    OrderStatus.sending => const Color(0xFF1E4FC2),
    OrderStatus.confirmed => const Color(0xFF17693F),
    OrderStatus.failed => const Color(0xFFB3261E),
    OrderStatus.unknown => const Color(0xFF5E3F99),
  };

  Color get background => switch (this) {
    OrderStatus.pending => const Color(0xFFFFF1D6),
    OrderStatus.sending => const Color(0xFFE3ECFF),
    OrderStatus.confirmed => const Color(0xFFDDF5E7),
    OrderStatus.failed => const Color(0xFFFDE3E3),
    OrderStatus.unknown => const Color(0xFFEEE7FA),
  };
}
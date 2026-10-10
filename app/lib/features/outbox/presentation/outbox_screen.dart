import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' show OrderStatus;
import '../domain/saved_order.dart';
import 'order_status_label.dart';
import 'outbox_providers.dart';

class OutboxScreen extends ConsumerWidget {
  const OutboxScreen({super.key});

  Future<void> _sendPending(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary =
    await ref.read(outboxControllerProvider.notifier).sendPending();
    if (summary == null) return;
    final message = summary.total == 0
        ? 'No hay pedidos pendientes para enviar'
        : 'Confirmados: ${summary.confirmed} · Error: ${summary.failed} · '
        'Desconocido: ${summary.unknown}';
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retry(BuildContext context, WidgetRef ref, SavedOrder order) async {
    final isUnknown = order.status == OrderStatus.unknown;
    if (isUnknown) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reenviar pedido #${order.id}'),
          content: const Text(
            'No sabemos si este pedido llego al servidor. Si lo reenvias, '
                'podria registrarse dos veces. ¿Quieres reenviarlo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reenviar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(outboxControllerProvider.notifier)
        .retry(order.id, includeUnknown: isUnknown);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(savedOrdersProvider);
    final isSending = ref.watch(outboxControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: isSending ? null : () => _sendPending(context, ref),
            icon: isSending
                ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.send),
            label: Text(isSending ? 'Enviando...' : 'Enviar pendientes'),
          ),
        ),
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Todavia no hay pedidos guardados'))
            : ListView(
          children: [
            for (final order in items)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(order.status.icon),
                  title: Text(
                    'Pedido #${order.id} · USD ${order.total.toStringAsFixed(2)}',
                  ),
                  subtitle: Text([
                    order.status.label,
                    '${order.itemCount} articulos · intentos: ${order.attempts}',
                    if (order.remoteReference != null)
                      'Referencia simulada: ${order.remoteReference}',
                    if (order.lastError != null) order.lastError!,
                  ].join('\n')),
                  isThreeLine: true,
                  trailing: switch (order.status) {
                    OrderStatus.failed || OrderStatus.unknown => IconButton(
                      tooltip: 'Reintentar',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _retry(context, ref, order),
                    ),
                    _ => null,
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
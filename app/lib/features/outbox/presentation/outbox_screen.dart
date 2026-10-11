import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' show OrderStatus;
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/state_view.dart';
import '../domain/saved_order.dart';
import 'order_status_label.dart';
import 'outbox_providers.dart';

class OutboxScreen extends ConsumerWidget {
  const OutboxScreen({super.key});

  Future<void> _sendPending(BuildContext context, WidgetRef ref) async {
    final summary = await ref.read(outboxControllerProvider.notifier).sendPending();
    if (summary == null || !context.mounted) return;
    final message = summary.total == 0
        ? 'No hay pedidos para enviar'
        : 'Confirmados: ${summary.confirmed} · Error: ${summary.failed} · '
        'Desconocido: ${summary.unknown}';
    showFeedback(context, message, icon: Icons.send);
  }

  Future<void> _retry(BuildContext context, WidgetRef ref, SavedOrder order) async {
    final isUnknown = order.status == OrderStatus.unknown;
    if (isUnknown) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.help_outline),
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
            TextButton(
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
    final sendable = ref.watch(sendableCountProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader(title: 'Historial', subtitle: 'Tus pedidos:'),
          Expanded(
            child: switch (orders) {
              AsyncData(:final value) when value.isEmpty => const StateView(
                icon: Icons.receipt_long_outlined,
                title: 'Todavia no hay pedidos',
                message:
                'Los pedidos que guardes apareceran aqui, aunque no tengas conexion.',
              ),
              AsyncData(:final value) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  _SendPanel(
                    sendable: sendable,
                    isSending: isSending,
                    onSend: () => _sendPending(context, ref),
                  ),
                  const SizedBox(height: 12),
                  for (final order in value)
                    _OrderCard(order: order, onRetry: () => _retry(context, ref, order)),
                ],
              ),
              AsyncError(:final error) => StateView(
                icon: Icons.error_outline,
                title: 'No se pudieron leer los pedidos',
                message: '$error',
              ),
              _ => const LoadingView(message: 'Cargando pedidos...'),
            },
          ),
        ],
      ),
    );
  }
}

class _SendPanel extends StatelessWidget {
  const _SendPanel({required this.sendable, required this.isSending, required this.onSend});

  final int sendable;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sendable == 0
                ? 'Todo esta al dia'
                : '$sendable ${sendable == 1 ? 'pedido' : 'pedidos'} por enviar',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Se envian los pendientes y los que tuvieron error. Los de resultado '
                'desconocido se reintentan uno por uno.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isSending || sendable == 0 ? null : onSend,
            icon: isSending
                ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.send),
            label: Text(isSending ? 'Enviando...' : 'Enviar pendientes'),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onRetry});

  final SavedOrder order;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canRetry =
        order.status == OrderStatus.failed || order.status == OrderStatus.unknown;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Pedido #${order.id}', style: textTheme.titleMedium)),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDate(order.createdAt)} · ${order.itemCount} articulos',
            style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            order.lines.map((l) => '${l.quantity} × ${l.title}').join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Total estimado', style: textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
              const Spacer(),
              Text(formatPrice(order.total), style: textTheme.titleMedium),
            ],
          ),
          if (order.attempts > 0 || order.remoteReference != null || order.lastError != null) ...[
            const Divider(height: 20),
            Text(
              [
                'Intentos: ${order.attempts}',
                if (order.remoteReference != null) 'Referencia simulada: #${order.remoteReference}',
              ].join(' · '),
              style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            if (order.lastError != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: order.status.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.lastError!,
                      style: textTheme.bodySmall?.copyWith(color: order.status.color),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (canRetry) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(
                  order.status == OrderStatus.unknown ? 'Reintentar (incierto)' : 'Reintentar',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estado: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: status.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 16, color: status.color),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(color: status.color, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
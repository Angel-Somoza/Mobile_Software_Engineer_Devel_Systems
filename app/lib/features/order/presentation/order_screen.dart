import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/state_view.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../domain/cart.dart';
import 'order_providers.dart';
import 'scan_feedback.dart';

void openOrderScreen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrderScreen()));
}

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(cartControllerProvider.notifier).scanAndAdd();
    if (context.mounted) showScanFeedback(context, outcome);
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final orderId = await ref.read(cartControllerProvider.notifier).save();
    if (orderId == null || !context.mounted) return;
    showFeedback(
      context,
      'Pedido #$orderId guardado. Envialo desde Historial.',
      icon: Icons.check_circle_outline,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final productsById = switch (ref.watch(productsProvider)) {
      AsyncData(:final value) => {for (final p in value) p.id: p},
      _ => const <int, Product>{},
    };

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader(title: 'Pedido', subtitle: 'Revisa tu pedido:'),
          Expanded(
            child: cart.isEmpty
                ? StateView(
              icon: Icons.shopping_cart_outlined,
              title: 'Tu pedido esta vacio',
              message: 'Escanea un QR o toca un producto del catalogo para empezar.',
              actionLabel: 'Escanear QR',
              onAction: () => _scan(context, ref),
            )
                : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final line in cart.lines)
                  _LineCard(
                    line: line,
                    thumbnailUrl: productsById[line.productId]?.thumbnailUrl,
                    onIncrease: () => controller.increase(line.productId),
                    onDecrease: () => controller.decrease(line.productId),
                    onRemove: () => controller.remove(line.productId),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _scan(context, ref),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear otro producto'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _SummaryBar(cart: cart, onSave: () => _save(context, ref)),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.thumbnailUrl,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final CartLine line;
  final String? thumbnailUrl;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 64,
              child: ColoredBox(
                color: Colors.white,
                child: ProductThumbnail(title: line.title, url: thumbnailUrl),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatPrice(line.price)} c/u',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPrice(line.subtotal),
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Quitar ${line.title}',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, color: AppColors.muted),
              ),
              _QuantityStepper(
                quantity: line.quantity,
                onIncrease: onIncrease,
                onDecrease: onDecrease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Restar uno',
            visualDensity: VisualDensity.compact,
            onPressed: onDecrease,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Semantics(
            label: 'Cantidad $quantity',
            excludeSemantics: true,
            child: Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          IconButton(
            tooltip: 'Sumar uno',
            visualDensity: VisualDensity.compact,
            onPressed: onIncrease,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.cart, required this.onSave});

  final Cart cart;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Total estimado', style: textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    formatPrice(cart.total),
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Text(
                '${cart.itemCount} articulos · sin impuestos ni descuentos',
                style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt),
                label: const Text('Guardar pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
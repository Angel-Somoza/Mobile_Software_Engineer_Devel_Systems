import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import 'order_providers.dart';
import 'order_screen.dart';

class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartControllerProvider).itemCount;
    return IconButton(
      tooltip: 'Pedido actual, $count articulos',
      iconSize: 34,
      onPressed: () => openOrderScreen(context),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.primary,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined, color: AppColors.ink),
      ),
    );
  }
}
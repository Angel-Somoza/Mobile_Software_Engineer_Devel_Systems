import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../domain/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${product.title}, ${formatPrice(product.price)}. Toca para agregar al pedido',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: Colors.white,
                      child: ProductThumbnail(
                        title: product.title,
                        url: product.thumbnailUrl,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatPrice(product.price),
                            style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
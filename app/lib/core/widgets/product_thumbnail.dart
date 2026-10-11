import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({super.key, required this.title, this.url});

  final String title;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: AppColors.card,
      child: Center(
        child: Text(
          title.isEmpty ? '?' : title.characters.first.toUpperCase(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ),
    );

    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
    );
  }
}
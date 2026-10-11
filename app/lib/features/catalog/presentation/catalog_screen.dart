import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/state_view.dart';
import '../../order/presentation/cart_button.dart';
import '../../order/presentation/order_providers.dart';
import '../domain/product.dart';
import 'catalog_providers.dart';
import 'product_card.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() => ref.read(catalogRefreshProvider.notifier).refresh();

  void _add(Product product) {
    ref.read(cartControllerProvider.notifier).add(product);
    showFeedback(context, 'Agregado: ${product.title}', icon: Icons.check_circle_outline);
  }

  String _refreshErrorMessage(Object error) {
    if (error is NoConnectionException || error is RequestTimeoutException) {
      return 'Sin conexion. Mostrando el catalogo guardado.';
    }
    return 'No se pudo actualizar ($error). Mostrando el catalogo guardado.';
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final refreshState = ref.watch(catalogRefreshProvider);
    final isRefreshing = refreshState.isLoading;
    final refreshError = refreshState.hasError ? refreshState.error : null;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenHeader(
            title: 'Catalogo',
            subtitle: 'Selecciona tu producto:',
            trailing: CartButton(),
          ),
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(minHeight: 3, color: AppColors.primary),
            ),
          Expanded(
            child: switch (products) {
              AsyncData(:final value) when value.isNotEmpty => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (refreshError != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: InlineNotice(
                            message: _refreshErrorMessage(refreshError),
                            onRetry: isRefreshing ? null : _refresh,
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      sliver: SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: value.length,
                        itemBuilder: (context, index) => ProductCard(
                          product: value[index],
                          onAdd: () => _add(value[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AsyncData() when refreshError != null => StateView(
                icon: Icons.cloud_off_outlined,
                title: 'Sin catalogo guardado',
                message:
                'Conectate a internet para descargar el catalogo por primera vez.',
                actionLabel: 'Reintentar',
                onAction: isRefreshing ? null : _refresh,
              ),
              AsyncError(:final error) => StateView(
                icon: Icons.error_outline,
                title: 'No se pudo leer el catalogo',
                message: '$error',
              ),
              _ => const LoadingView(message: 'Descargando catalogo...'),
            },
          ),
        ],
      ),
    );
  }
}
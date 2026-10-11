import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class ScanButton extends StatelessWidget {
  const ScanButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Escanear codigo QR',
      child: Tooltip(
        message: 'Escanear QR',
        child: SizedBox.square(
          dimension: 72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.scanGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientStart.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 36),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.background,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    final text = base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w300,
          letterSpacing: -0.5,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.outline, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
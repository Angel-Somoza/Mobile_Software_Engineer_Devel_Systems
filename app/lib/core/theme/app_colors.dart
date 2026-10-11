import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFFC8006A);
  static const gradientStart = Color(0xFFF0157D);
  static const gradientEnd = Color(0xFFFF6A13);
  static const ink = Color(0xFF1C1B22);
  static const muted = Color(0xFF6E6A78);
  static const background = Color(0xFFFFFFFF);
  static const card = Color(0xFFF4F2F7);
  static const outline = Color(0xFFE4E0EA);
  static const noticeBackground = Color(0xFFFFF1D6);
  static const noticeText = Color(0xFF6B4100);

  static const scanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );
}
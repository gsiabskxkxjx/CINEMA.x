import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// الثيم الداكن. عمداً لا نضبط ثيمات المكونات التي تغيّرت أنواعها بين إصدارات Flutter
/// (Card/Dialog/TabBar/AppBar/InputDecoration) بل نصمّم المكونات مباشرةً في الودجات.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primary,
        surface: AppColors.surface,
        surfaceTint: Colors.transparent,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerColor: AppColors.divider,
      splashColor: AppColors.primary.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.text),
    );
  }
}

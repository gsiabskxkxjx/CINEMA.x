import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../auth/auth_widgets.dart';

/// شاشة انتظار قصيرة أثناء استعادة الجلسة.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 36),
            SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// وضع الصيانة (يُفعَّل من app_settings.maintenance_mode).
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key, required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.build_circle_outlined,
          title: context.tr('maintenance_title'),
          message: (message != null && message!.trim().isNotEmpty) ? message : context.tr('maintenance_message'),
          actionLabel: context.tr('retry'),
          onAction: onRetry,
        ),
      ),
    );
  }
}

/// حساب محظور.
class BlockedPage extends StatelessWidget {
  const BlockedPage({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.block_rounded,
          title: context.tr('blocked_title'),
          message: context.tr('err_blocked'),
          actionLabel: context.tr('logout'),
          onAction: onSignOut,
        ),
      ),
    );
  }
}

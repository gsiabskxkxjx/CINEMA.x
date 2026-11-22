import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../providers/providers.dart';
import '../auth/login_page.dart';
import '../auth/reset_password_page.dart';
import '../../core/widgets/common_widgets.dart';
import 'gate_pages.dart';
import 'main_shell.dart';

bool _truthy(Object? v) => v == true || v == 'true' || v == 1;

/// البوابة الجذرية:
/// استعادة كلمة المرور → تسجيل الدخول → الحساب المحظور → وضع الصيانة → التطبيق.
/// في الوضع التجريبي (بدون Supabase) تفتح التطبيق مباشرة.
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  StreamSubscription<void>? _recoverySub;

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasBackend) {
      _recoverySub = ref.read(authServiceProvider).passwordRecovery.listen((_) {
        if (mounted) ref.read(recoveryActiveProvider.notifier).state = true;
      });
    }
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasBackend) return const MainShell();

    if (ref.watch(recoveryActiveProvider)) return const ResetPasswordPage();

    final auth = ref.watch(authUserProvider);
    final user = auth.valueOrNull;
    if (user == null) {
      return auth.isLoading ? const SplashPage() : const LoginPage();
    }

    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    if (profile == null) {
      if (profileAsync.hasError) {
        return Scaffold(
          body: SafeArea(
            child: ErrorView(
              error: profileAsync.error!,
              onRetry: () => ref.invalidate(profileProvider),
            ),
          ),
        );
      }
      return const SplashPage();
    }

    if (profile.isBlocked) return BlockedPage(onSignOut: _signOut);

    final settings = ref.watch(publicSettingsProvider).valueOrNull;
    if (settings != null && _truthy(settings['maintenance_mode']) && !profile.isAdmin) {
      return MaintenancePage(
        message: settings['maintenance_message']?.toString(),
        onRetry: () => ref.invalidate(publicSettingsProvider),
      );
    }

    return const MainShell();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';

/// شعار التطبيق النصي.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CINEMA',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: size * 0.26, vertical: size * 0.1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(size * 0.2),
            ),
            child: Text(
              'X',
              style: TextStyle(
                fontSize: size * 0.9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// هيكل صفحات الدخول والتسجيل.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBack = false,
    this.showLanguage = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final bool showLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A0A10), AppColors.background],
                stops: [0, 0.55],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      if (showBack)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      const Spacer(),
                      if (showLanguage)
                        TextButton.icon(
                          onPressed: () => ref
                              .read(localeProvider.notifier)
                              .set(isAr ? 'en' : 'ar', syncProfile: false),
                          icon: const Icon(Icons.language_rounded, size: 18),
                          label: Text(isAr ? 'English' : 'العربية'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: BrandMark()),
                            const SizedBox(height: 28),
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: const TextStyle(color: AppColors.textDim, height: 1.5),
                              ),
                            ],
                            const SizedBox(height: 22),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? validateEmail(BuildContext context, String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return context.tr('v_required');
  if (!_emailRe.hasMatch(t)) return context.tr('v_email');
  return null;
}

String? validatePassword(BuildContext context, String? v) {
  final t = v ?? '';
  if (t.isEmpty) return context.tr('v_required');
  if (t.length < 8) return context.tr('v_password_short');
  return null;
}

String? validateRequired(BuildContext context, String? v) {
  if ((v ?? '').trim().isEmpty) return context.tr('v_required');
  return null;
}

/// زر إظهار/إخفاء كلمة المرور.
class PasswordToggle extends StatelessWidget {
  const PasswordToggle({super.key, required this.obscure, required this.onToggle});

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
      onPressed: onToggle,
    );
  }
}

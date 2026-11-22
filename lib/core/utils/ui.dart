import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';

/// انتقال صفحات سينمائي: تلاشي + انزلاق خفيف.
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.cardHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Text(message, style: const TextStyle(color: AppColors.textDim)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('cancel'), style: const TextStyle(color: AppColors.textDim)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AppColors.danger : AppColors.primary,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? ctx.tr('confirm')),
        ),
      ],
    ),
  );
  return result ?? false;
}

class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// قائمة اختيار سفلية. القيم يجب ألا تكون null (استخدم نصاً مثل 'all').
Future<T?> showChoiceSheet<T extends Object>(
  BuildContext context, {
  required String title,
  required List<ChoiceOption<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardHigh,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      title: Text(o.label),
                      subtitle: o.subtitle == null
                          ? null
                          : Text(o.subtitle!, style: const TextStyle(color: AppColors.textDim)),
                      trailing: o.value == selected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(ctx, o.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

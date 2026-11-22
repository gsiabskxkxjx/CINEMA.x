import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/providers.dart';
import 'auth_widgets.dart';

/// تعيين كلمة مرور جديدة بعد فتح رابط الاستعادة (تعرضها البوابة الجذرية).
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).updatePassword(_password.text);
      if (!mounted) return;
      showAppSnack(context, context.tr('password_updated'));
      ref.read(recoveryActiveProvider.notifier).state = false;
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    // إلغاء: نخرج من وضع الاستعادة ونسجّل الخروج لتفادي بقاء جلسة مؤقتة.
    final auth = ref.read(authServiceProvider);
    ref.read(recoveryActiveProvider.notifier).state = false;
    try {
      await auth.signOut();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('reset_title'),
      subtitle: context.tr('reset_subtitle'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _password,
              label: context.tr('new_password'),
              hint: context.tr('password_hint'),
              icon: Icons.lock_outline_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.next,
              textDirection: TextDirection.ltr,
              validator: (v) => validatePassword(context, v),
              suffix: PasswordToggle(
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _confirm,
              label: context.tr('confirm_password'),
              icon: Icons.lock_reset_rounded,
              obscure: _obscure,
              textInputAction: TextInputAction.done,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _submit(),
              validator: (v) {
                if ((v ?? '').isEmpty) return context.tr('v_required');
                if (v != _password.text) return context.tr('v_password_mismatch');
                return null;
              },
            ),
            const SizedBox(height: 22),
            PrimaryButton(label: context.tr('save'), loading: _busy, onPressed: _submit),
            const SizedBox(height: 8),
            TextButton(onPressed: _busy ? null : _cancel, child: Text(context.tr('cancel'))),
          ],
        ),
      ),
    );
  }
}

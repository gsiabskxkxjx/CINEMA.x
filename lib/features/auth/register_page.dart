import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/providers.dart';
import 'auth_widgets.dart';

/// إنشاء حساب جديد.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final signedIn = await ref.read(authServiceProvider).signUp(
            email: _email.text,
            password: _password.text,
            name: _name.text,
          );
      if (!mounted) return;
      if (signedIn) {
        // البوابة ستعرض التطبيق تلقائياً؛ نغلق صفحات الدخول المتراكمة.
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.mark_email_read_outlined, size: 40),
            title: Text(ctx.tr('confirm_email_title')),
            content: Text(ctx.tr('confirm_email_message')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.tr('ok')),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('register_title'),
      subtitle: context.tr('register_subtitle'),
      showBack: true,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                label: context.tr('display_name'),
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) => validateRequired(context, v),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _email,
                label: context.tr('email'),
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                validator: (v) => validateEmail(context, v),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _password,
                label: context.tr('password'),
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
              PrimaryButton(label: context.tr('create_account'), loading: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

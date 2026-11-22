import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/providers.dart';
import 'auth_widgets.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

/// تسجيل الدخول (هي الصفحة الجذر عند عدم وجود جلسة).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signIn(email: _email.text, password: _password.text);
      // عند النجاح يتغيّر authUserProvider فتنتقل البوابة تلقائياً إلى التطبيق.
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('login_title'),
      subtitle: context.tr('login_subtitle'),
      showLanguage: true,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                textDirection: TextDirection.ltr,
                onSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').isEmpty ? context.tr('v_required') : null,
                suffix: PasswordToggle(
                  obscure: _obscure,
                  onToggle: () => setState(() => _obscure = !_obscure),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(appRoute<void>(const ForgotPasswordPage())),
                  child: Text(context.tr('forgot_password')),
                ),
              ),
              const SizedBox(height: 4),
              PrimaryButton(label: context.tr('login'), loading: _busy, onPressed: _submit),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.tr('no_account'), style: const TextStyle(color: AppColors.textDim)),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(appRoute<void>(const RegisterPage())),
                    child: Text(context.tr('register')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

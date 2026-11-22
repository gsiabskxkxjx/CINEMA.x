import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/providers.dart';
import 'auth_widgets.dart';

/// طلب رابط استعادة كلمة المرور.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).resetPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: context.tr('forgot_title'),
      subtitle: context.tr('forgot_subtitle'),
      showBack: true,
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.trf('reset_sent', {'email': _email.text.trim()}),
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: context.tr('back_to_login'),
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ],
            )
          : Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _email,
                    label: context.tr('email'),
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    textDirection: TextDirection.ltr,
                    onSubmitted: (_) => _submit(),
                    validator: (v) => validateEmail(context, v),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: context.tr('send_reset_link'),
                    loading: _busy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../auth/auth_widgets.dart';
import 'account_page.dart';

/// تعديل الاسم والصورة وتغيير كلمة المرور.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  final _passForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  bool _initialized = false;
  bool _savingName = false;
  bool _uploading = false;
  bool _savingPass = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _savingName = true);
    try {
      await ref.read(userRepoProvider).updateProfile({'display_name': _name.text.trim()});
      ref.invalidate(profileProvider);
      if (mounted) showAppSnack(context, context.tr('saved'));
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      final dot = file.name.lastIndexOf('.');
      final ext = dot == -1 ? 'jpg' : file.name.substring(dot + 1);
      await ref.read(userRepoProvider).uploadAvatar(bytes, ext);
      ref.invalidate(profileProvider);
      if (mounted) showAppSnack(context, context.tr('saved'));
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (!_passForm.currentState!.validate()) return;
    setState(() => _savingPass = true);
    try {
      await ref.read(authServiceProvider).updatePassword(_newPassword.text);
      _newPassword.clear();
      _confirm.clear();
      if (mounted) showAppSnack(context, context.tr('password_updated'));
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profileProvider);
    final AppProfile? profile = async.valueOrNull;
    if (profile != null && !_initialized) {
      _name.text = profile.displayName ?? '';
      _email.text = profile.email ?? '';
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('edit_profile'))),
      body: profile == null
          ? (async.hasError
              ? ErrorView(error: async.error!, onRetry: () => ref.invalidate(profileProvider))
              : const Center(child: CircularProgressIndicator(color: AppColors.primary)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ProfileAvatar(url: profile.avatarUrl, name: profile.displayName ?? profile.email ?? '', radius: 52),
                      if (_uploading)
                        Container(
                          width: 104,
                          height: 104,
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                      PositionedDirectional(
                        end: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploading ? null : _pickAvatar,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.photo_camera_outlined, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _name,
                        label: context.tr('display_name'),
                        icon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveName(),
                        validator: (v) => validateRequired(context, v),
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: _email,
                        label: context.tr('email'),
                        icon: Icons.mail_outline_rounded,
                        textDirection: TextDirection.ltr,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(label: context.tr('save'), loading: _savingName, onPressed: _saveName),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(context.tr('change_password'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Form(
                  key: _passForm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _newPassword,
                        label: context.tr('new_password'),
                        hint: context.tr('password_hint'),
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                        validator: (v) => validatePassword(context, v),
                        suffix: PasswordToggle(obscure: _obscure, onToggle: () => setState(() => _obscure = !_obscure)),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _confirm,
                        label: context.tr('confirm_password'),
                        icon: Icons.lock_reset_rounded,
                        obscure: _obscure,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _changePassword(),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return context.tr('v_required');
                          if (v != _newPassword.text) return context.tr('v_password_mismatch');
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(label: context.tr('change_password'), loading: _savingPass, onPressed: _changePassword),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

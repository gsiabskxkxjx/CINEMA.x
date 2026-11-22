import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/providers.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

bool _truthy(Object? v) => v == true || v == 'true' || v == 1;

/// إعدادات التطبيق العامة: الصيانة، الاشتراكات، بريد الدعم.
/// ⚠️ app_settings قابلة للقراءة علناً (حتى قبل الدخول): لا تضع فيها أسراراً.
class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _email = TextEditingController();
  bool _maintenance = false;
  bool _subscriptions = false;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ref.read(adminRepoProvider).settings();
      if (!mounted) return;
      _maintenance = _truthy(s['maintenance_mode']);
      _subscriptions = _truthy(s['subscriptions_enabled']);
      _message.text = s['maintenance_message']?.toString() ?? '';
      _email.text = s['support_email']?.toString() ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(adminRepoProvider);
      await repo.setSetting('maintenance_mode', _maintenance);
      await repo.setSetting('maintenance_message', _message.text.trim());
      await repo.setSetting('subscriptions_enabled', _subscriptions);
      await repo.setSetting('support_email', _email.text.trim());
      ref.invalidate(publicSettingsProvider);
      if (mounted) showAppSnack(context, context.tr('saved'));
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr('admin_app_settings');
    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: ErrorView(error: _error!, onRetry: _load));
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PrimaryButton(label: context.tr('save'), loading: _saving, onPressed: _save),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminSwitch(
              title: context.tr('admin_maintenance'),
              subtitle: context.tr('admin_maintenance_hint'),
              value: _maintenance,
              onChanged: (v) => setState(() => _maintenance = v),
            ),
            const SizedBox(height: 4),
            AppTextField(controller: _message, label: context.tr('admin_maintenance_message'), maxLines: 3),
            const SizedBox(height: 16),
            AdminSwitch(
              title: context.tr('admin_subscriptions'),
              subtitle: context.tr('admin_subscriptions_hint'),
              value: _subscriptions,
              onChanged: (v) => setState(() => _subscriptions = v),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _email,
              label: context.tr('admin_support_email'),
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(t) ? null : context.tr('v_email');
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textDim),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('admin_settings_public_note'), style: const TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

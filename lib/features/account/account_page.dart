import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../admin/admin_home_page.dart';
import '../library/library_page.dart';
import 'about_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'subscription_page.dart';

/// تبويب "حسابي".
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('logout'),
      message: context.tr('logout_confirm'),
      confirmLabel: context.tr('logout'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final nav = Navigator.of(context);
    try {
      await ref.read(authServiceProvider).signOut();
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      if (context.mounted) showAppSnack(context, friendlyError(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final isAdmin = ref.watch(isAdminProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final demo = !AppConfig.hasBackend;

    void push(Widget page) => Navigator.of(context).push(appRoute<void>(page));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(context.tr('nav_account'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _ProfileHeader(
            profile: profile,
            email: user?.email,
            loading: profileAsync.isLoading && profile == null,
            demo: demo,
            onTap: demo ? null : () => push(const EditProfilePage()),
          ),
          if (profileAsync.hasError && profile == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ErrorView(error: profileAsync.error!, onRetry: () => ref.invalidate(profileProvider)),
            ),
          if (demo) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('demo_banner'), style: const TextStyle(height: 1.5, fontSize: 13))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _Group(children: [
            if (!demo)
              _Tile(
                icon: Icons.person_outline_rounded,
                title: context.tr('edit_profile'),
                onTap: () => push(const EditProfilePage()),
              ),
            _Tile(
              icon: Icons.history_rounded,
              title: context.tr('history'),
              onTap: () => push(const HistoryPage()),
            ),
            _Tile(
              icon: Icons.tune_rounded,
              title: context.tr('settings'),
              onTap: () => push(const SettingsPage()),
            ),
            _Tile(
              icon: Icons.workspace_premium_outlined,
              title: context.tr('subscription'),
              onTap: () => push(const SubscriptionPage()),
            ),
          ]),
          if (isAdmin) ...[
            const SizedBox(height: 16),
            _Group(children: [
              _Tile(
                icon: Icons.admin_panel_settings_outlined,
                title: context.tr('admin_panel'),
                subtitle: context.tr('admin_panel_hint'),
                iconColor: AppColors.primary,
                onTap: () => push(const AdminHomePage()),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          _Group(children: [
            _Tile(
              icon: Icons.info_outline_rounded,
              title: context.tr('about'),
              onTap: () => push(const AboutPage()),
            ),
            if (!demo)
              _Tile(
                icon: Icons.logout_rounded,
                title: context.tr('logout'),
                iconColor: AppColors.danger,
                titleColor: AppColors.danger,
                onTap: () => _signOut(context, ref),
              ),
          ]),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.email,
    required this.loading,
    required this.demo,
    required this.onTap,
  });

  final AppProfile? profile;
  final String? email;
  final bool loading;
  final bool demo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = demo
        ? context.tr('demo_user')
        : (profile?.displayName?.trim().isNotEmpty == true ? profile!.displayName! : (email ?? ''));
    return PressableScale(
      scale: 0.99,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            ProfileAvatar(url: profile?.avatarUrl, name: name, radius: 32),
            const SizedBox(width: 14),
            Expanded(
              child: loading
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Skeleton(width: 140, height: 16), SizedBox(height: 8), Skeleton(width: 180, height: 12)],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        if (!demo && email != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(email!, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                          ),
                        if (profile?.isAdmin == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: MiniBadge(context.tr('role_admin'), filled: true, color: AppColors.primary),
                          ),
                      ],
                    ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

/// صورة المستخدم الدائرية مع بديل بالحرف الأول.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.url, required this.name, this.radius = 28});

  final String? url;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    final d = radius * 2;
    return ClipOval(
      child: SizedBox(
        width: d,
        height: d,
        child: (url == null || url!.isEmpty)
            ? Container(
                color: AppColors.primary.withValues(alpha: 0.25),
                alignment: Alignment.center,
                child: Text(initial, style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w800)),
              )
            : AppImage(url: url, width: d, height: d, title: initial, icon: Icons.person_rounded),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: AppColors.card,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const Divider(height: 1, indent: 56, color: AppColors.divider),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.white70),
      title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
      onTap: onTap,
    );
  }
}

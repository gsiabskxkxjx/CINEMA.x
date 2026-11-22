import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/providers.dart';
import '../auth/auth_widgets.dart';

/// حول التطبيق + بيان حقوق المحتوى.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(publicSettingsProvider).valueOrNull;
    final support = settings?['support_email']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('about'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          const Center(child: BrandMark(size: 32)),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '${context.tr('version')} ${AppConfig.version}',
              style: const TextStyle(color: AppColors.textDim),
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(icon: Icons.movie_filter_outlined, title: context.tr('about_what'), body: context.tr('about_what_body')),
          const SizedBox(height: 12),
          _InfoCard(icon: Icons.gavel_rounded, title: context.tr('about_rights'), body: context.tr('about_rights_body')),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.cloud_outlined,
            title: context.tr('about_mode'),
            body: context.tr(AppConfig.hasBackend ? 'about_mode_live' : 'about_mode_demo'),
          ),
          if (support.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.support_agent_rounded,
              title: context.tr('support'),
              body: support,
              ltr: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.body, this.ltr = false});

  final IconData icon;
  final String title;
  final String body;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                  body,
                  textDirection: ltr ? TextDirection.ltr : null,
                  style: const TextStyle(color: AppColors.textDim, height: 1.6, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

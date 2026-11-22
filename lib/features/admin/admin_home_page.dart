import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import 'admin_featured_page.dart';
import 'admin_repository.dart';
import 'admin_settings_page.dart';
import 'admin_taxonomy_page.dart';
import 'admin_titles_page.dart';
import 'admin_users_page.dart';

final adminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(adminRepoProvider).stats(),
);

/// لوحة تحكم المسؤول: إحصائيات + اختصارات الإدارة. تظهر فقط لمن role = admin.
/// الحماية الحقيقية على الخادم (RLS)؛ هذا الفحص لإخفاء الواجهة فقط.
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.lock_outline_rounded, title: context.tr('err_forbidden')),
      );
    }
    final stats = ref.watch(adminStatsProvider);
    void push(Widget page) => Navigator.of(context).push(appRoute<void>(page));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_panel')),
        actions: [
          IconButton(
            tooltip: context.tr('retry'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminStatsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          try {
            await ref.read(adminStatsProvider.future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            stats.when(
              skipLoadingOnReload: true,
              loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (e, _) => SizedBox(height: 220, child: ErrorView(error: e, onRetry: () => ref.invalidate(adminStatsProvider))),
              data: (s) => _StatsView(stats: s),
            ),
            const SizedBox(height: 22),
            Text(context.tr('admin_manage'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.movie_outlined,
              title: context.tr('movies'),
              subtitle: context.tr('admin_movies_hint'),
              onTap: () => push(const AdminTitlesPage(kind: MediaKind.movie)),
            ),
            _MenuTile(
              icon: Icons.tv_rounded,
              title: context.tr('series_plural'),
              subtitle: context.tr('admin_series_hint'),
              onTap: () => push(const AdminTitlesPage(kind: MediaKind.series)),
            ),
            _MenuTile(
              icon: Icons.star_outline_rounded,
              title: context.tr('admin_featured'),
              subtitle: context.tr('admin_featured_hint'),
              onTap: () => push(const AdminFeaturedPage()),
            ),
            _MenuTile(
              icon: Icons.category_outlined,
              title: context.tr('admin_taxonomy'),
              subtitle: context.tr('admin_taxonomy_hint'),
              onTap: () => push(const AdminTaxonomyPage()),
            ),
            _MenuTile(
              icon: Icons.people_outline_rounded,
              title: context.tr('admin_users'),
              subtitle: context.tr('admin_users_hint'),
              onTap: () => push(const AdminUsersPage()),
            ),
            _MenuTile(
              icon: Icons.settings_outlined,
              title: context.tr('admin_app_settings'),
              subtitle: context.tr('admin_app_settings_hint'),
              onTap: () => push(const AdminSettingsPage()),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final byDay = jMapList(stats['views_by_day']);
    final top = jMapList(stats['top_titles']);
    final maxViews = byDay.fold<int>(1, (m, e) => (jInt(e['views']) ?? 0) > m ? (jInt(e['views']) ?? 0) : m);

    Widget stat(String label, Object? value, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(fmtCount(jInt(value) ?? 0), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          stat(context.tr('stat_users'), stats['users'], Icons.people_alt_outlined),
          const SizedBox(width: 10),
          stat(context.tr('stat_new_users'), stats['new_users_7d'], Icons.person_add_alt_outlined),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          stat(context.tr('movies'), stats['movies'], Icons.movie_outlined),
          const SizedBox(width: 10),
          stat(context.tr('series_plural'), stats['series'], Icons.tv_rounded),
          const SizedBox(width: 10),
          stat(context.tr('stat_episodes'), stats['episodes'], Icons.video_library_outlined),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          stat(context.tr('stat_views_total'), stats['views_total'], Icons.visibility_outlined),
          const SizedBox(width: 10),
          stat(context.tr('stat_views_7d'), stats['views_7d'], Icons.trending_up_rounded),
        ]),
        const SizedBox(height: 18),
        Text(context.tr('stat_views_by_day'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in byDay)
                  Expanded(
                    child: _Bar(
                      value: jInt(d['views']) ?? 0,
                      max: maxViews,
                      label: (jStr(d['day']) ?? '').split('-').last,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(context.tr('stat_top_titles'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.cardHigh,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(
                      (ar ? jStr(top[i]['title_ar']) : jStr(top[i]['title_en'])) ??
                          jStr(top[i]['title_ar']) ??
                          jStr(top[i]['title_en']) ??
                          '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      context.tr(jStr(top[i]['kind']) == 'series' ? 'series' : 'movie'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                    ),
                    trailing: Text(fmtCount(jInt(top[i]['view_count']) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.label});

  final int value;
  final int max;
  final String label;

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$value', style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
          const SizedBox(height: 3),
          Flexible(
            child: FractionallySizedBox(
              heightFactor: frac < 0.04 ? 0.04 : frac,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
        onTap: onTap,
      ),
    );
  }
}

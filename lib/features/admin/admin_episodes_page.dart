import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import 'admin_episode_form_page.dart';
import 'admin_repository.dart';
import 'admin_sources_page.dart';
import 'admin_widgets.dart';

final _adminEpisodesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, seasonId) => ref.watch(adminRepoProvider).episodes(seasonId),
);

/// حلقات موسم: إضافة/تعديل/حذف/نشر وإدارة الروابط لكل حلقة.
class AdminEpisodesPage extends ConsumerWidget {
  const AdminEpisodesPage({
    super.key,
    required this.seasonId,
    required this.seasonNumber,
    required this.seriesTitle,
  });

  final String seasonId;
  final int seasonNumber;
  final String seriesTitle;

  Future<void> _openForm(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> existing, {String? id}) async {
    final nextNumber = existing.fold<int>(0, (m, e) => (jInt(e['episode_number']) ?? 0) > m ? (jInt(e['episode_number']) ?? 0) : m) + 1;
    await Navigator.of(context).push(appRoute<void>(
      AdminEpisodeFormPage(seasonId: seasonId, seasonNumber: seasonNumber, id: id, suggestedNumber: nextNumber, seriesTitle: seriesTitle),
    ));
    ref.invalidate(_adminEpisodesProvider(seasonId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Map<String, dynamic> ep) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.tr('admin_delete_episode_confirm'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteEpisode(ep['id'].toString()),
      success: context.tr('deleted'),
    );
    if (done) ref.invalidate(_adminEpisodesProvider(seasonId));
  }

  Future<void> _togglePublished(BuildContext context, WidgetRef ref, Map<String, dynamic> ep) async {
    final next = !(ep['is_published'] == true);
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).saveEpisode(
            id: ep['id'].toString(),
            seasonId: seasonId,
            values: {'is_published': next},
          ),
    );
    if (done) ref.invalidate(_adminEpisodesProvider(seasonId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminEpisodesProvider(seasonId));
    final ar = context.isAr;
    final list = async.valueOrNull ?? const <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.trf('admin_season_n', {'n': seasonNumber}))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context, ref, list),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('admin_add_episode')),
      ),
      body: AdminAsyncList<Map<String, dynamic>>(
        async: async,
        onRetry: () => ref.invalidate(_adminEpisodesProvider(seasonId)),
        emptyIcon: Icons.video_library_outlined,
        emptyTitle: context.tr('admin_no_episodes'),
        builder: (context, rows) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final e = rows[i];
            final n = jInt(e['episode_number']) ?? 1;
            final published = e['is_published'] != false;
            final name = (ar ? jStr(e['title_ar']) : jStr(e['title_en'])) ?? jStr(e['title_ar']) ?? jStr(e['title_en']) ?? context.trf('admin_episode_n', {'n': n});
            return Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () => _openForm(context, ref, rows, id: e['id'].toString()),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AppImage(url: jStr(e['still_url']), width: 72, height: 42, title: '$n'),
                ),
                title: Text('$n. $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Wrap(
                  spacing: 6,
                  children: [
                    MiniBadge(
                      context.tr(published ? 'status_published' : 'status_hidden'),
                      color: published ? AppColors.success : AppColors.textDim,
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  color: AppColors.cardHigh,
                  onSelected: (v) {
                    if (v == 'edit') _openForm(context, ref, rows, id: e['id'].toString());
                    if (v == 'links') {
                      Navigator.of(context).push(appRoute<void>(
                        AdminSourcesPage(episodeId: e['id'].toString(), title: '$seriesTitle · S$seasonNumber E$n'),
                      ));
                    }
                    if (v == 'publish') _togglePublished(context, ref, e);
                    if (v == 'delete') _delete(context, ref, e);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
                    PopupMenuItem(value: 'links', child: Text(context.tr('admin_manage_sources'))),
                    PopupMenuItem(value: 'publish', child: Text(context.tr(published ? 'admin_unpublish' : 'admin_publish'))),
                    PopupMenuItem(value: 'delete', child: Text(context.tr('delete'), style: const TextStyle(color: AppColors.danger))),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

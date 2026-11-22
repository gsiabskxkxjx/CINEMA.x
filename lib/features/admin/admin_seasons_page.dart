import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import 'admin_episodes_page.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

final _adminSeasonsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, seriesId) => ref.watch(adminRepoProvider).seasons(seriesId),
);

/// مواسم مسلسل: إضافة/تعديل/حذف والدخول لحلقات كل موسم.
class AdminSeasonsPage extends ConsumerWidget {
  const AdminSeasonsPage({super.key, required this.seriesId, required this.title});

  final String seriesId;
  final String title;

  Future<void> _edit(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> existing, {Map<String, dynamic>? season}) async {
    final nextNumber = existing.fold<int>(0, (m, e) => (jInt(e['season_number']) ?? 0) > m ? (jInt(e['season_number']) ?? 0) : m) + 1;
    final number = TextEditingController(text: '${season == null ? nextNumber : jInt(season['season_number']) ?? 1}');
    final titleAr = TextEditingController(text: jStr(season?['title_ar']) ?? '');
    final titleEn = TextEditingController(text: jStr(season?['title_en']) ?? '');
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(ctx.tr(season == null ? 'admin_add_season' : 'admin_edit_season')),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: number,
                  label: '${ctx.tr('admin_season_number')} *',
                  keyboardType: TextInputType.number,
                  validator: requiredInt(ctx, min: 1, max: 999),
                ),
                const SizedBox(height: 10),
                AppTextField(controller: titleAr, label: ctx.tr('admin_title_ar')),
                const SizedBox(height: 10),
                AppTextField(controller: titleEn, label: ctx.tr('admin_title_en'), textDirection: TextDirection.ltr),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(ctx.tr('save')),
          ),
        ],
      ),
    );

    final n = toInt(number.text) ?? 1;
    final tAr = nz(titleAr.text);
    final tEn = nz(titleEn.text);
    number.dispose();
    titleAr.dispose();
    titleEn.dispose();
    if (ok != true || !context.mounted) return;

    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).saveSeason(
            id: season?['id']?.toString(),
            seriesId: seriesId,
            number: n,
            titleAr: tAr,
            titleEn: tEn,
          ),
      success: context.tr('saved'),
    );
    if (done) ref.invalidate(_adminSeasonsProvider(seriesId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Map<String, dynamic> season) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.tr('admin_delete_season_confirm'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteSeason(season['id'].toString()),
      success: context.tr('deleted'),
    );
    if (done) ref.invalidate(_adminSeasonsProvider(seriesId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminSeasonsProvider(seriesId));
    final ar = context.isAr;
    final list = async.valueOrNull ?? const <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? context.tr('admin_seasons_section') : title)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _edit(context, ref, list),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('admin_add_season')),
      ),
      body: AdminAsyncList<Map<String, dynamic>>(
        async: async,
        onRetry: () => ref.invalidate(_adminSeasonsProvider(seriesId)),
        emptyIcon: Icons.video_library_outlined,
        emptyTitle: context.tr('admin_no_seasons'),
        builder: (context, rows) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = rows[i];
            final n = jInt(s['season_number']) ?? 1;
            final name = (ar ? jStr(s['title_ar']) : jStr(s['title_en'])) ?? jStr(s['title_ar']) ?? jStr(s['title_en']);
            return Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                title: Text(name ?? context.trf('admin_season_n', {'n': n}), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(context.tr('admin_tap_for_episodes'), style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                onTap: () => Navigator.of(context).push(appRoute<void>(
                  AdminEpisodesPage(
                    seasonId: s['id'].toString(),
                    seasonNumber: n,
                    seriesTitle: title,
                  ),
                )),
                trailing: PopupMenuButton<String>(
                  color: AppColors.cardHigh,
                  onSelected: (v) {
                    if (v == 'edit') _edit(context, ref, rows, season: s);
                    if (v == 'delete') _delete(context, ref, s);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
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

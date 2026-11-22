import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import '../../data/models/models.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

final _adminFeaturedProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepoProvider).featured(),
);

/// ترتيب الأعمال المميّزة في بانر الرئيسية (سحب لإعادة الترتيب) وإزالتها من التمييز.
/// لإضافة عمل: فعّل "عمل مميّز" من صفحة تعديله.
class AdminFeaturedPage extends ConsumerStatefulWidget {
  const AdminFeaturedPage({super.key});

  @override
  ConsumerState<AdminFeaturedPage> createState() => _AdminFeaturedPageState();
}

class _AdminFeaturedPageState extends ConsumerState<AdminFeaturedPage> {
  List<Map<String, dynamic>>? _local;
  bool _saving = false;

  MediaKind _kindOf(Map<String, dynamic> r) => r['_kind'] == 'series' ? MediaKind.series : MediaKind.movie;

  Future<void> _reorder(List<Map<String, dynamic>> list, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final next = [...list];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    setState(() {
      _local = next;
      _saving = true;
    });
    final repo = ref.read(adminRepoProvider);
    final ok = await runAdminAction(context, () async {
      for (var i = 0; i < next.length; i++) {
        await repo.setFeaturedOrder(_kindOf(next[i]), next[i]['id'].toString(), i);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      _local = null;
      ref.invalidate(_adminFeaturedProvider);
    }
  }

  Future<void> _remove(List<Map<String, dynamic>> list, Map<String, dynamic> row) async {
    final ok = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).setFeatured(_kindOf(row), row['id'].toString(), false),
      success: context.tr('saved'),
    );
    if (ok) {
      _local = null;
      ref.invalidate(_adminFeaturedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final async = ref.watch(_adminFeaturedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_featured')),
        bottom: _saving ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary)) : null,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textDim),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr('admin_featured_help'), style: const TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.5))),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(_adminFeaturedProvider)),
              data: (remote) {
                final list = _local ?? remote;
                if (list.isEmpty) {
                  return EmptyState(icon: Icons.star_outline_rounded, title: context.tr('admin_no_featured'));
                }
                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  onReorder: (a, b) => _reorder(list, a, b),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final title = (ar ? jStr(r['title_ar']) : jStr(r['title_en'])) ?? jStr(r['title_ar']) ?? jStr(r['title_en']) ?? '';
                    return Container(
                      key: ValueKey('${r['_kind']}-${r['id']}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AppImage(url: jStr(r['poster_url']), width: 40, height: 58, title: title),
                        ),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Wrap(
                          spacing: 6,
                          children: [
                            MiniBadge(context.tr(r['_kind'] == 'series' ? 'series' : 'movie')),
                            if (r['is_published'] == false) MiniBadge(context.tr('status_hidden'), color: AppColors.danger),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: context.tr('remove'),
                              icon: const Icon(Icons.star_rounded, color: AppColors.gold),
                              onPressed: () => _remove(list, r),
                            ),
                            ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded, color: AppColors.textDim)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

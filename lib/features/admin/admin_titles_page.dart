import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import '../../data/models/models.dart';
import 'admin_repository.dart';
import 'admin_title_form_page.dart';
import 'admin_widgets.dart';

/// معرّف قائمة العناوين: نوع + نص بحث.
class _TitlesQuery {
  const _TitlesQuery(this.kind, this.text);
  final MediaKind kind;
  final String text;

  @override
  bool operator ==(Object other) => other is _TitlesQuery && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);
}

final _adminTitlesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _TitlesQuery>(
  (ref, q) => ref.watch(adminRepoProvider).titles(q.kind, query: q.text),
);

/// قائمة الأفلام أو المسلسلات للمسؤول: بحث، إضافة، تعديل، حذف، نشر/إخفاء.
class AdminTitlesPage extends ConsumerStatefulWidget {
  const AdminTitlesPage({super.key, required this.kind});

  final MediaKind kind;

  @override
  ConsumerState<AdminTitlesPage> createState() => _AdminTitlesPageState();
}

class _AdminTitlesPageState extends ConsumerState<AdminTitlesPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _text = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _text = v.trim());
    });
  }

  _TitlesQuery get _q => _TitlesQuery(widget.kind, _text);

  Future<void> _open({String? id}) async {
    await Navigator.of(context).push(appRoute<void>(AdminTitleFormPage(kind: widget.kind, id: id)));
    ref.invalidate(_adminTitlesProvider);
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final title = jStr(row['title_ar']) ?? jStr(row['title_en']) ?? '';
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.trf('admin_delete_title_confirm', {'title': title}),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteTitle(widget.kind, row['id'].toString()),
      success: context.tr('deleted'),
    );
    if (done) ref.invalidate(_adminTitlesProvider);
  }

  Future<void> _togglePublished(Map<String, dynamic> row) async {
    final next = !(row['is_published'] == true);
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).setPublished(widget.kind, row['id'].toString(), next),
    );
    if (done) ref.invalidate(_adminTitlesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final async = ref.watch(_adminTitlesProvider(_q));
    final isMovie = widget.kind == MediaKind.movie;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr(isMovie ? 'movies' : 'series_plural'))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _open(),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr(isMovie ? 'admin_add_movie' : 'admin_add_series')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppTextField(
              controller: _search,
              label: context.tr('search_hint'),
              icon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _debounce?.cancel();
                setState(() => _text = v.trim());
              },
              suffix: IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _debounce?.cancel();
                  _search.clear();
                  setState(() => _text = '');
                },
              ),
            ),
          ),
          Expanded(
            child: AdminAsyncList<Map<String, dynamic>>(
              async: async,
              onRetry: () => ref.invalidate(_adminTitlesProvider),
              emptyIcon: Icons.movie_filter_outlined,
              emptyTitle: context.tr('empty_results'),
              builder: (context, rows) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(_adminTitlesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final published = r['is_published'] == true;
                    final title = (ar ? jStr(r['title_ar']) : jStr(r['title_en'])) ??
                        jStr(r['title_ar']) ??
                        jStr(r['title_en']) ??
                        '';
                    return Container(
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onTap: () => _open(id: r['id'].toString()),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AppImage(url: jStr(r['poster_url']), width: 44, height: 64, title: title),
                        ),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (jInt(r['release_year']) != null)
                              Text('${r['release_year']}', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                            Text('👁 ${fmtCount(jInt(r['view_count']) ?? 0)}', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                            MiniBadge(
                              context.tr(published ? 'status_published' : 'status_hidden'),
                              color: published ? AppColors.success : AppColors.textDim,
                            ),
                            if (r['is_featured'] == true) MiniBadge(context.tr('status_featured'), color: AppColors.gold),
                            if (r['is_premium'] == true) const MiniBadge('PREMIUM', color: AppColors.gold),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          color: AppColors.cardHigh,
                          onSelected: (v) {
                            if (v == 'edit') _open(id: r['id'].toString());
                            if (v == 'publish') _togglePublished(r);
                            if (v == 'delete') _delete(r);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(context.tr('edit'))),
                            PopupMenuItem(
                              value: 'publish',
                              child: Text(context.tr(published ? 'admin_unpublish' : 'admin_publish')),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.tr('delete'), style: const TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

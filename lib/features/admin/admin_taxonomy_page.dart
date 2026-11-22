import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

final _adminCategoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepoProvider).categories(),
);

final RegExp _slugRe = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

String? _slugValidator(BuildContext ctx, String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return ctx.tr('v_required');
  return _slugRe.hasMatch(t) ? null : ctx.tr('v_slug');
}

/// إدارة الأنواع الفنية (genres) وفئات الصفحة الرئيسية (categories).
class AdminTaxonomyPage extends ConsumerStatefulWidget {
  const AdminTaxonomyPage({super.key});

  @override
  ConsumerState<AdminTaxonomyPage> createState() => _AdminTaxonomyPageState();
}

class _AdminTaxonomyPageState extends ConsumerState<AdminTaxonomyPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ genres
  Future<void> _editGenre({Map<String, dynamic>? row}) async {
    final slug = TextEditingController(text: jStr(row?['slug']) ?? '');
    final nameAr = TextEditingController(text: jStr(row?['name_ar']) ?? '');
    final nameEn = TextEditingController(text: jStr(row?['name_en']) ?? '');
    final order = TextEditingController(text: '${jInt(row?['sort_order']) ?? 0}');
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        scrollable: true,
        title: Text(ctx.tr(row == null ? 'admin_add_genre' : 'admin_edit_genre')),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameAr, label: '${ctx.tr('admin_title_ar')} *', validator: (v) => (v ?? '').trim().isEmpty ? ctx.tr('v_required') : null),
              const SizedBox(height: 10),
              AppTextField(controller: nameEn, label: '${ctx.tr('admin_title_en')} *', textDirection: TextDirection.ltr, validator: (v) => (v ?? '').trim().isEmpty ? ctx.tr('v_required') : null),
              const SizedBox(height: 10),
              AppTextField(controller: slug, label: 'slug *', hint: 'action', textDirection: TextDirection.ltr, validator: (v) => _slugValidator(ctx, v)),
              const SizedBox(height: 10),
              AppTextField(controller: order, label: ctx.tr('admin_sort_order'), keyboardType: TextInputType.number, validator: optionalInt(ctx, min: 0, max: 9999)),
            ],
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

    final values = <String, dynamic>{
      'slug': slug.text.trim(),
      'name_ar': nameAr.text.trim(),
      'name_en': nameEn.text.trim(),
      'sort_order': toInt(order.text) ?? 0,
    };
    slug.dispose();
    nameAr.dispose();
    nameEn.dispose();
    order.dispose();
    if (ok != true || !mounted) return;

    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).saveGenre(id: row?['id']?.toString(), values: values),
      success: context.tr('saved'),
    );
    if (done) ref.invalidate(adminGenresProvider);
  }

  Future<void> _deleteGenre(Map<String, dynamic> row) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.tr('admin_delete_genre_confirm'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteGenre(row['id'].toString()),
      success: context.tr('deleted'),
    );
    if (done) {
      ref.invalidate(adminGenresProvider);
      ref.invalidate(_adminCategoriesProvider);
    }
  }

  // ------------------------------------------------------------------ categories
  Future<void> _editCategory({Map<String, dynamic>? row}) async {
    final genres = await ref.read(adminGenresProvider.future).catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    final ar = context.isAr;
    final slug = TextEditingController(text: jStr(row?['slug']) ?? '');
    final nameAr = TextEditingController(text: jStr(row?['name_ar']) ?? '');
    final nameEn = TextEditingController(text: jStr(row?['name_en']) ?? '');
    final order = TextEditingController(text: '${jInt(row?['sort_order']) ?? 0}');
    var kind = jStr(row?['kind']) ?? 'all';
    var origin = jStr(row?['origin']) ?? 'all';
    var genre = jStr(row?['genre_id']) ?? 'all';
    var layout = jStr(row?['layout']) ?? 'poster';
    var showOnHome = row == null ? true : row['show_on_home'] != false;
    var active = row == null ? true : row['is_active'] != false;
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.card,
          scrollable: true,
          title: Text(ctx.tr(row == null ? 'admin_add_category' : 'admin_edit_category')),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: nameAr, label: '${ctx.tr('admin_title_ar')} *', validator: (v) => (v ?? '').trim().isEmpty ? ctx.tr('v_required') : null),
                const SizedBox(height: 10),
                AppTextField(controller: nameEn, label: '${ctx.tr('admin_title_en')} *', textDirection: TextDirection.ltr, validator: (v) => (v ?? '').trim().isEmpty ? ctx.tr('v_required') : null),
                const SizedBox(height: 10),
                AppTextField(controller: slug, label: 'slug *', hint: 'arabic-series', textDirection: TextDirection.ltr, validator: (v) => _slugValidator(ctx, v)),
                const SizedBox(height: 10),
                ChoiceField<String>(
                  label: ctx.tr('type'),
                  value: kind,
                  options: [
                    ChoiceOption('all', ctx.tr('all')),
                    ChoiceOption('movie', ctx.tr('movies')),
                    ChoiceOption('series', ctx.tr('series_plural')),
                  ],
                  onChanged: (v) => setD(() => kind = v),
                ),
                const SizedBox(height: 10),
                ChoiceField<String>(
                  label: ctx.tr('origin'),
                  value: origin,
                  options: [
                    ChoiceOption('all', ctx.tr('origin_all')),
                    ChoiceOption('arab', ctx.tr('origin_arab')),
                    ChoiceOption('foreign', ctx.tr('origin_foreign')),
                  ],
                  onChanged: (v) => setD(() => origin = v),
                ),
                const SizedBox(height: 10),
                ChoiceField<String>(
                  label: ctx.tr('genre'),
                  value: genre,
                  options: [
                    ChoiceOption('all', ctx.tr('all_genres')),
                    for (final g in genres)
                      ChoiceOption(g['id'].toString(), (ar ? jStr(g['name_ar']) : jStr(g['name_en'])) ?? jStr(g['name_ar']) ?? ''),
                  ],
                  onChanged: (v) => setD(() => genre = v),
                ),
                const SizedBox(height: 10),
                ChoiceField<String>(
                  label: ctx.tr('admin_layout'),
                  value: layout,
                  options: [
                    ChoiceOption('poster', ctx.tr('admin_layout_poster')),
                    ChoiceOption('landscape', ctx.tr('admin_layout_landscape')),
                  ],
                  onChanged: (v) => setD(() => layout = v),
                ),
                const SizedBox(height: 10),
                AppTextField(controller: order, label: ctx.tr('admin_sort_order'), keyboardType: TextInputType.number, validator: optionalInt(ctx, min: 0, max: 9999)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctx.tr('admin_show_on_home')),
                  value: showOnHome,
                  onChanged: (v) => setD(() => showOnHome = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctx.tr('admin_active')),
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
              ],
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
      ),
    );

    final values = <String, dynamic>{
      'slug': slug.text.trim(),
      'name_ar': nameAr.text.trim(),
      'name_en': nameEn.text.trim(),
      'kind': kind == 'all' ? null : kind,
      'origin': origin == 'all' ? null : origin,
      'genre_id': genre == 'all' ? null : genre,
      'layout': layout,
      'sort_order': toInt(order.text) ?? 0,
      'show_on_home': showOnHome,
      'is_active': active,
    };
    slug.dispose();
    nameAr.dispose();
    nameEn.dispose();
    order.dispose();
    if (ok != true || !mounted) return;

    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).saveCategory(id: row?['id']?.toString(), values: values),
      success: context.tr('saved'),
    );
    if (done) ref.invalidate(_adminCategoriesProvider);
  }

  Future<void> _deleteCategory(Map<String, dynamic> row) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.tr('admin_delete_category_confirm'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteCategory(row['id'].toString()),
      success: context.tr('deleted'),
    );
    if (done) ref.invalidate(_adminCategoriesProvider);
  }

  // ------------------------------------------------------------------ واجهة
  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final genres = ref.watch(adminGenresProvider);
    final cats = ref.watch(_adminCategoriesProvider);
    final onGenres = _tabs.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_taxonomy')),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textDim,
          tabs: [Tab(text: context.tr('genres')), Tab(text: context.tr('admin_categories'))],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => onGenres ? _editGenre() : _editCategory(),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr(onGenres ? 'admin_add_genre' : 'admin_add_category')),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          AdminAsyncList<Map<String, dynamic>>(
            async: genres,
            onRetry: () => ref.invalidate(adminGenresProvider),
            emptyIcon: Icons.label_outline_rounded,
            builder: (context, rows) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final g = rows[i];
                return Container(
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onTap: () => _editGenre(row: g),
                    title: Text((ar ? jStr(g['name_ar']) : jStr(g['name_en'])) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(jStr(g['slug']) ?? '', textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _deleteGenre(g)),
                  ),
                );
              },
            ),
          ),
          AdminAsyncList<Map<String, dynamic>>(
            async: cats,
            onRetry: () => ref.invalidate(_adminCategoriesProvider),
            emptyIcon: Icons.view_list_outlined,
            builder: (context, rows) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = rows[i];
                final active = c['is_active'] != false;
                final home = c['show_on_home'] != false;
                return Container(
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onTap: () => _editCategory(row: c),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.cardHigh,
                      child: Text('${jInt(c['sort_order']) ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    title: Text((ar ? jStr(c['name_ar']) : jStr(c['name_en'])) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (jStr(c['kind']) != null) MiniBadge(context.tr(c['kind'] == 'series' ? 'series_plural' : 'movies')),
                        if (jStr(c['origin']) != null) MiniBadge(context.tr(c['origin'] == 'arab' ? 'origin_arab' : 'origin_foreign')),
                        if (!home) MiniBadge(context.tr('admin_hidden_home')),
                        if (!active) MiniBadge(context.tr('status_hidden'), color: AppColors.danger),
                      ],
                    ),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _deleteCategory(c)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

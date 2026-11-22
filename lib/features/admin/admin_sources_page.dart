import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

class _LinksKey {
  const _LinksKey(this.movieId, this.episodeId);
  final String? movieId;
  final String? episodeId;

  @override
  bool operator ==(Object other) => other is _LinksKey && other.movieId == movieId && other.episodeId == episodeId;

  @override
  int get hashCode => Object.hash(movieId, episodeId);
}

final _adminSourcesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _LinksKey>(
  (ref, k) => ref.watch(adminRepoProvider).sources(movieId: k.movieId, episodeId: k.episodeId),
);

final _adminSubtitlesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _LinksKey>(
  (ref, k) => ref.watch(adminRepoProvider).subtitles(movieId: k.movieId, episodeId: k.episodeId),
);

/// روابط الفيديو والترجمات لفيلم أو حلقة. روابط البث تُحمى بـ RLS ولا تصل المستخدم إلا عبر دالة التشغيل.
class AdminSourcesPage extends ConsumerStatefulWidget {
  const AdminSourcesPage({super.key, this.movieId, this.episodeId, required this.title})
      : assert((movieId == null) != (episodeId == null), 'حدّد فيلماً أو حلقة فقط');

  final String? movieId;
  final String? episodeId;
  final String title;

  @override
  ConsumerState<AdminSourcesPage> createState() => _AdminSourcesPageState();
}

class _AdminSourcesPageState extends ConsumerState<AdminSourcesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  _LinksKey get _key => _LinksKey(widget.movieId, widget.episodeId);

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

  // ------------------------------------------------------------------ مصدر فيديو
  Future<void> _editSource({Map<String, dynamic>? row}) async {
    final label = TextEditingController(text: jStr(row?['label']) ?? '');
    final url = TextEditingController(text: jStr(row?['url']) ?? '');
    final height = TextEditingController(text: row?['quality_height'] == null ? '' : '${row!['quality_height']}');
    final order = TextEditingController(text: '${jInt(row?['sort_order']) ?? 0}');
    var type = jStr(row?['type']) ?? 'mp4';
    var typeTouched = row != null;
    var active = row == null ? true : row['is_active'] != false;
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.card,
          scrollable: true,
          title: Text(ctx.tr(row == null ? 'admin_add_source' : 'admin_edit_source')),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: url,
                  label: '${ctx.tr('admin_video_url')} *',
                  hint: 'https://…/video.mp4  |  .m3u8  |  .mpd',
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  validator: requiredUrl(ctx),
                  onChanged: (v) {
                    if (!typeTouched) setD(() => type = guessSourceType(v.trim()));
                  },
                ),
                const SizedBox(height: 10),
                AppTextField(controller: label, label: '${ctx.tr('admin_source_label')} *', hint: '1080p / 720p / Auto', textDirection: TextDirection.ltr, validator: (v) => (v ?? '').trim().isEmpty ? ctx.tr('v_required') : null),
                const SizedBox(height: 10),
                ChoiceField<String>(
                  label: ctx.tr('admin_source_type'),
                  value: type,
                  options: const [
                    ChoiceOption('mp4', 'MP4'),
                    ChoiceOption('hls', 'HLS (M3U8)'),
                    ChoiceOption('dash', 'DASH (MPD)'),
                  ],
                  onChanged: (v) => setD(() {
                    type = v;
                    typeTouched = true;
                  }),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: AppTextField(
                      controller: height,
                      label: ctx.tr('admin_quality_height'),
                      hint: '1080',
                      keyboardType: TextInputType.number,
                      validator: optionalInt(ctx, min: 100, max: 4320),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: order,
                      label: ctx.tr('admin_sort_order'),
                      keyboardType: TextInputType.number,
                      validator: optionalInt(ctx, min: 0, max: 9999),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
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
      'label': label.text.trim(),
      'url': url.text.trim(),
      'type': type,
      'quality_height': toInt(height.text),
      'sort_order': toInt(order.text) ?? 0,
      'is_active': active,
    };
    label.dispose();
    url.dispose();
    height.dispose();
    order.dispose();
    if (ok != true || !mounted) return;

    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).saveSource(
            id: row?['id']?.toString(),
            movieId: widget.movieId,
            episodeId: widget.episodeId,
            values: values,
          ),
      success: context.tr('saved'),
    );
    if (done) ref.invalidate(_adminSourcesProvider(_key));
  }

  Future<void> _deleteSource(Map<String, dynamic> row) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.tr('admin_delete_source_confirm'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteSource(row['id'].toString()),
      success: context.tr('deleted'),
    );
    if (done) ref.invalidate(_adminSourcesProvider(_key));
  }

  // ------------------------------------------------------------------ ترجمة
  Future<void> _editSubtitle({Map<String, dynamic>? row}) async {
    final lang = TextEditingController(text: jStr(row?['language']) ?? '');
    final label = TextEditingController(text: jStr(row?['label']) ?? '');
    final url = TextEditingController(text: jStr(row?['url']) ?? '');
    var format = jStr(row?['format']) ?? 'srt';
    var formatTouched = row != null;
    var isDefault = row?['is_default'] == true;
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.card,
          scrollable: true,
          title: Text(ctx.tr(row == null ? 'admin_add_subtitle' : 'admin_edit_subtitle')),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: url,
                  label: '${ctx.tr('admin_subtitle_url')} *',
                  hint: 'https://…/sub.srt  |  .vtt',
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  validator: requiredUrl(ctx),
                  onChanged: (v) {
                    if (!formatTouched) setD(() => format = guessSubtitleFormat(v.trim()));
                  },
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: AppTextField(
                      controller: lang,
                      label: '${ctx.tr('admin_language_code')} *',
                      hint: 'ar',
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return ctx.tr('v_required');
                        if (!RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z]{2,4})?$').hasMatch(t)) return ctx.tr('v_lang_code');
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: AppTextField(controller: label, label: ctx.tr('admin_source_label'), hint: 'العربية')),
                ]),
                const SizedBox(height: 10),
                ChoiceField<String>(
                  label: ctx.tr('admin_subtitle_format'),
                  value: format,
                  options: const [ChoiceOption('srt', 'SRT'), ChoiceOption('vtt', 'VTT')],
                  onChanged: (v) => setD(() {
                    format = v;
                    formatTouched = true;
                  }),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctx.tr('admin_default_subtitle')),
                  value: isDefault,
                  onChanged: (v) => setD(() => isDefault = v),
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
      'language': lang.text.trim().toLowerCase(),
      'label': nz(label.text),
      'url': url.text.trim(),
      'format': format,
      'is_default': isDefault,
    };
    lang.dispose();
    label.dispose();
    url.dispose();
    if (ok != true || !mounted) return;

    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).saveSubtitle(
            id: row?['id']?.toString(),
            movieId: widget.movieId,
            episodeId: widget.episodeId,
            values: values,
          ),
      success: context.tr('saved'),
    );
    if (done) ref.invalidate(_adminSubtitlesProvider(_key));
  }

  Future<void> _deleteSubtitle(Map<String, dynamic> row) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.tr('admin_delete_subtitle_confirm'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteSubtitle(
            row['id'].toString(),
            movieId: widget.movieId,
            episodeId: widget.episodeId,
          ),
      success: context.tr('deleted'),
    );
    if (done) ref.invalidate(_adminSubtitlesProvider(_key));
  }

  // ------------------------------------------------------------------ واجهة
  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(_adminSourcesProvider(_key));
    final subs = ref.watch(_adminSubtitlesProvider(_key));
    final onSourcesTab = _tabs.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? context.tr('admin_manage_sources') : widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textDim,
          tabs: [
            Tab(text: context.tr('admin_video_sources')),
            Tab(text: context.tr('subtitles')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => onSourcesTab ? _editSource() : _editSubtitle(),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr(onSourcesTab ? 'admin_add_source' : 'admin_add_subtitle')),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr('admin_rights_notice'), style: const TextStyle(fontSize: 12.5, height: 1.5))),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                AdminAsyncList<Map<String, dynamic>>(
                  async: sources,
                  onRetry: () => ref.invalidate(_adminSourcesProvider(_key)),
                  emptyIcon: Icons.link_off_rounded,
                  emptyTitle: context.tr('admin_no_sources'),
                  builder: (context, rows) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final active = r['is_active'] != false;
                      return Container(
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          onTap: () => _editSource(row: r),
                          leading: MiniBadge((jStr(r['type']) ?? 'mp4').toUpperCase(), filled: true, color: AppColors.primary),
                          title: Text(jStr(r['label']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            jStr(r['url']) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!active) MiniBadge(context.tr('status_hidden')),
                              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _deleteSource(r)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AdminAsyncList<Map<String, dynamic>>(
                  async: subs,
                  onRetry: () => ref.invalidate(_adminSubtitlesProvider(_key)),
                  emptyIcon: Icons.subtitles_off_outlined,
                  emptyTitle: context.tr('admin_no_subtitles'),
                  builder: (context, rows) => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      return Container(
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          onTap: () => _editSubtitle(row: r),
                          leading: MiniBadge((jStr(r['language']) ?? '').toUpperCase(), filled: true, color: AppColors.primary),
                          title: Text(jStr(r['label']) ?? (jStr(r['language']) ?? '').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            jStr(r['url']) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MiniBadge((jStr(r['format']) ?? 'srt').toUpperCase()),
                              if (r['is_default'] == true) ...[const SizedBox(width: 6), MiniBadge(context.tr('admin_default'), color: AppColors.gold)],
                              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => _deleteSubtitle(r)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

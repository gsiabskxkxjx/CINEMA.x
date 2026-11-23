import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import '../../providers/providers.dart';
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

  // ------------------------------------------------------------------ إضافة مصدر: رابط أو رفع من المعرض
  Future<void> _addSource() async {
    final choice = await showChoiceSheet<String>(
      context,
      title: context.tr('admin_add_source'),
      options: [
        ChoiceOption('link', context.tr('admin_source_from_link'), subtitle: context.tr('admin_source_from_link_sub')),
        ChoiceOption('gallery', context.tr('admin_source_from_gallery'), subtitle: context.tr('admin_source_from_gallery_sub')),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'gallery') {
      await _uploadFromGallery();
    } else {
      await _editSource();
    }
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  /// حدّ الحجم للرفع عبر دالة الخادم (طلب PUT واحد؛ الحد الفعلي عند R2/B2 قرابة 4.99 GiB).
  static const _hostMaxMb = 4700;

  static String _hostName(BuildContext context, String id) {
    switch (id) {
      case 'supabase':
        return 'Supabase Storage';
      case 'r2':
        return 'Cloudflare R2';
      case 'b2':
        return 'Backblaze B2';
      case 's3':
        return context.tr('admin_host_s3');
      default:
        return id;
    }
  }

  /// يختار فيديو من معرض الهاتف، يتحقق من حجمه، يرفعه إلى الاستضافة المختارة ثم ينشئ مصدراً يشير إليه.
  Future<void> _uploadFromGallery() async {
    final repo = ref.read(adminRepoProvider);

    // الاستضافة: Supabase دائماً + ما ضُبط في دالة الخادم من R2 / B2 / S3.
    final hosts = await repo.uploadHosts();
    if (!mounted) return;
    var host = 'supabase';
    if (hosts.length > 1) {
      final choice = await showChoiceSheet<String>(
        context,
        title: context.tr('admin_choose_host'),
        options: [
          for (final h in hosts)
            ChoiceOption(h, _hostName(context, h), subtitle: context.tr('admin_host_${h}_sub')),
        ],
      );
      if (choice == null || !mounted) return;
      host = choice;
    }

    XFile? picked;
    try {
      picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } catch (_) {
      if (mounted) showAppSnack(context, context.tr('err_upload'), error: true);
      return;
    }
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    int size;
    try {
      size = await file.length();
    } catch (_) {
      if (mounted) showAppSnack(context, context.tr('err_upload'), error: true);
      return;
    }

    // الحدّ الفعلي يفرضه الخادم؛ هذه القيمة لفحص مبكر فقط.
    // Supabase: app_settings.max_upload_mb (الافتراضي 50). غيره: حدّ الطلب الواحد.
    var maxMb = _hostMaxMb;
    if (host == 'supabase') {
      maxMb = 50;
      try {
        final settings = await ref.read(publicSettingsProvider.future);
        final v = jInt(settings['max_upload_mb']);
        if (v != null && v > 0) maxMb = v;
      } catch (_) {}
    }
    if (!mounted) return;
    if (size > maxMb * 1024 * 1024) {
      showAppSnack(context, context.trf('admin_upload_too_big', {'size': _mb(size), 'max': maxMb}), error: true);
      return;
    }

    final details = await _askUploadDetails(sizeMb: _mb(size), host: host, big: size > 500 * 1024 * 1024);
    if (details == null || !mounted) return;

    final cancel = VideoUploadCancel();
    final progress = ValueNotifier<List<int>>([0, size]);
    final nav = Navigator.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(ctx.tr('admin_uploading')),
          content: ValueListenableBuilder<List<int>>(
            valueListenable: progress,
            builder: (ctx, v, _) {
              final raw = v[1] == 0 ? 0.0 : v[0] / v[1];
              final double frac = raw > 1.0 ? 1.0 : raw;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: frac, color: AppColors.primary, backgroundColor: AppColors.cardHigh),
                  const SizedBox(height: 10),
                  Text('${_mb(v[0])} / ${_mb(v[1])} MB  (${(frac * 100).round()}%)', textDirection: TextDirection.ltr),
                  const SizedBox(height: 8),
                  Text(ctx.tr('admin_uploading_hint'), style: const TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.5)),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: cancel.cancel, child: Text(ctx.tr('cancel'))),
          ],
        ),
      ),
    ));

    String? url;
    Object? error;
    var cancelled = false;
    try {
      url = await repo.uploadVideo(
        file: file,
        host: host,
        cancel: cancel,
        onProgress: (sent, total) => progress.value = [sent, total],
      );
    } on VideoUploadCancelled {
      cancelled = true;
    } catch (e) {
      error = e;
    }
    if (mounted) nav.pop();
    progress.dispose();
    if (!mounted || cancelled) return;
    final uploaded = url;
    if (error != null || uploaded == null) {
      showAppSnack(context, friendlyError(context, error ?? const AppException('err_upload')), error: true);
      return;
    }

    final done = await runAdminAction(
      context,
      () => repo.saveSource(
        movieId: widget.movieId,
        episodeId: widget.episodeId,
        values: {
          'label': details['label'],
          'url': uploaded,
          'type': 'mp4',
          'quality_height': details['height'],
          'sort_order': 0,
          'is_active': true,
        },
      ),
      success: context.tr('admin_upload_done'),
    );
    if (!done) {
      // فشل إنشاء المصدر: لا نترك ملفاً يتيماً يستهلك المساحة.
      try {
        await repo.removeVideoFile(uploaded);
      } catch (_) {}
      return;
    }
    ref.invalidate(_adminSourcesProvider(_key));
  }

  /// يسأل عن اسم الجودة قبل الرفع. يعيد {'label': String, 'height': int?} أو null عند الإلغاء.
  Future<Map<String, dynamic>?> _askUploadDetails({required String sizeMb, required String host, required bool big}) async {
    final label = TextEditingController(text: 'Auto');
    final height = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        scrollable: true,
        title: Text('${ctx.tr('admin_source_from_gallery')} · ${_hostName(ctx, host)}'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.trf('admin_upload_selected', {'size': sizeMb}), style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
              if (big) ...[
                const SizedBox(height: 8),
                Text(ctx.tr('admin_upload_big_hint'), style: const TextStyle(color: AppColors.gold, fontSize: 12.5, height: 1.5)),
              ],
              const SizedBox(height: 12),
              AppTextField(
                controller: label,
                label: '${ctx.tr('admin_source_label')} *',
                hint: '1080p / 720p / Auto',
                textDirection: TextDirection.ltr,
                validator: (v) => (v ?? '').trim().isEmpty ? ctx.tr('v_required') : null,
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: height,
                label: ctx.tr('admin_quality_height'),
                hint: '1080',
                keyboardType: TextInputType.number,
                validator: optionalInt(ctx, min: 100, max: 4320),
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
            child: Text(ctx.tr('admin_upload_start')),
          ),
        ],
      ),
    );
    final out = <String, dynamic>{'label': label.text.trim(), 'height': toInt(height.text)};
    label.dispose();
    height.dispose();
    return ok == true ? out : null;
  }

  Future<void> _deleteSource(Map<String, dynamic> row) async {
    final url = jStr(row['url']) ?? '';
    final uploaded = AdminRepository.videoPathFromUrl(url) != null;
    final ok = await confirmDialog(
      context,
      title: context.tr('delete'),
      message: context.tr(uploaded ? 'admin_delete_uploaded_confirm' : 'admin_delete_source_confirm_ext'),
      confirmLabel: context.tr('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).deleteSource(row['id'].toString(), url: url.startsWith('https://') ? url : null),
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
        onPressed: () => onSourcesTab ? _addSource() : _editSubtitle(),
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

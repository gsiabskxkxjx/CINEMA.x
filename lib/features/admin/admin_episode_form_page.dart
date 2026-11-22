import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import 'admin_repository.dart';
import 'admin_sources_page.dart';
import 'admin_widgets.dart';

/// نموذج حلقة: رقم، عنوان، وصف، صورة، مدة، المقدمة، نشر + إدارة روابطها.
class AdminEpisodeFormPage extends ConsumerStatefulWidget {
  const AdminEpisodeFormPage({
    super.key,
    required this.seasonId,
    required this.seasonNumber,
    required this.suggestedNumber,
    required this.seriesTitle,
    this.id,
  });

  final String seasonId;
  final int seasonNumber;
  final int suggestedNumber;
  final String seriesTitle;
  final String? id;

  @override
  ConsumerState<AdminEpisodeFormPage> createState() => _AdminEpisodeFormPageState();
}

class _AdminEpisodeFormPageState extends ConsumerState<AdminEpisodeFormPage> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _overviewAr = TextEditingController();
  final _overviewEn = TextEditingController();
  final _still = TextEditingController();
  final _runtime = TextEditingController();
  final _introStart = TextEditingController();
  final _introEnd = TextEditingController();

  String? _id;
  bool _published = true;
  bool _loading = false;
  Object? _loadError;
  bool _saving = false;

  List<TextEditingController> get _all =>
      [_number, _titleAr, _titleEn, _overviewAr, _overviewEn, _still, _runtime, _introStart, _introEnd];

  @override
  void initState() {
    super.initState();
    _id = widget.id;
    if (_id == null) {
      _number.text = '${widget.suggestedNumber}';
    } else {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final rows = await ref.read(adminRepoProvider).episodes(widget.seasonId);
      final r = rows.where((e) => e['id'].toString() == _id).firstOrNull;
      if (!mounted) return;
      if (r == null) throw const AppException('err_not_found');
      String t(String k) => jStr(r[k]) ?? '';
      _number.text = t('episode_number');
      _titleAr.text = t('title_ar');
      _titleEn.text = t('title_en');
      _overviewAr.text = t('overview_ar');
      _overviewEn.text = t('overview_en');
      _still.text = t('still_url');
      _runtime.text = t('runtime_minutes');
      _introStart.text = t('intro_start_seconds');
      _introEnd.text = t('intro_end_seconds');
      _published = r['is_published'] != false;
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      showAppSnack(context, context.tr('v_fix_errors'), error: true);
      return;
    }
    final s = toInt(_introStart.text);
    final e = toInt(_introEnd.text);
    if (s != null && e != null && e <= s) {
      showAppSnack(context, context.tr('v_intro_range'), error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(adminRepoProvider).saveEpisode(
        id: _id,
        seasonId: widget.seasonId,
        values: {
          'episode_number': toInt(_number.text),
          'title_ar': nz(_titleAr.text),
          'title_en': nz(_titleEn.text),
          'overview_ar': nz(_overviewAr.text),
          'overview_en': nz(_overviewEn.text),
          'still_url': nz(_still.text),
          'runtime_minutes': toInt(_runtime.text),
          'intro_start_seconds': s,
          'intro_end_seconds': e,
          'is_published': _published,
        },
      );
      if (!mounted) return;
      setState(() => _id = id);
      showAppSnack(context, context.tr('saved'));
    } catch (err) {
      if (mounted) showAppSnack(context, friendlyError(context, err), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = context.tr(_id == null ? 'admin_add_episode' : 'admin_edit_episode');
    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (_loadError != null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: ErrorView(error: _loadError!, onRetry: _load));
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PrimaryButton(label: context.tr('save'), loading: _saving, onPressed: _save),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppTextField(
              controller: _number,
              label: '${context.tr('admin_episode_number')} *',
              keyboardType: TextInputType.number,
              validator: requiredInt(context, min: 1, max: 9999),
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _titleAr, label: context.tr('admin_title_ar')),
            const SizedBox(height: 12),
            AppTextField(controller: _titleEn, label: context.tr('admin_title_en'), textDirection: TextDirection.ltr),
            const SizedBox(height: 12),
            AppTextField(controller: _overviewAr, label: context.tr('admin_overview_ar'), maxLines: 3),
            const SizedBox(height: 12),
            AppTextField(controller: _overviewEn, label: context.tr('admin_overview_en'), maxLines: 3, textDirection: TextDirection.ltr),
            AdminLabel(context.tr('admin_images')),
            ImageUploadField(
              label: context.tr('admin_still_url'),
              controller: _still,
              bucket: 'stills',
              folder: 'stills',
              aspectRatio: 16 / 9,
              previewWidth: 120,
            ),
            AdminLabel(context.tr('admin_details')),
            AppTextField(
              controller: _runtime,
              label: context.tr('admin_runtime'),
              keyboardType: TextInputType.number,
              validator: optionalInt(context, min: 1, max: 2000),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: AppTextField(
                  controller: _introStart,
                  label: context.tr('admin_intro_start'),
                  keyboardType: TextInputType.number,
                  validator: optionalInt(context, min: 0, max: 86400),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _introEnd,
                  label: context.tr('admin_intro_end'),
                  keyboardType: TextInputType.number,
                  validator: optionalInt(context, min: 0, max: 86400),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            AdminSwitch(title: context.tr('admin_is_published'), subtitle: context.tr('admin_is_published_hint'), value: _published, onChanged: (v) => setState(() => _published = v)),
            AdminLabel(context.tr('admin_links_section')),
            if (_id == null)
              Text(context.tr('admin_save_first'), style: const TextStyle(color: AppColors.textDim, height: 1.5))
            else
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(appRoute<void>(
                  AdminSourcesPage(
                    episodeId: _id,
                    title: '${widget.seriesTitle} · S${widget.seasonNumber} E${_number.text}',
                  ),
                )),
                icon: const Icon(Icons.link_rounded),
                label: Text(context.tr('admin_manage_sources')),
              ),
          ],
        ),
      ),
    );
  }
}

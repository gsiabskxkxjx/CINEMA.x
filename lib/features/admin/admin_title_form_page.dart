import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import '../../data/models/models.dart';
import 'admin_repository.dart';
import 'admin_seasons_page.dart';
import 'admin_sources_page.dart';
import 'admin_widgets.dart';

/// نموذج إضافة/تعديل فيلم أو مسلسل.
class AdminTitleFormPage extends ConsumerStatefulWidget {
  const AdminTitleFormPage({super.key, required this.kind, this.id});

  final MediaKind kind;
  final String? id;

  @override
  ConsumerState<AdminTitleFormPage> createState() => _AdminTitleFormPageState();
}

class _AdminTitleFormPageState extends ConsumerState<AdminTitleFormPage> {
  final _form = GlobalKey<FormState>();

  final _titleAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _overviewAr = TextEditingController();
  final _overviewEn = TextEditingController();
  final _poster = TextEditingController();
  final _backdrop = TextEditingController();
  final _trailer = TextEditingController();
  final _year = TextEditingController();
  final _ageRating = TextEditingController();
  final _country = TextEditingController();
  final _language = TextEditingController();
  final _quality = TextEditingController();
  final _rating = TextEditingController();
  final _runtime = TextEditingController();
  final _director = TextEditingController();
  final _subLangs = TextEditingController();
  final _introStart = TextEditingController();
  final _introEnd = TextEditingController();
  final _featuredOrder = TextEditingController(text: '0');

  String? _id;
  String _origin = 'foreign';
  bool _published = true;
  bool _premium = false;
  bool _featured = false;
  final Set<String> _genreIds = {};
  final List<AdminCast> _cast = [];

  bool _loading = false;
  Object? _loadError;
  bool _saving = false;

  bool get _isMovie => widget.kind == MediaKind.movie;

  List<TextEditingController> get _all => [
        _titleAr, _titleEn, _overviewAr, _overviewEn, _poster, _backdrop, _trailer, _year,
        _ageRating, _country, _language, _quality, _rating, _runtime, _director, _subLangs,
        _introStart, _introEnd, _featuredOrder,
      ];

  @override
  void initState() {
    super.initState();
    _id = widget.id;
    if (_id != null) unawaited(_load());
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
      final r = await ref.read(adminRepoProvider).title(widget.kind, _id!);
      if (!mounted) return;
      String t(String k) => jStr(r[k]) ?? '';
      _titleAr.text = t('title_ar');
      _titleEn.text = t('title_en');
      _overviewAr.text = t('overview_ar');
      _overviewEn.text = t('overview_en');
      _poster.text = t('poster_url');
      _backdrop.text = t('backdrop_url');
      _trailer.text = t('trailer_url');
      _year.text = t('release_year');
      _ageRating.text = t('age_rating');
      _country.text = t('country');
      _language.text = t('language');
      _quality.text = t('quality');
      _rating.text = r['rating'] == null ? '' : '${r['rating']}';
      _runtime.text = t('runtime_minutes');
      _director.text = t('director');
      _subLangs.text = jStrList(r['subtitle_languages']).join(', ');
      _introStart.text = t('intro_start_seconds');
      _introEnd.text = t('intro_end_seconds');
      _featuredOrder.text = '${jInt(r['featured_order']) ?? 0}';
      _origin = jStr(r['origin']) ?? 'foreign';
      _published = r['is_published'] != false;
      _premium = r['is_premium'] == true;
      _featured = r['is_featured'] == true;
      _genreIds
        ..clear()
        ..addAll(jStrList(r['_genre_ids']));
      _cast.clear();
      for (final row in jMapList(r['_cast'])) {
        final a = jMap(row['actors']);
        if (a == null) continue;
        _cast.add(AdminCast(
          actorId: a['id'].toString(),
          name: jStr(a['name_ar']) ?? jStr(a['name_en']) ?? '',
          photoUrl: jStr(a['photo_url']),
          character: jStr(row['character_name']),
        ));
      }
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

  List<String> _parseLangs(String raw) => raw
      .split(RegExp(r'[,\s،]+'))
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      showAppSnack(context, context.tr('v_fix_errors'), error: true);
      return;
    }
    final introS = toInt(_introStart.text);
    final introE = toInt(_introEnd.text);
    if (_isMovie && introS != null && introE != null && introE <= introS) {
      showAppSnack(context, context.tr('v_intro_range'), error: true);
      return;
    }
    final values = <String, dynamic>{
      'title_ar': _titleAr.text.trim(),
      'title_en': nz(_titleEn.text),
      'overview_ar': nz(_overviewAr.text),
      'overview_en': nz(_overviewEn.text),
      'poster_url': nz(_poster.text),
      'backdrop_url': nz(_backdrop.text),
      'trailer_url': nz(_trailer.text),
      'release_year': toInt(_year.text),
      'age_rating': nz(_ageRating.text),
      'country': nz(_country.text),
      'language': nz(_language.text)?.toLowerCase(),
      'origin': _origin,
      'quality': nz(_quality.text),
      'rating': toDouble(_rating.text),
      'runtime_minutes': toInt(_runtime.text),
      'director': nz(_director.text),
      'subtitle_languages': _parseLangs(_subLangs.text),
      if (_isMovie) 'intro_start_seconds': introS,
      if (_isMovie) 'intro_end_seconds': introE,
      'is_featured': _featured,
      'featured_order': toInt(_featuredOrder.text) ?? 0,
      'is_published': _published,
      'is_premium': _premium,
    };
    setState(() => _saving = true);
    try {
      final newId = await ref.read(adminRepoProvider).saveTitle(
            widget.kind,
            id: _id,
            values: values,
            genreIds: _genreIds.toList(),
            cast: _cast,
          );
      if (!mounted) return;
      setState(() => _id = newId);
      showAppSnack(context, context.tr('saved'));
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickGenres() async {
    final genres = await ref.read(adminGenresProvider.future).catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    if (genres.isEmpty) {
      showAppSnack(context, context.tr('admin_no_genres'), error: true);
      return;
    }
    final ar = context.isAr;
    final selected = {..._genreIds};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: Text(context.tr('genres'), style: Theme.of(ctx).textTheme.titleMedium)),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () => Navigator.pop(ctx, selected),
                        child: Text(context.tr('confirm')),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final g in genres)
                        CheckboxListTile(
                          activeColor: AppColors.primary,
                          value: selected.contains(g['id'].toString()),
                          title: Text((ar ? jStr(g['name_ar']) : jStr(g['name_en'])) ?? jStr(g['name_ar']) ?? ''),
                          onChanged: (v) => setSheet(() {
                            final id = g['id'].toString();
                            if (v == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() => _genreIds
        ..clear()
        ..addAll(result));
    }
  }

  Future<void> _addActor() async {
    final actor = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ActorPickerSheet(),
    );
    if (actor == null || !mounted) return;
    final id = actor['id'].toString();
    if (_cast.any((c) => c.actorId == id)) {
      showAppSnack(context, context.tr('admin_actor_exists'));
      return;
    }
    setState(() => _cast.add(AdminCast(
          actorId: id,
          name: jStr(actor['name_ar']) ?? jStr(actor['name_en']) ?? '',
          photoUrl: jStr(actor['photo_url']),
        )));
  }

  Future<void> _editCharacter(AdminCast c) async {
    final ctrl = TextEditingController(text: c.character ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(c.name),
        content: AppTextField(controller: ctrl, label: context.tr('admin_character_name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('confirm'))),
        ],
      ),
    );
    if (ok == true) setState(() => c.character = ctrl.text.trim());
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final genres = ref.watch(adminGenresProvider).valueOrNull ?? const <Map<String, dynamic>>[];
    final title = _id == null
        ? context.tr(_isMovie ? 'admin_add_movie' : 'admin_add_series')
        : context.tr(_isMovie ? 'admin_edit_movie' : 'admin_edit_series');

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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            AdminLabel(context.tr('admin_basic_info')),
            AppTextField(controller: _titleAr, label: '${context.tr('admin_title_ar')} *', validator: (v) => validateRequiredText(context, v)),
            const SizedBox(height: 12),
            AppTextField(controller: _titleEn, label: context.tr('admin_title_en'), textDirection: TextDirection.ltr),
            const SizedBox(height: 12),
            AppTextField(controller: _overviewAr, label: context.tr('admin_overview_ar'), maxLines: 4),
            const SizedBox(height: 12),
            AppTextField(controller: _overviewEn, label: context.tr('admin_overview_en'), maxLines: 4, textDirection: TextDirection.ltr),

            AdminLabel(context.tr('admin_images')),
            ImageUploadField(label: context.tr('admin_poster_url'), controller: _poster, bucket: 'posters', folder: 'posters'),
            const SizedBox(height: 14),
            ImageUploadField(
              label: context.tr('admin_backdrop_url'),
              controller: _backdrop,
              bucket: 'backdrops',
              folder: 'backdrops',
              aspectRatio: 16 / 9,
              previewWidth: 120,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _trailer,
              label: context.tr('admin_trailer_url'),
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              validator: optionalUrl(context),
            ),

            AdminLabel(context.tr('admin_details')),
            Row(children: [
              Expanded(
                child: AppTextField(
                  controller: _year,
                  label: context.tr('year'),
                  keyboardType: TextInputType.number,
                  validator: optionalInt(context, min: 1888, max: 2100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _runtime,
                  label: context.tr(_isMovie ? 'admin_runtime' : 'admin_runtime_episode'),
                  keyboardType: TextInputType.number,
                  validator: optionalInt(context, min: 1, max: 2000),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: AppTextField(
                  controller: _rating,
                  label: context.tr('admin_rating'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    final d = toDouble(t);
                    return (d == null || d < 0 || d > 10) ? context.tr('v_rating_range') : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: _ageRating, label: context.tr('admin_age_rating'), hint: 'PG-13', textDirection: TextDirection.ltr)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: AppTextField(controller: _country, label: context.tr('country'))),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: _language, label: context.tr('admin_language_code'), hint: 'ar / en', textDirection: TextDirection.ltr)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: AppTextField(controller: _quality, label: context.tr('admin_quality'), hint: 'HD / FHD / 4K', textDirection: TextDirection.ltr)),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceField<String>(
                  label: context.tr('origin'),
                  value: _origin,
                  options: [
                    ChoiceOption('arab', context.tr('origin_arab')),
                    ChoiceOption('foreign', context.tr('origin_foreign')),
                  ],
                  onChanged: (v) => setState(() => _origin = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            AppTextField(controller: _director, label: context.tr('director')),
            const SizedBox(height: 12),
            AppTextField(
              controller: _subLangs,
              label: context.tr('admin_subtitle_langs'),
              hint: 'ar, en',
              textDirection: TextDirection.ltr,
            ),
            if (_isMovie) ...[
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
            ],

            AdminLabel(context.tr('genres')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _genreIds)
                  InputChip(
                    label: Text(_genreName(genres, id, ar)),
                    backgroundColor: AppColors.card,
                    side: BorderSide.none,
                    onDeleted: () => setState(() => _genreIds.remove(id)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.tr('admin_choose_genres')),
                  backgroundColor: AppColors.cardHigh,
                  side: BorderSide.none,
                  onPressed: _pickGenres,
                ),
              ],
            ),

            AdminLabel(context.tr('cast')),
            for (final c in _cast)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () => _editCharacter(c),
                  leading: ClipOval(
                    child: AppImage(url: c.photoUrl, width: 42, height: 42, title: c.name.isEmpty ? null : c.name.substring(0, 1), icon: Icons.person_rounded),
                  ),
                  title: Text(c.name),
                  subtitle: (c.character ?? '').isEmpty ? null : Text(c.character!, style: const TextStyle(color: AppColors.textDim)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _cast.remove(c)),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _addActor,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(context.tr('admin_add_actor')),
            ),

            AdminLabel(context.tr('admin_publishing')),
            AdminSwitch(title: context.tr('admin_is_published'), subtitle: context.tr('admin_is_published_hint'), value: _published, onChanged: (v) => setState(() => _published = v)),
            AdminSwitch(title: context.tr('admin_is_premium'), subtitle: context.tr('admin_is_premium_hint'), value: _premium, onChanged: (v) => setState(() => _premium = v)),
            AdminSwitch(title: context.tr('admin_is_featured'), subtitle: context.tr('admin_is_featured_hint'), value: _featured, onChanged: (v) => setState(() => _featured = v)),
            if (_featured)
              AppTextField(
                controller: _featuredOrder,
                label: context.tr('admin_featured_order'),
                keyboardType: TextInputType.number,
                validator: optionalInt(context, min: 0, max: 9999),
              ),

            AdminLabel(context.tr(_isMovie ? 'admin_links_section' : 'admin_seasons_section')),
            if (_id == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.textDim),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('admin_save_first'), style: const TextStyle(color: AppColors.textDim, height: 1.5))),
                ]),
              )
            else if (_isMovie)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(appRoute<void>(
                  AdminSourcesPage(movieId: _id, title: _titleAr.text.trim()),
                )),
                icon: const Icon(Icons.link_rounded),
                label: Text(context.tr('admin_manage_sources')),
              )
            else
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(appRoute<void>(
                  AdminSeasonsPage(seriesId: _id!, title: _titleAr.text.trim()),
                )),
                icon: const Icon(Icons.video_library_outlined),
                label: Text(context.tr('admin_manage_seasons')),
              ),
          ],
        ),
      ),
    );
  }

  String _genreName(List<Map<String, dynamic>> genres, String id, bool ar) {
    final g = genres.where((e) => e['id'].toString() == id).firstOrNull;
    if (g == null) return '…';
    return (ar ? jStr(g['name_ar']) : jStr(g['name_en'])) ?? jStr(g['name_ar']) ?? jStr(g['name_en']) ?? '…';
  }
}

String? validateRequiredText(BuildContext context, String? v) =>
    (v ?? '').trim().isEmpty ? context.tr('v_required') : null;

/// ورقة اختيار ممثل: بحث + إنشاء ممثل جديد.
class _ActorPickerSheet extends ConsumerStatefulWidget {
  const _ActorPickerSheet();

  @override
  ConsumerState<_ActorPickerSheet> createState() => _ActorPickerSheetState();
}

class _ActorPickerSheetState extends ConsumerState<_ActorPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>>? _future;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminRepoProvider).actors();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _future = ref.read(adminRepoProvider).actors(query: v));
    });
  }

  Future<void> _createNew() async {
    final nameAr = TextEditingController(text: _search.text.trim());
    final nameEn = TextEditingController();
    final photo = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(ctx.tr('admin_add_actor')),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: nameAr, label: '${ctx.tr('admin_actor_name_ar')} *', validator: (v) => validateRequiredText(ctx, v)),
                const SizedBox(height: 10),
                AppTextField(controller: nameEn, label: ctx.tr('admin_actor_name_en'), textDirection: TextDirection.ltr),
                const SizedBox(height: 10),
                ImageUploadField(
                  label: ctx.tr('admin_actor_photo'),
                  controller: photo,
                  bucket: 'posters',
                  folder: 'actors',
                  aspectRatio: 1,
                  previewWidth: 60,
                ),
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
    final aAr = nameAr.text.trim();
    final aEn = nz(nameEn.text);
    final aPhoto = nz(photo.text);
    nameAr.dispose();
    nameEn.dispose();
    photo.dispose();
    if (ok != true || !mounted) return;
    setState(() => _creating = true);
    try {
      final row = await ref.read(adminRepoProvider).createActor(nameAr: aAr, nameEn: aEn, photoUrl: aPhoto);
      if (mounted) Navigator.pop(context, row);
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        showAppSnack(context, friendlyError(context, e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppTextField(
                  controller: _search,
                  label: context.tr('admin_search_actor'),
                  icon: Icons.search_rounded,
                  onSubmitted: _onChanged,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                title: Text(context.tr('admin_add_actor')),
                trailing: _creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                onTap: _creating ? null : _createNew,
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
                    }
                    if (snap.hasError) {
                      return Padding(padding: const EdgeInsets.all(16), child: Text(friendlyError(context, snap.error!)));
                    }
                    final rows = snap.data ?? const <Map<String, dynamic>>[];
                    if (rows.isEmpty) {
                      return Padding(padding: const EdgeInsets.all(24), child: Text(context.tr('empty_results'), textAlign: TextAlign.center));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final a = rows[i];
                        final name = (ar ? jStr(a['name_ar']) : jStr(a['name_en'])) ?? jStr(a['name_ar']) ?? jStr(a['name_en']) ?? '';
                        return ListTile(
                          leading: ClipOval(
                            child: AppImage(url: jStr(a['photo_url']), width: 40, height: 40, title: name.isEmpty ? null : name.substring(0, 1), icon: Icons.person_rounded),
                          ),
                          title: Text(name),
                          onTap: () => Navigator.pop(context, a),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

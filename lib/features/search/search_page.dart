import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../discover/catalog_grid.dart';

/// البحث الذكي: اسم عربي/إنجليزي، ممثل، مخرج + فلاتر (نوع، سنة، دولة، تصنيف) + اقتراحات + سجل.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  String _typed = ''; // ما يكتبه المستخدم (للاقتراحات)
  String? _submitted; // الاستعلام المنفّذ (للنتائج)
  CatalogQuery _filters = const CatalogQuery(sort: 'popular');

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _typed = v.trim();
        if (_typed.isEmpty) _submitted = null;
      });
    });
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    _text.text = q;
    _text.selection = TextSelection.collapsed(offset: q.length);
    ref.read(searchHistoryProvider.notifier).add(q);
    setState(() {
      _typed = q;
      _submitted = q;
    });
  }

  void _clear() {
    _text.clear();
    setState(() {
      _typed = '';
      _submitted = null;
    });
    _focus.requestFocus();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<CatalogQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _FiltersSheet(initial: _filters),
    );
    if (result != null && mounted) {
      setState(() {
        _filters = result;
        // بدون نص بحث: عند وجود فلاتر نعرض نتائج التصفح مباشرة، وبدونها نعود لسجل البحث
        if (_typed.isEmpty) _submitted = result.hasFilters ? '' : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _submitted != null;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: _submit,
                    onTap: () {
                      if (_submitted != null && _text.text.isNotEmpty) {
                        setState(() => _submitted = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: context.tr('search_hint'),
                      hintStyle: const TextStyle(color: AppColors.textDim),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textDim),
                      suffixIcon: _text.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
                              onPressed: _clear,
                            ),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _filters.hasFilters,
                  backgroundColor: AppColors.primary,
                  smallSize: 9,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.card),
                    tooltip: context.tr('filters'),
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: showResults
                ? CatalogGrid(
                    query: _filters.copyWith(text: _submitted!.isEmpty ? null : _submitted),
                    emptyTitleKey: 'empty_search',
                    emptyMessageKey: 'empty_search_hint',
                  )
                : (_typed.isEmpty ? _History(onPick: _submit) : _Suggestions(text: _typed, onPick: _submit)),
          ),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) {
      return EmptyState(
        icon: Icons.manage_search_rounded,
        title: context.tr('search_empty_title'),
        message: context.tr('search_empty_message'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.tr('recent_searches'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textDim)),
            ),
            TextButton(
              onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
              child: Text(context.tr('clear_all')),
            ),
          ],
        ),
        for (final q in history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded, color: AppColors.textDim),
            title: Text(q),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textDim),
              onPressed: () => ref.read(searchHistoryProvider.notifier).remove(q),
            ),
            onTap: () => onPick(q),
          ),
      ],
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.text, required this.onPick});

  final String text;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestionsProvider(text));
    return async.when(
      loading: () => const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      ),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(suggestionsProvider(text))),
      data: (list) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search_rounded, color: AppColors.primary),
              title: Text(context.trf('search_for', {'q': text})),
              onTap: () => onPick(text),
            ),
            for (final s in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.north_west_rounded, size: 18, color: AppColors.textDim),
                title: Text(s),
                onTap: () => onPick(s),
              ),
          ],
        );
      },
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.initial});

  final CatalogQuery initial;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late CatalogQuery _q = widget.initial;

  Future<void> _pickYear() async {
    final now = DateTime.now().year;
    final v = await showChoiceSheet<String>(
      context,
      title: context.tr('year'),
      selected: _q.year?.toString() ?? 'all',
      options: [
        ChoiceOption('all', context.tr('all')),
        for (var y = now + 1; y >= 1960; y--) ChoiceOption('$y', '$y'),
      ],
    );
    if (v != null) setState(() => _q = _q.copyWith(year: v == 'all' ? null : int.tryParse(v)));
  }

  Future<void> _pickCountry(List<String> countries) async {
    final v = await showChoiceSheet<String>(
      context,
      title: context.tr('country'),
      selected: _q.country ?? 'all',
      options: [
        ChoiceOption('all', context.tr('all')),
        for (final c in countries) ChoiceOption(c, c),
      ],
    );
    if (v != null) setState(() => _q = _q.copyWith(country: v == 'all' ? null : v));
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final genres = ref.watch(genresProvider).valueOrNull ?? const <Genre>[];
    final countries = ref.watch(countriesProvider).valueOrNull ?? const <String>[];

    Widget label(String key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(context.tr(key), style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
        );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(context.tr('filters'), style: Theme.of(context).textTheme.titleMedium),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _q = const CatalogQuery(sort: 'popular')),
                      child: Text(context.tr('reset')),
                    ),
                  ],
                ),
              ),
              label('type'),
              ChipsRow<String>(
                selected: _q.kind?.name ?? 'all',
                options: [
                  ChipOption('all', context.tr('all')),
                  ChipOption('movie', context.tr('movies')),
                  ChipOption('series', context.tr('series_plural')),
                ],
                onSelected: (v) => setState(() => _q = _q.copyWith(kind: v == 'all' ? null : MediaKind.parse(v))),
              ),
              label('origin'),
              ChipsRow<String>(
                selected: _q.origin ?? 'all',
                options: [
                  ChipOption('all', context.tr('origin_all')),
                  ChipOption('arab', context.tr('origin_arab')),
                  ChipOption('foreign', context.tr('origin_foreign')),
                ],
                onSelected: (v) => setState(() => _q = _q.copyWith(origin: v == 'all' ? null : v)),
              ),
              if (genres.isNotEmpty) ...[
                label('genre'),
                ChipsRow<String>(
                  selected: _q.genreId ?? 'all',
                  options: [
                    ChipOption('all', context.tr('all_genres')),
                    for (final g in genres) ChipOption(g.id, g.name(ar)),
                  ],
                  onSelected: (v) => setState(() => _q = _q.copyWith(genreId: v == 'all' ? null : v)),
                ),
              ],
              label('sort'),
              ChipsRow<String>(
                selected: _q.sort,
                options: [
                  ChipOption('popular', context.tr('sort_popular')),
                  ChipOption('latest', context.tr('sort_latest')),
                  ChipOption('rating', context.tr('sort_rating')),
                  ChipOption('year', context.tr('sort_year')),
                ],
                onSelected: (v) => setState(() => _q = _q.copyWith(sort: v)),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: AppColors.textDim),
                title: Text(context.tr('year')),
                trailing: Text(_q.year?.toString() ?? context.tr('all'),
                    style: const TextStyle(color: AppColors.textDim)),
                onTap: _pickYear,
              ),
              ListTile(
                leading: const Icon(Icons.public_rounded, color: AppColors.textDim),
                title: Text(context.tr('country')),
                trailing: Text(_q.country ?? context.tr('all'), style: const TextStyle(color: AppColors.textDim)),
                onTap: countries.isEmpty ? null : () => _pickCountry(countries),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                  label: context.tr('apply'),
                  onPressed: () => Navigator.pop(context, _q),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

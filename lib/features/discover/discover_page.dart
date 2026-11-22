import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import 'catalog_grid.dart';

final discoverQueryProvider =
    StateProvider<CatalogQuery>((ref) => const CatalogQuery(sort: 'popular'));

/// اكتشف: تصفح الأعمال مع مرشحات (النوع، الأصل، التصنيف، الترتيب).
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(discoverQueryProvider);
    final genres = ref.watch(genresProvider).valueOrNull ?? const <Genre>[];
    final ar = context.isAr;

    void set(CatalogQuery q) => ref.read(discoverQueryProvider.notifier).state = q;

    final header = SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Text(
                context.tr('nav_discover'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ChipsRow<String>(
              selected: query.kind?.name ?? 'all',
              options: [
                ChipOption('all', context.tr('all')),
                ChipOption('movie', context.tr('movies')),
                ChipOption('series', context.tr('series_plural')),
              ],
              onSelected: (v) => set(query.copyWith(kind: v == 'all' ? null : MediaKind.parse(v))),
            ),
            const SizedBox(height: 8),
            ChipsRow<String>(
              selected: query.origin ?? 'all',
              options: [
                ChipOption('all', context.tr('origin_all')),
                ChipOption('arab', context.tr('origin_arab')),
                ChipOption('foreign', context.tr('origin_foreign')),
              ],
              onSelected: (v) => set(query.copyWith(origin: v == 'all' ? null : v)),
            ),
            const SizedBox(height: 8),
            if (genres.isNotEmpty)
              ChipsRow<String>(
                selected: query.genreId ?? 'all',
                options: [
                  ChipOption('all', context.tr('all_genres')),
                  for (final g in genres) ChipOption(g.id, g.name(ar)),
                ],
                onSelected: (v) => set(query.copyWith(genreId: v == 'all' ? null : v)),
              ),
            const SizedBox(height: 8),
            ChipsRow<String>(
              selected: query.sort,
              options: [
                ChipOption('popular', context.tr('sort_popular')),
                ChipOption('latest', context.tr('sort_latest')),
                ChipOption('rating', context.tr('sort_rating')),
                ChipOption('year', context.tr('sort_year')),
              ],
              onSelected: (v) => set(query.copyWith(sort: v)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    return CatalogGrid(
      query: query,
      headerSlivers: [header],
      emptyTitleKey: 'empty_results',
      emptyMessageKey: 'empty_results_hint',
      emptyIcon: Icons.explore_off_outlined,
    );
  }
}

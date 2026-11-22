import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/poster_card.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import 'hero_banner.dart';

/// الصفحة الرئيسية: بانر + أكمل المشاهدة + الأكثر مشاهدة + أحدث الإضافات + الصفوف + قائمتي.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(homeProvider);
    try {
      await ref.read(homeProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Stack(
      children: [
        home.when(
          skipLoadingOnReload: true,
          loading: () => const HomeSkeleton(),
          error: (e, _) => SafeArea(
            child: ErrorView(error: e, onRetry: () => ref.invalidate(homeProvider)),
          ),
          data: (data) {
            final heroItems = data.featured.isNotEmpty ? data.featured : data.latest.take(5).toList();
            if (heroItems.isEmpty && data.rows.isEmpty) {
              return SafeArea(
                child: EmptyState(
                  icon: Icons.movie_filter_outlined,
                  title: context.tr('empty_catalog'),
                  message: context.tr(isAdmin ? 'empty_catalog_admin' : 'empty_catalog_user'),
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              edgeOffset: MediaQuery.paddingOf(context).top + 40,
              onRefresh: () => _refresh(ref),
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (heroItems.isNotEmpty) HeroBanner(items: heroItems),
                  if (!AppConfig.hasBackend) const _DemoBanner(),
                  const _ContinueWatchingRow(),
                  MediaRow(
                    title: context.tr('most_watched'),
                    items: data.mostWatched,
                    onSeeAll: () => openCatalogList(
                      context,
                      title: context.tr('most_watched'),
                      query: const CatalogQuery(sort: 'popular'),
                    ),
                  ),
                  MediaRow(
                    title: context.tr('latest_additions'),
                    items: data.latest,
                    onSeeAll: () => openCatalogList(
                      context,
                      title: context.tr('latest_additions'),
                      query: const CatalogQuery(sort: 'latest'),
                    ),
                  ),
                  for (final row in data.rows)
                    MediaRow(
                      title: row.category.name(context.isAr),
                      items: row.items,
                      landscape: row.category.isLandscape,
                      onSeeAll: () => openCatalogList(
                        context,
                        title: row.category.name(context.isAr),
                        query: CatalogQuery(
                          kind: row.category.kind,
                          origin: row.category.origin,
                          genreId: row.category.genreId,
                          sort: 'popular',
                        ),
                      ),
                    ),
                  const _FavoritesRow(),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
        const Positioned(top: 0, left: 0, right: 0, child: _TopBar()),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC0B0B0F), Color(0x000B0B0F)],
          ),
        ),
        child: Row(
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'CINEMA ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                  ),
                  TextSpan(
                    text: 'X',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('demo_banner'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textDim, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingRow extends ConsumerWidget {
  const _ContinueWatchingRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueWatchingProvider);
    final entries = async.valueOrNull ?? const <WatchEntry>[];
    if (entries.isEmpty) {
      if (async.isLoading) return const RowSkeleton(landscape: true);
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.tr('continue_watching')),
        SizedBox(
          height: 210 * 9 / 16 + MediaQuery.textScalerOf(context).scale(13) * 2.7 + 14,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => WatchCard(
              entry: entries[i],
              onRemove: () async {
                final ok = await confirmDialog(
                  context,
                  title: context.tr('remove_from_continue'),
                  message: entries[i].item.title(context.isAr),
                  confirmLabel: context.tr('remove'),
                  danger: true,
                );
                if (!ok) return;
                await ref.read(userRepoProvider).removeFromHistory(entries[i]);
                ref.invalidate(continueWatchingProvider);
                ref.invalidate(historyProvider);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoritesRow extends ConsumerWidget {
  const _FavoritesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider).valueOrNull ?? const <MediaItem>[];
    return MediaRow(title: context.tr('my_list'), items: favs.take(15).toList());
  }
}

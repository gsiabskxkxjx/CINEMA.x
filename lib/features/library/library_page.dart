import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/poster_card.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../player/play_helpers.dart';

/// قائمتي: المفضلة + سجل المشاهدة.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('nav_my_list'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            TabBar(
              indicatorColor: AppColors.primary,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textDim,
              dividerColor: AppColors.divider,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: context.tr('favorites')),
                Tab(text: context.tr('history')),
              ],
            ),
            const Expanded(
              child: TabBarView(children: [FavoritesTab(), HistoryTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const CustomScrollView(slivers: [SliverGridSkeleton()]),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(favoritesProvider)),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_add_outlined,
            title: context.tr('favorites_empty_title'),
            message: context.tr('favorites_empty_message'),
          );
        }
        final width = MediaQuery.sizeOf(context).width;
        const pad = 16.0;
        const gap = 10.0;
        final cols = ((width - pad * 2 + gap) / (130 + gap)).floor().clamp(3, 8).toInt();
        final itemW = (width - pad * 2 - gap * (cols - 1)) / cols;
        final labelH = MediaQuery.textScalerOf(context).scale(13) * 2.7 + 8;
        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () async => ref.invalidate(favoritesProvider),
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(pad, 14, pad, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 14,
              crossAxisSpacing: gap,
              mainAxisExtent: itemW * 1.5 + labelH,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return PosterCard(
                item: item,
                width: itemW,
                onTap: () => openDetails(context, item),
              );
            },
          ),
        );
      },
    );
  }
}

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key, this.padBottom = 100});

  final double padBottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const ListSkeleton(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(historyProvider)),
      data: (entries) {
        if (entries.isEmpty) {
          return EmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: context.tr('history_empty_title'),
            message: context.tr('history_empty_message'),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          onRefresh: () async => ref.invalidate(historyProvider),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, padBottom),
            itemCount: entries.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: context.tr('clear_history'),
                        message: context.tr('clear_history_confirm'),
                        confirmLabel: context.tr('clear_all'),
                        danger: true,
                      );
                      if (!ok) return;
                      try {
                        await ref.read(userRepoProvider).clearHistory();
                        ref.invalidate(historyProvider);
                        ref.invalidate(continueWatchingProvider);
                      } catch (e) {
                        if (context.mounted) showAppSnack(context, friendlyError(context, e), error: true);
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text(context.tr('clear_history')),
                  ),
                );
              }
              return _HistoryTile(entry: entries[i - 1]);
            },
          ),
        );
      },
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.entry});

  final WatchEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.isAr;
    final ep = entry.episode;
    final title = entry.item.title(ar);
    final url = ep?.stillUrl ?? entry.item.backdropUrl ?? entry.item.posterUrl;
    final sub = ep != null ? 'S${ep.seasonNumber} E${ep.number} • ${ep.displayTitle(ar)}' : context.tr('movie');

    return PressableScale(
      scale: 0.98,
      onTap: () => resumeEntry(context, ref, entry),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(url: url, width: 128, height: 72, title: title),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: entry.completed ? 1 : entry.progress,
                      minHeight: 3,
                      color: AppColors.primary,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                const SizedBox(height: 2),
                Text(
                  '${entry.completed ? context.tr('watched') : context.tr('in_progress')} • ${fmtTimeAgo(entry.updatedAt, ar)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('remove'),
            icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
            onPressed: () async {
              try {
                await ref.read(userRepoProvider).removeFromHistory(entry);
                ref.invalidate(historyProvider);
                ref.invalidate(continueWatchingProvider);
              } catch (e) {
                if (context.mounted) showAppSnack(context, friendlyError(context, e), error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// صفحة سجل المشاهدة المستقلة (تُفتح من حسابي).
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(context.tr('history'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: const HistoryTab(padBottom: 24),
    );
  }
}

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

/// تفاصيل فيلم/مسلسل: الغلاف، القصة، الممثلون، المواسم والحلقات، مشابه.
class DetailsPage extends ConsumerWidget {
  const DetailsPage({super.key, required this.item});

  /// بيانات أولية من القائمة تُعرض فوراً أثناء تحميل التفاصيل الكاملة.
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = MediaRef(item.kind, item.id);
    final async = ref.watch(detailsProvider(key));

    if (async.hasError && !async.hasValue) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: ErrorView(error: async.error!, onRetry: () => ref.invalidate(detailsProvider(key))),
      );
    }
    return Scaffold(
      body: _DetailsBody(item: async.valueOrNull ?? item, loading: async.isLoading),
    );
  }
}

class _DetailsBody extends ConsumerStatefulWidget {
  const _DetailsBody({required this.item, required this.loading});

  final MediaItem item;
  final bool loading;

  @override
  ConsumerState<_DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends ConsumerState<_DetailsBody> {
  String? _seasonId;
  bool _expanded = false;

  Future<void> _toggleFavorite() async {
    try {
      await ref.read(favoritesProvider.notifier).toggle(widget.item);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ar = context.isAr;
    final isSeries = item.isSeries;
    final inList = ref.watch(isFavoriteProvider(item.id));
    final key = MediaRef(item.kind, item.id);

    final contentAsync = isSeries ? ref.watch(seriesContentProvider(item.id)) : null;
    final seriesProgress = isSeries
        ? (ref.watch(seriesProgressProvider(item.id)).valueOrNull ?? const <String, WatchEntry>{})
        : const <String, WatchEntry>{};
    final movieProgress = isSeries ? null : ref.watch(movieProgressProvider(item.id)).valueOrNull;

    // نص زر التشغيل
    var playLabel = context.tr('play');
    if (isSeries) {
      final eps = contentAsync?.valueOrNull?.episodes ?? const <Episode>[];
      if (eps.isNotEmpty) {
        final ep = pickEpisodeToPlay(eps, seriesProgress);
        final entry = seriesProgress[ep.id];
        final resumed = entry != null && !entry.completed && entry.positionSeconds > 10;
        playLabel = '${context.tr(resumed ? 'resume' : 'play')}  S${ep.seasonNumber} E${ep.number}';
      }
    } else if (movieProgress != null && !movieProgress.completed && movieProgress.positionSeconds > 10) {
      playLabel = context.tr('resume');
    }

    final overview = item.overview(ar);
    final metaBadges = <Widget>[
      if (item.rating != null)
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
          const SizedBox(width: 3),
          Text(item.rating!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      if (item.year != null) Text('${item.year}', style: const TextStyle(color: AppColors.textDim)),
      if (item.ageRating != null) MiniBadge(item.ageRating!),
      if (item.quality != null) MiniBadge(item.quality!, filled: true, color: AppColors.primary),
      if (item.runtimeMinutes != null)
        Text(
          isSeries
              ? '${fmtRuntime(item.runtimeMinutes, ar)} ${context.tr('per_episode')}'
              : fmtRuntime(item.runtimeMinutes, ar),
          style: const TextStyle(color: AppColors.textDim),
        ),
      if (item.isPremium) const Icon(Icons.workspace_premium, size: 18, color: AppColors.gold),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ------------------------------------------------------------ الغلاف
        SizedBox(
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(url: item.backdropUrl ?? item.posterUrl, title: item.title(ar)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x990B0B0F), Color(0x000B0B0F), Color(0xFF0B0B0F)],
                    stops: [0, 0.4, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      _CircleButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
                      const Spacer(),
                      _CircleButton(
                        icon: inList ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: inList ? AppColors.primary : Colors.white,
                        onTap: _toggleFavorite,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title(ar),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
              ),
              if ((ar ? item.titleEn : item.titleAr) != null && (ar ? item.titleEn : item.titleAr)!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    ar ? item.titleEn! : item.titleAr,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: metaBadges),
              const SizedBox(height: 16),

              // ------------------------------------------------------------ الأزرار
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.loading ? null : () => startPlayback(context, ref, item),
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: Text(playLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _toggleFavorite,
                    icon: Icon(inList ? Icons.check_rounded : Icons.add_rounded),
                    label: Text(context.tr(inList ? 'in_my_list' : 'my_list')),
                  ),
                ],
              ),

              // ------------------------------------------------------------ القصة
              if (overview != null) ...[
                const SizedBox(height: 18),
                Text(context.tr('story'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: Text(
                    overview,
                    maxLines: _expanded ? null : 4,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDim, height: 1.6),
                  ),
                ),
                if (overview.length > 160)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(context.tr(_expanded ? 'show_less' : 'show_more')),
                    ),
                  ),
              ],

              // ------------------------------------------------------------ الأنواع
              if (item.genres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in item.genres)
                      ActionChip(
                        label: Text(g.name(ar)),
                        backgroundColor: AppColors.card,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        labelStyle: const TextStyle(fontSize: 12.5),
                        onPressed: () => openCatalogList(
                          context,
                          title: g.name(ar),
                          query: CatalogQuery(genreId: g.id, sort: 'popular'),
                        ),
                      ),
                  ],
                ),
              ],

              // ------------------------------------------------------------ معلومات
              const SizedBox(height: 16),
              _InfoRow(label: context.tr('director'), value: item.director),
              _InfoRow(label: context.tr('country'), value: item.country),
              _InfoRow(label: context.tr('language'), value: item.language?.toUpperCase()),
              _InfoRow(
                label: context.tr('subtitles'),
                value: item.subtitleLanguages.isEmpty ? null : item.subtitleLanguages.map((e) => e.toUpperCase()).join(' • '),
              ),
            ],
          ),
        ),

        // ------------------------------------------------------------ الممثلون
        if (item.cast.isNotEmpty) ...[
          SectionHeader(title: context.tr('cast')),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: item.cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final a = item.cast[i];
                final name = a.name(ar);
                return PressableScale(
                  onTap: () => openCatalogList(
                    context,
                    title: name,
                    query: CatalogQuery(text: name, sort: 'popular'),
                  ),
                  child: SizedBox(
                    width: 74,
                    child: Column(
                      children: [
                        ClipOval(
                          child: AppImage(
                            url: a.photoUrl,
                            width: 60,
                            height: 60,
                            title: name.isEmpty ? null : name.substring(0, 1),
                            icon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // ------------------------------------------------------------ المواسم والحلقات
        if (isSeries) _buildEpisodes(context, contentAsync!, seriesProgress),

        // ------------------------------------------------------------ مشابه
        _SimilarRow(refKey: key),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEpisodes(
    BuildContext context,
    AsyncValue<SeriesContent> async,
    Map<String, WatchEntry> progress,
  ) {
    final ar = context.isAr;
    return async.when(
      loading: () => const SizedBox(height: 260, child: ListSkeleton(count: 3)),
      error: (e, _) => SizedBox(
        height: 200,
        child: ErrorView(error: e, onRetry: () => ref.invalidate(seriesContentProvider(widget.item.id))),
      ),
      data: (content) {
        if (content.episodes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.video_library_outlined,
              title: context.tr('no_episodes'),
            ),
          );
        }
        final seasons = content.seasons.isNotEmpty
            ? content.seasons
            : [
                Season(
                  id: content.episodes.first.seasonId,
                  seriesId: widget.item.id,
                  number: content.episodes.first.seasonNumber,
                ),
              ];
        final selected = seasons.any((s) => s.id == _seasonId) ? _seasonId! : seasons.first.id;
        final episodes = content.episodesOf(selected);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: context.tr('episodes')),
            if (seasons.length > 1)
              ChipsRowSeasons(
                seasons: seasons,
                selectedId: selected,
                onSelected: (id) => setState(() => _seasonId = id),
              ),
            const SizedBox(height: 8),
            for (final ep in episodes)
              _EpisodeTile(
                episode: ep,
                entry: progress[ep.id],
                onTap: () => openPlayer(
                  context,
                  ref,
                  PlayerArgs(item: widget.item, episode: ep, episodes: content.episodes),
                ),
                ar: ar,
              ),
          ],
        );
      },
    );
  }
}

class ChipsRowSeasons extends StatelessWidget {
  const ChipsRowSeasons({
    super.key,
    required this.seasons,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Season> seasons;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = seasons[i];
          final sel = s.id == selectedId;
          return ChoiceChip(
            label: Text(s.displayTitle(ar)),
            selected: sel,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.card,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            labelStyle: TextStyle(
              color: sel ? Colors.white : AppColors.textDim,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            ),
            onSelected: (_) => onSelected(s.id),
          );
        },
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.entry, required this.onTap, required this.ar});

  final Episode episode;
  final WatchEntry? entry;
  final VoidCallback onTap;
  final bool ar;

  @override
  Widget build(BuildContext context) {
    final overview = episode.overview(ar);
    final watched = entry?.completed ?? false;
    return PressableScale(
      scale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              height: 74,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(url: episode.stillUrl, width: 132, height: 74, title: '${episode.number}'),
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(watched ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 20),
                      ),
                    ),
                    if (entry != null && entry!.progress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: watched ? 1 : entry!.progress,
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
                  Text(
                    '${episode.number}. ${episode.displayTitle(ar)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  if (episode.runtimeMinutes != null)
                    Text(
                      fmtRuntime(episode.runtimeMinutes, ar),
                      style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                    ),
                  if (overview != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textDim, height: 1.4),
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

class _SimilarRow extends ConsumerWidget {
  const _SimilarRow({required this.refKey});

  final MediaRef refKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(similarProvider(refKey));
    return async.maybeWhen(
      data: (items) => MediaRow(title: context.tr('similar'), items: items),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
          ),
          Expanded(child: Text(value!, style: const TextStyle(fontSize: 13.5, height: 1.4))),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.color = Colors.white});

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

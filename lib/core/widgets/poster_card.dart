import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../features/player/play_helpers.dart';
import '../l10n/app_strings.dart';
import '../nav.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'app_image.dart';
import 'common_widgets.dart';

/// بطاقة عمل (بوستر عمودي أو أفقي) مع تأثير ضغط وشارات.
class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    this.width = 118,
    this.landscape = false,
    this.onTap,
  });

  final MediaItem item;
  final double width;
  final bool landscape;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final h = landscape ? width * 9 / 16 : width * 1.5;
    final url = landscape ? (item.backdropUrl ?? item.posterUrl) : (item.posterUrl ?? item.backdropUrl);
    final title = item.title(ar);
    final sub = [
      if (item.year != null) '${item.year}',
      if (item.isSeries) context.tr('series'),
    ].join(' • ');

    return PressableScale(
      onTap: onTap ?? () => openDetails(context, item),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(url: url, width: width, height: h, title: title, radius: 10),
                  if (item.quality != null)
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      child: MiniBadge(item.quality!, filled: true, color: AppColors.primary),
                    ),
                  if (item.isPremium)
                    const PositionedDirectional(
                      top: 6,
                      end: 6,
                      child: Icon(Icons.workspace_premium, size: 18, color: AppColors.gold),
                    ),
                  if (item.rating != null)
                    PositionedDirectional(bottom: 6, start: 6, child: _RatingPill(item.rating!)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.2),
              ),
          ],
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill(this.rating);

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
          const SizedBox(width: 2),
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// صف أفقي من البطاقات مع عنوان وزر "عرض الكل".
class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.items,
    this.landscape = false,
    this.onSeeAll,
  });

  final String title;
  final List<MediaItem> items;
  final bool landscape;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final w = landscape ? 210.0 : 118.0;
    final imgH = landscape ? w * 9 / 16 : w * 1.5;
    final labelH = MediaQuery.textScalerOf(context).scale(13) * 2.7 + 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: imgH + labelH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => PosterCard(item: items[i], width: w, landscape: landscape),
          ),
        ),
      ],
    );
  }
}

/// بطاقة "أكمل المشاهدة" مع شريط التقدم.
class WatchCard extends ConsumerWidget {
  const WatchCard({super.key, required this.entry, this.width = 210, this.onRemove});

  final WatchEntry entry;
  final double width;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.isAr;
    final h = width * 9 / 16;
    final ep = entry.episode;
    final title = entry.item.title(ar);
    final url = ep?.stillUrl ?? entry.item.backdropUrl ?? entry.item.posterUrl;
    final remaining =
        Duration(seconds: (entry.durationSeconds - entry.positionSeconds).clamp(0, 1 << 30).toInt());
    final sub = ep != null
        ? 'S${ep.seasonNumber} E${ep.number} • ${ep.displayTitle(ar)}'
        : '${fmtClock(remaining)} ${context.tr('remaining')}';

    return PressableScale(
      onTap: () => resumeEntry(context, ref, entry),
      onLongPress: onRemove,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(url: url, width: width, height: h, title: title),
                    Container(color: Colors.black26),
                    Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 1.4),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 24),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: entry.progress,
                        minHeight: 3.5,
                        color: AppColors.primary,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

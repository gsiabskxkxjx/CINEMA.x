import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../player/play_helpers.dart';

/// البانر الكبير لأحدث/أبرز الأعمال (تمرير تلقائي + مؤشرات).
class HeroBanner extends ConsumerStatefulWidget {
  const HeroBanner({super.key, required this.items});

  final List<MediaItem> items;

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.items.length < 2 || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 1.15).clamp(380.0, 560.0).toDouble();
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _HeroSlide(item: widget.items[i]),
          ),
          if (widget.items.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.primary : Colors.white30,
                        borderRadius: BorderRadius.circular(3),
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

class _HeroSlide extends ConsumerWidget {
  const _HeroSlide({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.isAr;
    final title = item.title(ar);
    final inList = ref.watch(isFavoriteProvider(item.id));
    final meta = [
      if (item.year != null) '${item.year}',
      if (item.genres.isNotEmpty) item.genres.take(2).map((g) => g.name(ar)).join(' · '),
      if (item.isSeries) context.tr('series') else context.tr('movie'),
    ].join('  •  ');

    return GestureDetector(
      onTap: () => openDetails(context, item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImage(url: item.posterUrl ?? item.backdropUrl, title: title),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC0B0B0F), Color(0x000B0B0F), Color(0x000B0B0F), Color(0xFF0B0B0F)],
                stops: [0, 0.22, 0.5, 1],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(meta, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => startPlayback(context, ref, item),
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: Text(context.tr('play'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        try {
                          await ref.read(favoritesProvider.notifier).toggle(item);
                        } catch (e) {
                          if (context.mounted) {
                            showAppSnack(context, friendlyError(context, e), error: true);
                          }
                        }
                      },
                      icon: Icon(inList ? Icons.check_rounded : Icons.add_rounded),
                      label: Text(context.tr(inList ? 'in_my_list' : 'my_list')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'skeleton.dart';

/// صورة شبكية مع كاش على القرص، تحميل تدريجي (fade)، وبديل جميل عند الغياب/الفشل.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.title,
    this.radius = 0,
    this.icon = Icons.movie_creation_outlined,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? title;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(width: width, height: height, title: title, icon: icon);
    final u = url;

    Widget child;
    if (u == null || u.isEmpty) {
      child = fallback;
    } else {
      int? cacheWidth;
      final w = width;
      if (w != null && w.isFinite && w > 0) {
        cacheWidth = (w * MediaQuery.devicePixelRatioOf(context)).round();
      }
      child = CachedNetworkImage(
        imageUrl: u,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (context, url) => Skeleton(width: width, height: height, radius: 0),
        errorWidget: (context, url, error) => fallback,
      );
    }

    if (radius > 0) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
    }
    return child;
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.width, this.height, this.title, required this.icon});

  final double? width;
  final double? height;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final hue = ((title ?? '').hashCode.abs() % 360).toDouble();
    final c1 = HSLColor.fromAHSL(1, hue, 0.38, 0.20).toColor();
    final c2 = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.45, 0.10).toColor();
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 28),
          if (title != null && title!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

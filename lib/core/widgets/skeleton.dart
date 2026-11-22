import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// مستطيل لامع لحالات التحميل (Skeleton Loading).
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = 10});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.cardHigh,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// صف أفقي وهمي (عنوان + بطاقات).
class RowSkeleton extends StatelessWidget {
  const RowSkeleton({super.key, this.landscape = false});

  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final w = landscape ? 200.0 : 112.0;
    final h = landscape ? w * 9 / 16 : w * 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Skeleton(width: 140, height: 18, radius: 6),
        ),
        SizedBox(
          height: h + 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: w, height: h),
                const SizedBox(height: 8),
                Skeleton(width: w * 0.7, height: 10, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          Skeleton(width: w, height: w * 1.15, radius: 0),
          const RowSkeleton(),
          const RowSkeleton(landscape: true),
          const RowSkeleton(),
        ],
      ),
    );
  }
}

/// شبكة وهمية داخل CustomScrollView.
class SliverGridSkeleton extends StatelessWidget {
  const SliverGridSkeleton({super.key, this.count = 12});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Skeleton(),
          childCount: count,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const Row(
        children: [
          Skeleton(width: 120, height: 68),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 14, radius: 5),
                SizedBox(height: 8),
                Skeleton(width: 120, height: 10, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

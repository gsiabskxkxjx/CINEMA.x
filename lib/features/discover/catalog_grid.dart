import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/poster_card.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

/// شبكة أعمال مرقّمة (Infinite scroll) مرتبطة باستعلام كتالوج.
/// تُستخدم في اكتشف والبحث وصفحات "عرض الكل".
class CatalogGrid extends ConsumerStatefulWidget {
  const CatalogGrid({
    super.key,
    required this.query,
    this.headerSlivers = const [],
    this.emptyTitleKey = 'empty_results',
    this.emptyMessageKey,
    this.emptyIcon = Icons.search_off_rounded,
  });

  final CatalogQuery query;
  final List<Widget> headerSlivers;
  final String emptyTitleKey;
  final String? emptyMessageKey;
  final IconData emptyIcon;

  @override
  ConsumerState<CatalogGrid> createState() => _CatalogGridState();
}

class _CatalogGridState extends ConsumerState<CatalogGrid> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 500) {
      ref.read(catalogPagerProvider(widget.query).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogPagerProvider(widget.query));
    final notifier = ref.read(catalogPagerProvider(widget.query).notifier);

    final width = MediaQuery.sizeOf(context).width;
    const pad = 16.0;
    const gap = 10.0;
    final cols = math.max(3, ((width - pad * 2 + gap) / (130 + gap)).floor());
    final itemW = (width - pad * 2 - gap * (cols - 1)) / cols;
    final labelH = MediaQuery.textScalerOf(context).scale(13) * 2.7 + 8;

    final Widget body;
    if (!state.initialized && state.error == null) {
      body = const SliverGridSkeleton();
    } else if (state.error != null && state.items.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(error: state.error!, onRetry: notifier.refresh),
      );
    } else if (state.items.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: widget.emptyIcon,
          title: context.tr(widget.emptyTitleKey),
          message: widget.emptyMessageKey == null ? null : context.tr(widget.emptyMessageKey!),
        ),
      );
    } else {
      body = SliverPadding(
        padding: const EdgeInsets.fromLTRB(pad, 8, pad, 16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, i) => PosterCard(item: state.items[i], width: itemW),
            childCount: state.items.length,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: gap,
            mainAxisExtent: itemW * 1.5 + labelH,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...widget.headerSlivers,
          body,
          if (state.loading && state.items.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
              ),
            ),
          if (state.error != null && state.items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: notifier.loadMore,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.tr('retry')),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }
}

/// صف رقائق اختيار أفقي (نوع/أصل/ترتيب/نوع فني).
class ChipsRow<T extends Object> extends StatelessWidget {
  const ChipsRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<ChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final sel = o.value == selected;
          return ChoiceChip(
            label: Text(o.label),
            selected: sel,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.card,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            labelStyle: TextStyle(
              color: sel ? Colors.white : AppColors.textDim,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            onSelected: (_) => onSelected(o.value),
          );
        },
      ),
    );
  }
}

class ChipOption<T> {
  const ChipOption(this.value, this.label);
  final T value;
  final String label;
}

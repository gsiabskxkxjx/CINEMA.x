import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import 'player_page.dart';

/// فتح المشغّل ثم تحديث القوائم المتأثرة عند العودة (أكمل المشاهدة، السجل، تقدّم الحلقات).
Future<void> openPlayer(BuildContext context, WidgetRef ref, PlayerArgs args) async {
  await Navigator.of(context).push(appRoute<void>(PlayerPage(args: args)));
  if (!context.mounted) return;
  ref.invalidate(continueWatchingProvider);
  ref.invalidate(historyProvider);
  if (args.item.kind == MediaKind.series) {
    ref.invalidate(seriesProgressProvider(args.item.id));
  } else {
    ref.invalidate(movieProgressProvider(args.item.id));
  }
}

/// الحلقة المناسبة للتشغيل: آخر حلقة غير مكتملة، أو التالية بعد المكتملة، أو الأولى.
Episode pickEpisodeToPlay(List<Episode> episodes, Map<String, WatchEntry> progress) {
  if (progress.isEmpty) return episodes.first;
  WatchEntry? last;
  for (final e in progress.values) {
    if (last == null || e.updatedAt.isAfter(last.updatedAt)) last = e;
  }
  final lastEpId = last?.episode?.id;
  final idx = episodes.indexWhere((e) => e.id == lastEpId);
  if (idx == -1 || last == null) return episodes.first;
  if (!last.completed) return episodes[idx];
  return idx + 1 < episodes.length ? episodes[idx + 1] : episodes.first;
}

/// تشغيل عمل (فيلم مباشرة، أو المسلسل من الحلقة المناسبة).
Future<void> startPlayback(BuildContext context, WidgetRef ref, MediaItem item) async {
  try {
    if (item.kind == MediaKind.movie) {
      await openPlayer(context, ref, PlayerArgs(item: item));
      return;
    }
    final content = await ref.read(seriesContentProvider(item.id).future);
    if (content.episodes.isEmpty) {
      if (context.mounted) showAppSnack(context, context.tr('no_episodes'), error: true);
      return;
    }
    final progress = await ref.read(userRepoProvider).seriesProgress(item.id);
    if (!context.mounted) return;
    final episode = pickEpisodeToPlay(content.episodes, progress);
    await openPlayer(context, ref, PlayerArgs(item: item, episode: episode, episodes: content.episodes));
  } catch (e) {
    if (context.mounted) showAppSnack(context, friendlyError(context, e), error: true);
  }
}

/// استئناف مدخل من "أكمل المشاهدة".
Future<void> resumeEntry(BuildContext context, WidgetRef ref, WatchEntry entry) async {
  try {
    if (entry.episode == null) {
      await openPlayer(context, ref, PlayerArgs(item: entry.item));
      return;
    }
    final content = await ref.read(seriesContentProvider(entry.item.id).future);
    if (!context.mounted) return;
    final ep = content.episodes.where((e) => e.id == entry.episode!.id).firstOrNull ?? entry.episode!;
    await openPlayer(
      context,
      ref,
      PlayerArgs(item: entry.item, episode: ep, episodes: content.episodes),
    );
  } catch (e) {
    if (context.mounted) showAppSnack(context, friendlyError(context, e), error: true);
  }
}

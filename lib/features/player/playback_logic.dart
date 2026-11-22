import '../../data/models/models.dart';

/// منطق التشغيل البحت (بدون media_kit) ليسهل اختباره.

/// يختار مصدر التشغيل الابتدائي حسب جودة المستخدم المفضلة.
/// [preferred]: auto | 1080 | 720 | 480 | 360
VideoSource pickSource(List<VideoSource> sources, String preferred) {
  assert(sources.isNotEmpty);
  final sorted = [...sources]
    ..sort((a, b) => (b.qualityHeight ?? 0).compareTo(a.qualityHeight ?? 0));

  bool isAdaptive(VideoSource s) => s.type == 'hls' || s.type == 'dash';

  if (preferred == 'auto') {
    // المصدر التكيّفي (HLS/DASH) يختار الجودة بنفسه؛ وإلا فأعلى جودة حتى 1080.
    final adaptive = sorted.where(isAdaptive).toList();
    if (adaptive.isNotEmpty) return adaptive.first;
    final capped = sorted.where((s) => (s.qualityHeight ?? 0) <= 1080).toList();
    return capped.isNotEmpty ? capped.first : sorted.last;
  }

  final target = int.tryParse(preferred) ?? 720;
  final fixed = sorted.where((s) => s.qualityHeight != null).toList();
  if (fixed.isEmpty) return sorted.first;
  final notAbove = fixed.where((s) => s.qualityHeight! <= target).toList();
  // أعلى جودة لا تتجاوز المطلوبة، وإلا أقرب جودة أعلى منها.
  return notAbove.isNotEmpty ? notAbove.first : fixed.last;
}

/// الثواني التي يُستأنف منها التشغيل (0 = من البداية).
int resumePositionSeconds(WatchEntry? entry) {
  if (entry == null || entry.completed) return 0;
  final pos = entry.positionSeconds;
  if (pos < 10) return 0;
  final dur = entry.durationSeconds;
  if (dur > 0 && dur - pos < 15) return 0;
  return pos;
}

/// نافذة تخطي المقدمة (ثوانٍ) أو null.
({int start, int end})? introWindow(MediaItem item, Episode? episode) {
  final s = episode?.introStart ?? item.introStart;
  final e = episode?.introEnd ?? item.introEnd;
  if (s == null || e == null || e <= s) return null;
  return (start: s, end: e);
}

/// الحلقة التالية بعد [current] أو null.
Episode? nextEpisodeOf(List<Episode> episodes, Episode? current) {
  if (current == null) return null;
  final i = episodes.indexWhere((e) => e.id == current.id);
  if (i == -1 || i + 1 >= episodes.length) return null;
  return episodes[i + 1];
}

/// مفتاح الترجمة الافتراضية: off | ext:<id>.
String defaultSubtitleKey(List<SubtitleItem> subtitles, String preferredLanguage) {
  if (preferredLanguage == 'off') return 'off';
  for (final s in subtitles) {
    if (s.language.toLowerCase() == preferredLanguage.toLowerCase()) return 'ext:${s.id}';
  }
  return 'off';
}

/// هل انتهى التشغيل فعلاً (وليس انقطاعاً مبكراً)؟
bool isGenuineEnd(Duration position, Duration duration) {
  if (duration <= Duration.zero) return false;
  return duration - position <= const Duration(seconds: 12);
}

/// عنوان مختصر للحلقة: "S1 · E3".
String episodeTag(Episode e) => 'S${e.seasonNumber} · E${e.number}';

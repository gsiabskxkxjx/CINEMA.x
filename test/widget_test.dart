import 'package:cinema_x/core/l10n/app_strings.dart';
import 'package:cinema_x/core/l10n/strings_ar.dart';
import 'package:cinema_x/core/l10n/strings_en.dart';
import 'package:cinema_x/core/utils/errors.dart';
import 'package:cinema_x/core/utils/formatters.dart';
import 'package:cinema_x/data/demo/demo_repositories.dart';
import 'package:cinema_x/data/models/models.dart';
import 'package:cinema_x/features/player/playback_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبارات وحدة للمنطق البحت (بدون media_kit أو شبكة).
/// تشغيل: flutter test
void main() {
  const movie = MediaItem(id: 'm1', kind: MediaKind.movie, titleAr: 'فيلم');
  const series = MediaItem(id: 's1', kind: MediaKind.series, titleAr: 'مسلسل');

  Episode ep(String id, int n, {int? introStart, int? introEnd}) => Episode(
        id: id,
        seasonId: 'se1',
        seriesId: 's1',
        number: n,
        introStart: introStart,
        introEnd: introEnd,
      );

  WatchEntry entry({int pos = 0, int dur = 0, bool done = false}) => WatchEntry(
        item: movie,
        positionSeconds: pos,
        durationSeconds: dur,
        completed: done,
        updatedAt: DateTime(2026, 1, 1),
      );

  // ------------------------------------------------------------------ الترجمة
  group('الترجمة (i18n)', () {
    test('المفاتيح متطابقة بين العربية والإنجليزية', () {
      expect(kStringsAr.keys.toSet(), kStringsEn.keys.toSet());
    });

    test('لا توجد قيمة فارغة', () {
      for (final e in kStringsAr.entries) {
        expect(e.value.trim(), isNotEmpty, reason: 'ar:${e.key}');
      }
      for (final e in kStringsEn.entries) {
        expect(e.value.trim(), isNotEmpty, reason: 'en:${e.key}');
      }
    });

    test('العناصر النائبة {x} متطابقة في اللغتين', () {
      final re = RegExp(r'\{(\w+)\}');
      for (final k in kStringsAr.keys) {
        final a = re.allMatches(kStringsAr[k]!).map((m) => m.group(1)).toSet();
        final e = re.allMatches(kStringsEn[k]!).map((m) => m.group(1)).toSet();
        expect(a, e, reason: k);
      }
    });

    test('t و tf', () {
      const ar = AppStrings(true);
      const en = AppStrings(false);
      expect(ar.t('nav_home'), 'الرئيسية');
      expect(en.t('nav_home'), 'Home');
      expect(en.t('no_such_key'), 'no_such_key');
      expect(en.tf('next_in', {'n': 7}), 'Next episode in 7s');
      expect(ar.tf('reconnecting', {'n': 2, 'max': 3}), contains('2/3'));
    });

    test('كل مفاتيح الأخطاء التي يعيدها errorKey موجودة', () {
      for (final key in [
        errorKey(const AppException('err_network')),
        errorKey(const FormatException('x')),
      ]) {
        expect(kStringsAr.containsKey(key), isTrue, reason: key);
      }
    });
  });

  // ------------------------------------------------------------------ أدوات
  group('formatters', () {
    test('fmtClock', () {
      expect(fmtClock(const Duration(seconds: 65)), '01:05');
      expect(fmtClock(const Duration(hours: 1, minutes: 5, seconds: 9)), '1:05:09');
      expect(fmtClock(const Duration(seconds: -5)), '00:00');
    });

    test('fmtRuntime', () {
      expect(fmtRuntime(135, false), '2h 15m');
      expect(fmtRuntime(120, true), '2س');
      expect(fmtRuntime(45, false), '45m');
      expect(fmtRuntime(null, false), '');
      expect(fmtRuntime(0, true), '');
    });

    test('fmtCount', () {
      expect(fmtCount(999), '999');
      expect(fmtCount(12500), '12.5K');
      expect(fmtCount(2000000), '2.0M');
    });

    test('تخمين نوع الرابط والترجمة', () {
      expect(guessSourceType('https://x.com/a/index.m3u8?token=1'), 'hls');
      expect(guessSourceType('https://x.com/a/manifest.mpd'), 'dash');
      expect(guessSourceType('https://x.com/a/movie.mp4'), 'mp4');
      expect(guessSubtitleFormat('https://x.com/s.vtt'), 'vtt');
      expect(guessSubtitleFormat('https://x.com/s.srt'), 'srt');
    });

    test('isValidHttpUrl', () {
      expect(isValidHttpUrl('https://example.com/a.mp4'), isTrue);
      expect(isValidHttpUrl('http://example.com'), isTrue);
      expect(isValidHttpUrl('ftp://example.com'), isFalse);
      expect(isValidHttpUrl('example.com'), isFalse);
      expect(isValidHttpUrl(''), isFalse);
      expect(isValidHttpUrl(null), isFalse);
    });

    test('normalizeSearch يوحّد الأحرف العربية', () {
      expect(normalizeSearch('أحمد'), normalizeSearch('احمد'));
      expect(normalizeSearch('مدرسة'), normalizeSearch('مدرسه'));
      expect(normalizeSearch('  HeLLo '), 'hello');
    });
  });

  // ------------------------------------------------------------------ النماذج
  group('النماذج', () {
    test('CatalogQuery: مساواة بالقيمة و copyWith', () {
      const a = CatalogQuery(text: 'x', kind: MediaKind.movie);
      const b = CatalogQuery(text: 'x', kind: MediaKind.movie);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.hasFilters, isTrue);
      expect(const CatalogQuery(text: 'x').hasFilters, isFalse);

      // copyWith يسمح بتصفير الحقول عبر null صريح.
      final cleared = a.copyWith(kind: null);
      expect(cleared.kind, isNull);
      expect(cleared.text, 'x');
      // وبدون تمرير الحقل يبقى كما هو.
      expect(a.copyWith(sort: 'popular').kind, MediaKind.movie);
    });

    test('MediaRef مساواة', () {
      expect(const MediaRef(MediaKind.movie, '1'), const MediaRef(MediaKind.movie, '1'));
      expect(const MediaRef(MediaKind.movie, '1') == const MediaRef(MediaKind.series, '1'), isFalse);
    });

    test('WatchEntry.progress ضمن [0,1]', () {
      expect(entry(pos: 50, dur: 100).progress, 0.5);
      expect(entry(pos: 500, dur: 100).progress, 1);
      expect(entry(pos: 5, dur: 0).progress, 0);
    });

    test('WatchEntry.key يفضّل معرّف الحلقة', () {
      final e = WatchEntry(
        item: series,
        episode: ep('e1', 1),
        positionSeconds: 1,
        durationSeconds: 2,
        completed: false,
        updatedAt: DateTime(2026),
      );
      expect(e.key, 'e1');
      expect(entry().key, 'm1');
    });

    test('AuthUser مساواة', () {
      expect(const AuthUser(id: 'a', email: 'x@y.z'), const AuthUser(id: 'a', email: 'x@y.z'));
      expect(const AuthUser(id: 'a') == const AuthUser(id: 'b'), isFalse);
    });
  });

  // ------------------------------------------------------------------ منطق التشغيل
  group('pickSource', () {
    const s480 = VideoSource(id: '1', label: '480p', url: 'u1', qualityHeight: 480);
    const s720 = VideoSource(id: '2', label: '720p', url: 'u2', qualityHeight: 720);
    const s1080 = VideoSource(id: '3', label: '1080p', url: 'u3', qualityHeight: 1080);
    const s2160 = VideoSource(id: '4', label: '4K', url: 'u4', qualityHeight: 2160);
    const hls = VideoSource(id: '5', label: 'Auto', url: 'u5', type: 'hls');
    final fixed = [s480, s720, s1080, s2160];

    test('auto: أعلى جودة حتى 1080', () {
      expect(pickSource(fixed, 'auto').id, '3');
    });

    test('auto: يفضّل المصدر التكيّفي HLS', () {
      expect(pickSource([...fixed, hls], 'auto').id, '5');
    });

    test('auto: إن كانت كلها فوق 1080 يأخذ الأدنى', () {
      expect(pickSource([s2160], 'auto').id, '4');
    });

    test('جودة محددة: أعلى جودة لا تتجاوز المطلوب', () {
      expect(pickSource(fixed, '720').id, '2');
      expect(pickSource(fixed, '1080').id, '3');
      expect(pickSource(fixed, '360').id, '1'); // لا أقل منها: أقرب أعلى
    });

    test('مصدر وحيد', () {
      expect(pickSource([s720], '1080').id, '2');
      expect(pickSource([hls], '720').id, '5');
    });
  });

  group('resumePositionSeconds', () {
    test('لا سجل أو مكتمل', () {
      expect(resumePositionSeconds(null), 0);
      expect(resumePositionSeconds(entry(pos: 600, dur: 1000, done: true)), 0);
    });

    test('بداية قصيرة لا تُستأنف', () {
      expect(resumePositionSeconds(entry(pos: 5, dur: 1000)), 0);
    });

    test('قرب النهاية يبدأ من جديد', () {
      expect(resumePositionSeconds(entry(pos: 990, dur: 1000)), 0);
    });

    test('استئناف عادي', () {
      expect(resumePositionSeconds(entry(pos: 600, dur: 1000)), 600);
      // مدة غير معروفة: يستأنف من الموضع المحفوظ.
      expect(resumePositionSeconds(entry(pos: 120, dur: 0)), 120);
    });
  });

  group('introWindow', () {
    test('من الحلقة أولاً ثم العمل', () {
      final w = introWindow(series, ep('e1', 1, introStart: 5, introEnd: 60));
      expect(w, isNotNull);
      expect(w!.start, 5);
      expect(w.end, 60);
    });

    test('بدون قيم أو نطاق معكوس', () {
      expect(introWindow(movie, null), isNull);
      expect(introWindow(series, ep('e1', 1, introStart: 60, introEnd: 5)), isNull);
      expect(introWindow(series, ep('e1', 1, introStart: 10, introEnd: 10)), isNull);
    });
  });

  group('nextEpisodeOf', () {
    final list = [ep('a', 1), ep('b', 2), ep('c', 3)];

    test('التالية موجودة', () {
      expect(nextEpisodeOf(list, list[0])?.id, 'b');
      expect(nextEpisodeOf(list, list[1])?.id, 'c');
    });

    test('الأخيرة أو غير موجودة أو null', () {
      expect(nextEpisodeOf(list, list[2]), isNull);
      expect(nextEpisodeOf(list, ep('zzz', 9)), isNull);
      expect(nextEpisodeOf(list, null), isNull);
      expect(nextEpisodeOf(const [], list[0]), isNull);
    });
  });

  group('defaultSubtitleKey', () {
    const subs = [
      SubtitleItem(id: '1', language: 'en', url: 'u'),
      SubtitleItem(id: '2', language: 'AR', url: 'u'),
    ];

    test('يطابق اللغة دون حساسية لحالة الأحرف', () {
      expect(defaultSubtitleKey(subs, 'ar'), 'ext:2');
      expect(defaultSubtitleKey(subs, 'en'), 'ext:1');
    });

    test('off أو لغة غير متاحة', () {
      expect(defaultSubtitleKey(subs, 'off'), 'off');
      expect(defaultSubtitleKey(subs, 'fr'), 'off');
      expect(defaultSubtitleKey(const [], 'ar'), 'off');
    });
  });

  group('isGenuineEnd / episodeTag', () {
    test('النهاية الحقيقية مقابل الانقطاع المبكر', () {
      expect(isGenuineEnd(const Duration(minutes: 59, seconds: 55), const Duration(hours: 1)), isTrue);
      expect(isGenuineEnd(const Duration(minutes: 10), const Duration(hours: 1)), isFalse);
      expect(isGenuineEnd(const Duration(minutes: 10), Duration.zero), isFalse);
    });

    test('episodeTag', () {
      const e = Episode(id: 'x', seasonId: 's', seriesId: 'p', number: 3, seasonNumber: 2);
      expect(episodeTag(e), 'S2 · E3');
    });
  });

  // ------------------------------------------------------------------ المستودع التجريبي
  group('المستودع التجريبي', () {
    late DemoContentRepository content;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      content = DemoContentRepository();
    });

    test('يوجد محتوى وتصنيفات وصفوف رئيسية', () async {
      expect((await content.latest(limit: 50)), isNotEmpty);
      expect(await content.genres(), isNotEmpty);
      expect(await content.homeCategories(), isNotEmpty);
      expect(await content.featured(), isNotEmpty);
    });

    test('التصفية حسب النوع', () async {
      final movies = await content.browse(const CatalogQuery(kind: MediaKind.movie), offset: 0, limit: 100);
      expect(movies, isNotEmpty);
      expect(movies.every((i) => i.kind == MediaKind.movie), isTrue);
    });

    test('البحث بنص لا وجود له يعيد قائمة فارغة', () async {
      final r = await content.browse(const CatalogQuery(text: 'zzzz-no-such-title-qqq'), offset: 0, limit: 20);
      expect(r, isEmpty);
    });

    test('الترقيم: offset/limit', () async {
      final all = await content.browse(const CatalogQuery(), offset: 0, limit: 100);
      final page = await content.browse(const CatalogQuery(), offset: 1, limit: 2);
      expect(page.length, lessThanOrEqualTo(2));
      if (all.length > 1) expect(page.first.id, all[1].id);
    });

    test('تفاصيل عمل غير موجود تعيد err_not_found', () async {
      expect(
        () => content.details(MediaKind.movie, 'no-such-id'),
        throwsA(isA<AppException>().having((e) => e.key, 'key', 'err_not_found')),
      );
    });

    test('لكل فيلم مصدر تشغيل واحد على الأقل', () async {
      final movies = await content.browse(const CatalogQuery(kind: MediaKind.movie), offset: 0, limit: 100);
      for (final m in movies) {
        final src = await content.playbackSources(movieId: m.id);
        expect(src, isNotEmpty, reason: m.titleAr);
        expect(isValidHttpUrl(src.first.url), isTrue, reason: m.titleAr);
      }
    });

    test('لكل مسلسل حلقات ولكل حلقة مصدر تشغيل', () async {
      final shows = await content.browse(const CatalogQuery(kind: MediaKind.series), offset: 0, limit: 100);
      expect(shows, isNotEmpty);
      for (final s in shows) {
        final eps = await content.allEpisodes(s.id);
        expect(eps, isNotEmpty, reason: s.titleAr);
        final src = await content.playbackSources(episodeId: eps.first.id);
        expect(src, isNotEmpty, reason: s.titleAr);
      }
    });

    test('المفضلة وسجل المشاهدة محلياً', () async {
      final prefs = await SharedPreferences.getInstance();
      final user = LocalUserRepository(prefs, content);
      final movies = await content.browse(const CatalogQuery(kind: MediaKind.movie), offset: 0, limit: 5);
      final m = movies.first;

      expect(await user.favorites(), isEmpty);
      await user.setFavorite(m, true);
      expect((await user.favorites()).map((i) => i.id), [m.id]);
      await user.setFavorite(m, false);
      expect(await user.favorites(), isEmpty);

      // تقدّم متوسط: يظهر في "أكمل المشاهدة".
      await user.saveProgress(item: m, positionSeconds: 600, durationSeconds: 6000);
      expect((await user.continueWatching()).map((e) => e.item.id), [m.id]);
      expect((await user.movieProgress(m.id))?.positionSeconds, 600);

      // اقتراب من النهاية: يُعدّ مكتملاً ويختفي من "أكمل المشاهدة".
      await user.saveProgress(item: m, positionSeconds: 5990, durationSeconds: 6000);
      expect(await user.continueWatching(), isEmpty);
      expect((await user.history()).single.completed, isTrue);

      await user.clearHistory();
      expect(await user.history(), isEmpty);
    });
  });
}

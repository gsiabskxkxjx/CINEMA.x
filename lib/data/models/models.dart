import 'json_helpers.dart';

/// نوع العمل.
enum MediaKind {
  movie,
  series;

  static MediaKind parse(Object? v) =>
      v?.toString() == 'series' ? MediaKind.series : MediaKind.movie;
}

/// نوع فني (أكشن، رعب...).
class Genre {
  const Genre({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    this.sortOrder = 0,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final int sortOrder;

  factory Genre.fromJson(Map<String, dynamic> j) => Genre(
        id: j['id'].toString(),
        slug: jStr(j['slug']) ?? '',
        nameAr: jStr(j['name_ar']) ?? '',
        nameEn: jStr(j['name_en']) ?? '',
        sortOrder: jInt(j['sort_order']) ?? 0,
      );

  String name(bool ar) {
    if (ar) return nameAr.isNotEmpty ? nameAr : nameEn;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }
}

/// ممثل.
class Actor {
  const Actor({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.photoUrl,
    this.character,
  });

  final String id;
  final String nameAr;
  final String? nameEn;
  final String? photoUrl;
  final String? character;

  factory Actor.fromJson(Map<String, dynamic> j, {String? character}) => Actor(
        id: j['id'].toString(),
        nameAr: jStr(j['name_ar']) ?? '',
        nameEn: jStr(j['name_en']),
        photoUrl: jStr(j['photo_url']),
        character: character,
      );

  String name(bool ar) {
    final en = nameEn ?? '';
    if (ar) return nameAr.isNotEmpty ? nameAr : en;
    return en.isNotEmpty ? en : nameAr;
  }
}

/// فيلم أو مسلسل (نموذج موحّد للقوائم والتفاصيل).
class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.titleAr,
    this.titleEn,
    this.overviewAr,
    this.overviewEn,
    this.posterUrl,
    this.backdropUrl,
    this.trailerUrl,
    this.year,
    this.ageRating,
    this.country,
    this.language,
    this.origin = 'foreign',
    this.quality,
    this.rating,
    this.runtimeMinutes,
    this.director,
    this.subtitleLanguages = const [],
    this.introStart,
    this.introEnd,
    this.isFeatured = false,
    this.featuredOrder = 0,
    this.isPremium = false,
    this.viewCount = 0,
    this.createdAt,
    this.genres = const [],
    this.cast = const [],
  });

  final String id;
  final MediaKind kind;
  final String titleAr;
  final String? titleEn;
  final String? overviewAr;
  final String? overviewEn;
  final String? posterUrl;
  final String? backdropUrl;
  final String? trailerUrl;
  final int? year;
  final String? ageRating;
  final String? country;
  final String? language;
  final String origin;
  final String? quality;
  final double? rating;
  final int? runtimeMinutes;
  final String? director;
  final List<String> subtitleLanguages;
  final int? introStart;
  final int? introEnd;
  final bool isFeatured;
  final int featuredOrder;
  final bool isPremium;
  final int viewCount;
  final DateTime? createdAt;
  final List<Genre> genres;
  final List<Actor> cast;

  bool get isSeries => kind == MediaKind.series;

  /// يقبل صفاً من view الـ catalog (يحتوي kind) أو من جدول movies/series (مرّر kind).
  factory MediaItem.fromJson(Map<String, dynamic> j, {MediaKind? kind}) {
    final k = kind ?? MediaKind.parse(j['kind']);
    final isMovie = k == MediaKind.movie;

    final genreRows = jMapList(j[isMovie ? 'movie_genres' : 'series_genres']);
    final genres = <Genre>[];
    for (final r in genreRows) {
      final g = jMap(r['genres']);
      if (g != null) genres.add(Genre.fromJson(g));
    }

    final actorRows = jMapList(j[isMovie ? 'movie_actors' : 'series_actors']);
    actorRows.sort((a, b) =>
        (jInt(a['sort_order']) ?? 0).compareTo(jInt(b['sort_order']) ?? 0));
    final cast = <Actor>[];
    for (final r in actorRows) {
      final a = jMap(r['actors']);
      if (a != null) {
        cast.add(Actor.fromJson(a, character: jStr(r['character_name'])));
      }
    }

    return MediaItem(
      id: j['id'].toString(),
      kind: k,
      titleAr: jStr(j['title_ar']) ?? '',
      titleEn: jStr(j['title_en']),
      overviewAr: jStr(j['overview_ar']),
      overviewEn: jStr(j['overview_en']),
      posterUrl: jStr(j['poster_url']),
      backdropUrl: jStr(j['backdrop_url']),
      trailerUrl: jStr(j['trailer_url']),
      year: jInt(j['release_year']),
      ageRating: jStr(j['age_rating']),
      country: jStr(j['country']),
      language: jStr(j['language']),
      origin: jStr(j['origin']) ?? 'foreign',
      quality: jStr(j['quality']),
      rating: jDouble(j['rating']),
      runtimeMinutes: jInt(j['runtime_minutes']),
      director: jStr(j['director']),
      subtitleLanguages: jStrList(j['subtitle_languages']),
      introStart: jInt(j['intro_start_seconds']),
      introEnd: jInt(j['intro_end_seconds']),
      isFeatured: jBool(j['is_featured']),
      featuredOrder: jInt(j['featured_order']) ?? 0,
      isPremium: jBool(j['is_premium']),
      viewCount: jInt(j['view_count']) ?? 0,
      createdAt: jDate(j['created_at']),
      genres: genres,
      cast: cast,
    );
  }

  String title(bool ar) {
    final en = (titleEn ?? '').trim();
    if (ar) return titleAr.isNotEmpty ? titleAr : en;
    return en.isNotEmpty ? en : titleAr;
  }

  String? overview(bool ar) => ar ? (overviewAr ?? overviewEn) : (overviewEn ?? overviewAr);
}

class Season {
  const Season({
    required this.id,
    required this.seriesId,
    required this.number,
    this.titleAr,
    this.titleEn,
  });

  final String id;
  final String seriesId;
  final int number;
  final String? titleAr;
  final String? titleEn;

  factory Season.fromJson(Map<String, dynamic> j) => Season(
        id: j['id'].toString(),
        seriesId: j['series_id'].toString(),
        number: jInt(j['season_number']) ?? 1,
        titleAr: jStr(j['title_ar']),
        titleEn: jStr(j['title_en']),
      );

  String displayTitle(bool ar) {
    final t = ar ? (titleAr ?? titleEn) : (titleEn ?? titleAr);
    return t ?? (ar ? 'الموسم $number' : 'Season $number');
  }
}

class Episode {
  const Episode({
    required this.id,
    required this.seasonId,
    required this.seriesId,
    required this.number,
    this.seasonNumber = 1,
    this.titleAr,
    this.titleEn,
    this.overviewAr,
    this.overviewEn,
    this.stillUrl,
    this.runtimeMinutes,
    this.introStart,
    this.introEnd,
  });

  final String id;
  final String seasonId;
  final String seriesId;
  final int number;
  final int seasonNumber;
  final String? titleAr;
  final String? titleEn;
  final String? overviewAr;
  final String? overviewEn;
  final String? stillUrl;
  final int? runtimeMinutes;
  final int? introStart;
  final int? introEnd;

  factory Episode.fromJson(Map<String, dynamic> j) {
    final season = jMap(j['seasons']);
    return Episode(
      id: j['id'].toString(),
      seasonId: j['season_id'].toString(),
      seriesId: j['series_id'].toString(),
      number: jInt(j['episode_number']) ?? 1,
      seasonNumber: jInt(season?['season_number']) ?? jInt(j['season_number']) ?? 1,
      titleAr: jStr(j['title_ar']),
      titleEn: jStr(j['title_en']),
      overviewAr: jStr(j['overview_ar']),
      overviewEn: jStr(j['overview_en']),
      stillUrl: jStr(j['still_url']),
      runtimeMinutes: jInt(j['runtime_minutes']),
      introStart: jInt(j['intro_start_seconds']),
      introEnd: jInt(j['intro_end_seconds']),
    );
  }

  String displayTitle(bool ar) {
    final t = ar ? (titleAr ?? titleEn) : (titleEn ?? titleAr);
    return t ?? (ar ? 'الحلقة $number' : 'Episode $number');
  }

  String? overview(bool ar) => ar ? (overviewAr ?? overviewEn) : (overviewEn ?? overviewAr);
}

/// مصدر تشغيل (رابط فيديو) - لا يصل للمستخدم إلا عبر get_playback_sources.
class VideoSource {
  const VideoSource({
    required this.id,
    required this.label,
    required this.url,
    this.qualityHeight,
    this.type = 'mp4',
  });

  final String id;
  final String label;
  final String url;
  final int? qualityHeight;
  final String type;

  factory VideoSource.fromJson(Map<String, dynamic> j) => VideoSource(
        id: j['id'].toString(),
        label: jStr(j['label']) ?? 'Auto',
        url: jStr(j['url']) ?? '',
        qualityHeight: jInt(j['quality_height']),
        type: jStr(j['type']) ?? 'mp4',
      );
}

/// ملف ترجمة خارجي (SRT/VTT).
class SubtitleItem {
  const SubtitleItem({
    required this.id,
    required this.language,
    required this.url,
    this.label,
    this.format = 'srt',
    this.isDefault = false,
  });

  final String id;
  final String language;
  final String url;
  final String? label;
  final String format;
  final bool isDefault;

  factory SubtitleItem.fromJson(Map<String, dynamic> j) => SubtitleItem(
        id: j['id'].toString(),
        language: jStr(j['language']) ?? '',
        url: jStr(j['url']) ?? '',
        label: jStr(j['label']),
        format: jStr(j['format']) ?? 'srt',
        isDefault: jBool(j['is_default']),
      );

  String displayLabel() => label ?? language.toUpperCase();
}

/// صف في سجل المشاهدة / أكمل المشاهدة.
class WatchEntry {
  const WatchEntry({
    required this.item,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.completed,
    required this.updatedAt,
    this.episode,
  });

  final MediaItem item;
  final Episode? episode;
  final int positionSeconds;
  final int durationSeconds;
  final bool completed;
  final DateTime updatedAt;

  String get key => episode?.id ?? item.id;

  double get progress {
    if (durationSeconds <= 0) return 0;
    final p = positionSeconds / durationSeconds;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  static WatchEntry? tryParse(Map<String, dynamic> row) {
    final isEpisode = row['kind'] == 'episode';
    final itemMap = jMap(isEpisode ? row['series'] : row['movies']);
    if (itemMap == null) return null;
    Episode? episode;
    if (isEpisode) {
      final ep = jMap(row['episodes']);
      if (ep == null) return null;
      episode = Episode.fromJson(ep);
    }
    return WatchEntry(
      item: MediaItem.fromJson(itemMap,
          kind: isEpisode ? MediaKind.series : MediaKind.movie),
      episode: episode,
      positionSeconds: jInt(row['position_seconds']) ?? 0,
      durationSeconds: jInt(row['duration_seconds']) ?? 0,
      completed: jBool(row['completed']),
      updatedAt: jDate(row['updated_at']) ?? DateTime.now(),
    );
  }
}

/// ملف المستخدم.
class AppProfile {
  const AppProfile({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.role = 'user',
    this.isBlocked = false,
    this.language = 'ar',
    this.preferredQuality = 'auto',
    this.subtitleLanguage = 'off',
    this.autoplayNext = true,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final bool isBlocked;
  final String language;
  final String preferredQuality;
  final String subtitleLanguage;
  final bool autoplayNext;

  bool get isAdmin => role == 'admin';

  factory AppProfile.fromJson(Map<String, dynamic> j) => AppProfile(
        id: j['id'].toString(),
        email: jStr(j['email']),
        displayName: jStr(j['display_name']),
        avatarUrl: jStr(j['avatar_url']),
        role: jStr(j['role']) ?? 'user',
        isBlocked: jBool(j['is_blocked']),
        language: jStr(j['language']) ?? 'ar',
        preferredQuality: jStr(j['preferred_quality']) ?? 'auto',
        subtitleLanguage: jStr(j['subtitle_language']) ?? 'off',
        autoplayNext: jBool(j['autoplay_next'], true),
      );

  factory AppProfile.demo() => const AppProfile(id: 'demo', displayName: 'Demo');

  AppProfile copyWith({String? displayName, String? avatarUrl}) => AppProfile(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role,
        isBlocked: isBlocked,
        language: language,
        preferredQuality: preferredQuality,
        subtitleLanguage: subtitleLanguage,
        autoplayNext: autoplayNext,
      );
}

/// فئة = قاعدة صف في الرئيسية.
class CategoryRow {
  const CategoryRow({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    this.kind,
    this.origin,
    this.genreId,
    this.layout = 'poster',
    this.sortOrder = 0,
    this.showOnHome = true,
    this.isActive = true,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final MediaKind? kind;
  final String? origin;
  final String? genreId;
  final String layout;
  final int sortOrder;
  final bool showOnHome;
  final bool isActive;

  bool get isLandscape => layout == 'landscape';

  factory CategoryRow.fromJson(Map<String, dynamic> j) => CategoryRow(
        id: j['id'].toString(),
        slug: jStr(j['slug']) ?? '',
        nameAr: jStr(j['name_ar']) ?? '',
        nameEn: jStr(j['name_en']) ?? '',
        kind: jStr(j['kind']) == null ? null : MediaKind.parse(j['kind']),
        origin: jStr(j['origin']),
        genreId: jStr(j['genre_id']),
        layout: jStr(j['layout']) ?? 'poster',
        sortOrder: jInt(j['sort_order']) ?? 0,
        showOnHome: jBool(j['show_on_home'], true),
        isActive: jBool(j['is_active'], true),
      );

  String name(bool ar) {
    if (ar) return nameAr.isNotEmpty ? nameAr : nameEn;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.billingPeriod,
    required this.price,
    required this.currency,
    required this.maxDevices,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final String billingPeriod;
  final double price;
  final String currency;
  final int maxDevices;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        id: j['id'].toString(),
        code: jStr(j['code']) ?? '',
        nameAr: jStr(j['name_ar']) ?? '',
        nameEn: jStr(j['name_en']) ?? '',
        billingPeriod: jStr(j['billing_period']) ?? 'none',
        price: jDouble(j['price']) ?? 0,
        currency: jStr(j['currency']) ?? 'USD',
        maxDevices: jInt(j['max_devices']) ?? 1,
      );

  String name(bool ar) => ar ? nameAr : nameEn;
}

/// مرجع لعمل (نوع + معرّف) - يصلح مفتاحاً لـ family providers.
class MediaRef {
  const MediaRef(this.kind, this.id);
  final MediaKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is MediaRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// استعلام كتالوج (بحث/تصفح) - قيمة غير قابلة للتغيير مع مساواة بالقيمة.
class CatalogQuery {
  const CatalogQuery({
    this.text,
    this.kind,
    this.origin,
    this.genreId,
    this.year,
    this.country,
    this.sort = 'latest',
  });

  final String? text;
  final MediaKind? kind;
  final String? origin;
  final String? genreId;
  final int? year;
  final String? country;
  final String sort; // latest | popular | rating | year

  static const Object _unset = Object();

  CatalogQuery copyWith({
    Object? text = _unset,
    Object? kind = _unset,
    Object? origin = _unset,
    Object? genreId = _unset,
    Object? year = _unset,
    Object? country = _unset,
    String? sort,
  }) {
    return CatalogQuery(
      text: identical(text, _unset) ? this.text : text as String?,
      kind: identical(kind, _unset) ? this.kind : kind as MediaKind?,
      origin: identical(origin, _unset) ? this.origin : origin as String?,
      genreId: identical(genreId, _unset) ? this.genreId : genreId as String?,
      year: identical(year, _unset) ? this.year : year as int?,
      country: identical(country, _unset) ? this.country : country as String?,
      sort: sort ?? this.sort,
    );
  }

  bool get hasFilters =>
      kind != null || origin != null || genreId != null || year != null || country != null;

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery &&
      other.text == text &&
      other.kind == kind &&
      other.origin == origin &&
      other.genreId == genreId &&
      other.year == year &&
      other.country == country &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(text, kind, origin, genreId, year, country, sort);
}

class HomeRow {
  const HomeRow(this.category, this.items);
  final CategoryRow category;
  final List<MediaItem> items;
}

class HomeData {
  const HomeData({
    required this.featured,
    required this.mostWatched,
    required this.latest,
    required this.rows,
  });

  final List<MediaItem> featured;
  final List<MediaItem> mostWatched;
  final List<MediaItem> latest;
  final List<HomeRow> rows;
}

/// مواسم وحلقات مسلسل.
class SeriesContent {
  const SeriesContent({required this.seasons, required this.episodes});
  final List<Season> seasons;
  final List<Episode> episodes; // مرتبة: الموسم ثم رقم الحلقة

  List<Episode> episodesOf(String seasonId) =>
      episodes.where((e) => e.seasonId == seasonId).toList();
}

/// وسائط صفحة المشغّل.
class PlayerArgs {
  const PlayerArgs({
    required this.item,
    this.episode,
    this.episodes = const [],
  });

  final MediaItem item;
  final Episode? episode; // null للأفلام
  final List<Episode> episodes; // كل حلقات المسلسل مرتبة (للحلقة التالية)
}

class SessionUser {
  const SessionUser({required this.id, this.email});
  final String id;
  final String? email;

  @override
  bool operator ==(Object other) => other is SessionUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

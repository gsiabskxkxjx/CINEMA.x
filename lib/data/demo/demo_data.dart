import '../models/models.dart';

/// بيانات تجريبية للوضع التجريبي (عند عدم ضبط Supabase).
///
/// - العناوين والممثلون والمخرجون في الأعمال التجريبية خيالية بالكامل.
/// - الفيديو من أفلام Blender القصيرة المفتوحة (Creative Commons Attribution).
/// - الروابط تابعة لجهات خارجية وقد لا تعمل دائماً؛ استبدلها من لوحة الإدارة.
class DemoData {
  DemoData._() {
    _build();
  }

  static final DemoData instance = DemoData._();

  static const String _mp4 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/';
  static const String _hls = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  static const String _sintelSubs = 'https://durian.blender.org/wp-content/content/subtitles/sintel_en.srt';
  static const List<String> _clips = [
    'BigBuckBunny.mp4',
    'ElephantsDream.mp4',
    'Sintel.mp4',
    'TearsOfSteel.mp4',
  ];

  final List<Genre> genres = [];
  final List<CategoryRow> categories = [];
  final List<MediaItem> items = [];
  final Map<String, List<Season>> seasonsBySeries = {};
  final Map<String, List<Episode>> episodesBySeries = {};
  final Map<String, List<VideoSource>> sourcesByContent = {};
  final Map<String, List<SubtitleItem>> subtitlesByContent = {};
  final List<SubscriptionPlan> plans = const [
    SubscriptionPlan(
      id: 'plan-free',
      code: 'free',
      nameAr: 'مجاني',
      nameEn: 'Free',
      billingPeriod: 'none',
      price: 0,
      currency: 'USD',
      maxDevices: 1,
    ),
    SubscriptionPlan(
      id: 'plan-monthly',
      code: 'premium_monthly',
      nameAr: 'بريميوم شهري',
      nameEn: 'Premium Monthly',
      billingPeriod: 'monthly',
      price: 4.99,
      currency: 'USD',
      maxDevices: 4,
    ),
    SubscriptionPlan(
      id: 'plan-yearly',
      code: 'premium_yearly',
      nameAr: 'بريميوم سنوي',
      nameEn: 'Premium Yearly',
      billingPeriod: 'yearly',
      price: 49.99,
      currency: 'USD',
      maxDevices: 4,
    ),
  ];

  MediaItem? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Genre _g(String slug) => genres.firstWhere((g) => g.slug == slug);

  static const List<Actor> _actors = [
    Actor(id: 'a1', nameAr: 'سامي العلي', nameEn: 'Sami Al-Ali'),
    Actor(id: 'a2', nameAr: 'ليلى حداد', nameEn: 'Layla Haddad'),
    Actor(id: 'a3', nameAr: 'عمر ناصر', nameEn: 'Omar Nasser'),
    Actor(id: 'a4', nameAr: 'نور خليل', nameEn: 'Nour Khalil'),
    Actor(id: 'a5', nameAr: 'رامي صالح', nameEn: 'Rami Saleh'),
    Actor(id: 'a6', nameAr: 'هالة منصور', nameEn: 'Hala Mansour'),
  ];

  void _build() {
    const genreSeeds = [
      ['action', 'أكشن', 'Action'],
      ['horror', 'رعب', 'Horror'],
      ['sci-fi', 'خيال علمي', 'Sci-Fi'],
      ['comedy', 'كوميديا', 'Comedy'],
      ['drama', 'دراما', 'Drama'],
      ['romance', 'رومانسي', 'Romance'],
      ['thriller', 'إثارة', 'Thriller'],
      ['animation', 'رسوم متحركة', 'Animation'],
      ['anime', 'أنمي', 'Anime'],
      ['family', 'عائلي', 'Family'],
    ];
    for (var i = 0; i < genreSeeds.length; i++) {
      final s = genreSeeds[i];
      genres.add(Genre(id: 'g-${s[0]}', slug: s[0], nameAr: s[1], nameEn: s[2], sortOrder: i));
    }

    categories.addAll([
      _cat('action-movies', 'أفلام الأكشن', 'Action Movies', MediaKind.movie, null, 'action', 10),
      _cat('horror-movies', 'أفلام الرعب', 'Horror Movies', MediaKind.movie, null, 'horror', 20),
      _cat('scifi-movies', 'أفلام الخيال العلمي', 'Sci-Fi Movies', MediaKind.movie, null, 'sci-fi', 30),
      _cat('comedy-movies', 'أفلام الكوميديا', 'Comedy Movies', MediaKind.movie, null, 'comedy', 40),
      _cat('arabic-movies', 'الأفلام العربية', 'Arabic Movies', MediaKind.movie, 'arab', null, 50),
      _cat('foreign-movies', 'الأفلام الأجنبية', 'Foreign Movies', MediaKind.movie, 'foreign', null, 60),
      _cat('arabic-series', 'المسلسلات العربية', 'Arabic Series', MediaKind.series, 'arab', null, 70),
      _cat('foreign-series', 'المسلسلات الأجنبية', 'Foreign Series', MediaKind.series, 'foreign', null, 80),
      _cat('anime', 'الأنمي', 'Anime', null, null, 'anime', 90),
    ]);

    // ------------------------------------------------------------ أفلام Blender الحقيقية
    _movie(0, 'بيغ باك باني', 'Big Buck Bunny', ['animation', 'comedy', 'family'], 'foreign', 2008, 'Netherlands',
        'en', 'Sacha Goedegebure', 10, 'G', 'HD', null,
        'فيلم رسوم متحركة قصير من إنتاج مؤسسة Blender عن أرنب ضخم طيّب القلب يواجه ثلاثة قوارض مشاكسة.',
        'A short open-source animated film by the Blender Foundation about a giant, kind-hearted rabbit and three mischievous rodents.',
        featured: true, clip: 0, real: true);
    _movie(1, 'حلم الفيلة', 'Elephants Dream', ['animation', 'sci-fi'], 'foreign', 2006, 'Netherlands', 'en',
        'Bassam Kurdali', 11, 'PG', 'HD', null,
        'أول فيلم قصير مفتوح المصدر من Blender، يتابع شخصيتين داخل آلة سريالية غريبة.',
        'The first open-source short film from Blender, following two characters inside a strange, surreal machine.',
        featured: true, clip: 1, real: true);
    _movie(2, 'سينتل', 'Sintel', ['animation', 'action'], 'foreign', 2010, 'Netherlands', 'en', 'Colin Levy', 15,
        'PG-13', 'HD', null,
        'فيلم فانتازيا قصير عن فتاة تدعى سينتل تبحث عن تنين صغير صادقته.',
        'A short fantasy film about a girl named Sintel who searches for a baby dragon she befriended.',
        featured: true, clip: 2, real: true, subs: true);
    _movie(3, 'دموع الفولاذ', 'Tears of Steel', ['sci-fi', 'action'], 'foreign', 2012, 'Netherlands', 'en',
        'Ian Hubert', 12, 'PG-13', 'HD', null,
        'فيلم خيال علمي قصير تدور أحداثه في أمستردام مستقبلية، يجمع بين التصوير الحي والمؤثرات البصرية.',
        'A short sci-fi film set in a future Amsterdam, combining live-action footage and visual effects.',
        featured: true, clip: 3, real: true);

    // ------------------------------------------------------------ أفلام تجريبية خيالية
    const demoOverviewAr = 'عمل تجريبي خيالي يُستخدم لعرض شكل التطبيق فقط. استبدله بمحتوى تملك حق عرضه من لوحة الإدارة.';
    const demoOverviewEn = 'A fictional demo title used only to show the app layout. Replace it with content you are licensed to show.';
    final fake = <List<Object>>[
      // ar, en, genres, origin, year, rating, country, lang, director, runtime, age, quality
      ['عملية الفجر', 'Operation Dawn', ['action', 'thriller'], 'foreign', 2023, 7.4, 'USA', 'en', 'D. Marlowe', 118, 'PG-13', '4K'],
      ['سباق الموت', 'Death Race Zero', ['action'], 'foreign', 2022, 6.8, 'UK', 'en', 'K. Brandt', 105, 'R', 'FHD'],
      ['الحارس الأخير', 'The Last Guard', ['action', 'drama'], 'foreign', 2021, 7.1, 'USA', 'en', 'S. Ortega', 124, 'PG-13', 'FHD'],
      ['ثأر الصحراء', 'Desert Vengeance', ['action', 'drama'], 'arab', 2023, 7.9, 'Egypt', 'ar', 'م. فهمي', 109, '+15', 'FHD'],
      ['مطاردة القاهرة', 'Cairo Chase', ['action', 'thriller'], 'arab', 2022, 7.2, 'Egypt', 'ar', 'ه. السيد', 101, '+13', 'HD'],
      ['بيت الظلال', 'House of Shadows', ['horror', 'thriller'], 'foreign', 2023, 6.5, 'USA', 'en', 'L. Chen', 96, 'R', 'FHD'],
      ['الليلة الأخيرة', 'The Final Night', ['horror'], 'foreign', 2020, 6.1, 'Canada', 'en', 'P. Vance', 92, 'R', 'HD'],
      ['همس الجدران', 'Whispers in the Walls', ['horror', 'drama'], 'foreign', 2024, 6.9, 'Spain', 'es', 'I. Duarte', 99, 'R', 'FHD'],
      ['ما بعد الغيوم', 'Beyond the Clouds', ['sci-fi', 'drama'], 'foreign', 2024, 8.1, 'USA', 'en', 'A. Reyes', 132, 'PG-13', '4K'],
      ['مدار الصفر', 'Zero Orbit', ['sci-fi', 'thriller'], 'foreign', 2022, 7.3, 'Germany', 'de', 'T. Weiss', 114, 'PG-13', 'FHD'],
      ['ذاكرة آلية', 'Machine Memory', ['sci-fi'], 'foreign', 2021, 6.7, 'Japan', 'ja', 'H. Sato', 108, 'PG', 'HD'],
      ['أسبوع المصائب', 'Week of Chaos', ['comedy', 'family'], 'foreign', 2023, 6.4, 'USA', 'en', 'R. Gold', 94, 'PG', 'FHD'],
      ['العريس الغلطان', 'The Wrong Groom', ['comedy', 'romance'], 'arab', 2023, 7.0, 'Egypt', 'ar', 'ن. رشدي', 102, '+13', 'FHD'],
      ['جيران بالغلط', 'Accidental Neighbors', ['comedy'], 'arab', 2021, 6.6, 'Lebanon', 'ar', 'ج. كرم', 97, '+13', 'HD'],
      ['زقاق الياسمين', 'Jasmine Alley', ['drama', 'romance'], 'arab', 2022, 8.0, 'Syria', 'ar', 'ر. العلي', 121, '+15', 'FHD'],
      ['رسائل من بغداد', 'Letters from Baghdad', ['drama'], 'arab', 2024, 8.3, 'Iraq', 'ar', 'ع. الجبوري', 128, '+15', '4K'],
      ['ليالي دمشق', 'Damascus Nights', ['romance', 'drama'], 'arab', 2020, 7.5, 'Syria', 'ar', 'س. حداد', 110, '+13', 'HD'],
      ['نهر الصمت', 'River of Silence', ['drama'], 'foreign', 2022, 7.7, 'France', 'fr', 'C. Lambert', 116, 'PG-13', 'FHD'],
      ['الطريق إلى الشمال', 'Road to the North', ['drama', 'thriller'], 'foreign', 2023, 7.0, 'Norway', 'no', 'E. Berg', 120, 'PG-13', 'FHD'],
      ['حديقة الأحلام', 'Dream Garden', ['family', 'animation'], 'foreign', 2024, 7.6, 'Korea', 'ko', 'J. Park', 90, 'G', '4K'],
    ];
    for (var i = 0; i < fake.length; i++) {
      final f = fake[i];
      _movie(
        4 + i,
        f[0] as String,
        f[1] as String,
        (f[2] as List).cast<String>(),
        f[3] as String,
        f[4] as int,
        f[6] as String,
        f[7] as String,
        f[8] as String,
        f[9] as int,
        f[10] as String,
        f[11] as String,
        f[5] as double,
        demoOverviewAr,
        demoOverviewEn,
        featured: i == 8 || i == 15,
        clip: i % _clips.length,
      );
    }

    // ------------------------------------------------------------ مسلسلات تجريبية
    final seriesSeeds = <List<Object>>[
      ['حارة الأمل', 'Hope Alley', ['drama'], 'arab', 2023, 8.2, 'Egypt', 'ar', '+13', 'FHD'],
      ['ليل المدينة', 'City Night', ['thriller', 'drama'], 'arab', 2024, 7.8, 'Syria', 'ar', '+15', 'FHD'],
      ['آخر الناجين', 'Last Survivors', ['sci-fi', 'thriller'], 'foreign', 2023, 8.4, 'USA', 'en', 'PG-13', '4K'],
      ['الأكاديمية', 'The Academy', ['drama', 'comedy'], 'foreign', 2022, 7.1, 'UK', 'en', 'PG', 'FHD'],
      ['محارب النجوم', 'Star Warrior', ['anime', 'action', 'sci-fi'], 'foreign', 2023, 8.6, 'Japan', 'ja', 'PG-13', 'FHD'],
      ['سيف الغيم', 'Cloud Sword', ['anime', 'action'], 'foreign', 2021, 8.0, 'Japan', 'ja', 'PG-13', 'HD'],
      ['مدرسة السحر', 'Magic School', ['anime', 'family'], 'foreign', 2024, 7.7, 'Japan', 'ja', 'PG', 'FHD'],
    ];
    for (var i = 0; i < seriesSeeds.length; i++) {
      final s = seriesSeeds[i];
      _series(
        i,
        s[0] as String,
        s[1] as String,
        (s[2] as List).cast<String>(),
        s[3] as String,
        s[4] as int,
        s[5] as double,
        s[6] as String,
        s[7] as String,
        s[8] as String,
        s[9] as String,
        demoOverviewAr,
        demoOverviewEn,
        featured: i == 2,
      );
    }
  }

  CategoryRow _cat(String slug, String ar, String en, MediaKind? kind, String? origin, String? genreSlug, int order) {
    return CategoryRow(
      id: 'cat-$slug',
      slug: slug,
      nameAr: ar,
      nameEn: en,
      kind: kind,
      origin: origin,
      genreId: genreSlug == null ? null : 'g-$genreSlug',
      sortOrder: order,
    );
  }

  List<Actor> _castFor(int seed) => [
        for (var k = 0; k < 4; k++)
          Actor(
            id: _actors[(seed + k) % _actors.length].id,
            nameAr: _actors[(seed + k) % _actors.length].nameAr,
            nameEn: _actors[(seed + k) % _actors.length].nameEn,
            character: null,
          ),
      ];

  void _movie(
    int index,
    String ar,
    String en,
    List<String> genreSlugs,
    String origin,
    int year,
    String country,
    String lang,
    String director,
    int runtime,
    String age,
    String quality,
    double? rating,
    String overviewAr,
    String overviewEn, {
    bool featured = false,
    int clip = 0,
    bool real = false,
    bool subs = false,
  }) {
    final id = 'm-$index';
    items.add(MediaItem(
      id: id,
      kind: MediaKind.movie,
      titleAr: ar,
      titleEn: en,
      overviewAr: overviewAr,
      overviewEn: overviewEn,
      year: year,
      ageRating: age,
      country: country,
      language: lang,
      origin: origin,
      quality: quality,
      rating: rating,
      runtimeMinutes: runtime,
      director: director,
      subtitleLanguages: subs ? const ['en'] : const [],
      isFeatured: featured,
      featuredOrder: index,
      viewCount: 1000 - index * 17 + (index * 31) % 97,
      createdAt: DateTime(2025, 1, 1).add(Duration(days: 40 - index)),
      genres: genreSlugs.map(_g).toList(),
      cast: real ? const [] : _castFor(index),
    ));
    sourcesByContent[id] = [
      VideoSource(id: '$id-mp4', label: '720p', url: '$_mp4${_clips[clip]}', qualityHeight: 720, type: 'mp4'),
      const VideoSource(id: 'demo-hls', label: 'Auto (HLS)', url: _hls, type: 'hls'),
    ];
    if (subs) {
      subtitlesByContent[id] = const [
        SubtitleItem(id: 'sub-sintel-en', language: 'en', url: _sintelSubs, label: 'English', format: 'srt'),
      ];
    }
  }

  void _series(
    int index,
    String ar,
    String en,
    List<String> genreSlugs,
    String origin,
    int year,
    double rating,
    String country,
    String lang,
    String age,
    String quality,
    String overviewAr,
    String overviewEn, {
    bool featured = false,
  }) {
    final id = 's-$index';
    items.add(MediaItem(
      id: id,
      kind: MediaKind.series,
      titleAr: ar,
      titleEn: en,
      overviewAr: overviewAr,
      overviewEn: overviewEn,
      year: year,
      ageRating: age,
      country: country,
      language: lang,
      origin: origin,
      quality: quality,
      rating: rating,
      runtimeMinutes: 45,
      director: null,
      isFeatured: featured,
      featuredOrder: 10 + index,
      viewCount: 900 - index * 23 + (index * 17) % 61,
      createdAt: DateTime(2025, 1, 1).add(Duration(days: 30 - index)),
      genres: genreSlugs.map(_g).toList(),
      cast: _castFor(index + 2),
    ));

    final seasons = <Season>[];
    final episodes = <Episode>[];
    for (var s = 1; s <= 2; s++) {
      final seasonId = '$id-s$s';
      seasons.add(Season(id: seasonId, seriesId: id, number: s));
      for (var e = 1; e <= 4; e++) {
        final epId = '$id-s$s-e$e';
        episodes.add(Episode(
          id: epId,
          seasonId: seasonId,
          seriesId: id,
          seasonNumber: s,
          number: e,
          overviewAr: 'حلقة تجريبية تستخدم مقطع فيديو مفتوحاً للاختبار.',
          overviewEn: 'A demo episode that reuses an open-licensed video clip for testing.',
          runtimeMinutes: 10 + e,
          introStart: 3,
          introEnd: 20,
        ));
        sourcesByContent[epId] = [
          VideoSource(
            id: '$epId-mp4',
            label: '720p',
            url: '$_mp4${_clips[(index + s + e) % _clips.length]}',
            qualityHeight: 720,
            type: 'mp4',
          ),
        ];
      }
    }
    seasonsBySeries[id] = seasons;
    episodesBySeries[id] = episodes;
  }
}

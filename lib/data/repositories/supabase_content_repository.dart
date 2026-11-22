import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json_helpers.dart';
import '../models/models.dart';
import 'repositories.dart';

class SupabaseContentRepository implements ContentRepository {
  SupabaseContentRepository(this._db);

  final SupabaseClient _db;

  List<MediaItem> _items(Object? data) => jMapList(data).map((e) => MediaItem.fromJson(e)).toList();

  @override
  Future<List<MediaItem>> featured() async {
    final data = await _db
        .from('catalog')
        .select()
        .eq('is_featured', true)
        .order('featured_order')
        .order('created_at', ascending: false)
        .limit(8);
    return _items(data);
  }

  @override
  Future<List<MediaItem>> mostWatched({int limit = 15}) async {
    final data = await _db
        .from('catalog')
        .select()
        .order('view_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return _items(data);
  }

  @override
  Future<List<MediaItem>> latest({int limit = 15}) async {
    final data = await _db.from('catalog').select().order('created_at', ascending: false).limit(limit);
    return _items(data);
  }

  @override
  Future<List<CategoryRow>> homeCategories() async {
    final data = await _db
        .from('categories')
        .select()
        .eq('is_active', true)
        .eq('show_on_home', true)
        .order('sort_order');
    return jMapList(data).map(CategoryRow.fromJson).toList();
  }

  @override
  Future<List<MediaItem>> browse(CatalogQuery query,
      {required int offset, required int limit}) async {
    final text = query.text?.trim();
    final data = await _db.rpc('browse_catalog', params: {
      'p_query': (text == null || text.isEmpty) ? null : text,
      'p_kind': query.kind?.name,
      'p_origin': query.origin,
      'p_genre_id': query.genreId,
      'p_year': query.year,
      'p_country': query.country,
      'p_sort': query.sort,
      'p_limit': limit,
      'p_offset': offset,
    });
    return _items(data);
  }

  @override
  Future<List<String>> suggestions(String text) async {
    final t = text.trim();
    if (t.isEmpty) return const [];
    final data = await _db.rpc('search_suggestions', params: {'p_query': t});
    final seen = <String>{};
    final out = <String>[];
    for (final row in jMapList(data)) {
      final s = jStr(row['suggestion']);
      if (s != null && seen.add(s)) out.add(s);
    }
    return out;
  }

  @override
  Future<List<Genre>> genres() async {
    final data = await _db.from('genres').select().order('sort_order');
    return jMapList(data).map(Genre.fromJson).toList();
  }

  @override
  Future<List<String>> countries() async {
    final data = await _db.rpc('catalog_countries');
    return jMapList(data).map((r) => jStr(r['country'])).whereType<String>().toList();
  }

  @override
  Future<MediaItem> details(MediaKind kind, String id) async {
    final isMovie = kind == MediaKind.movie;
    final select = isMovie
        ? '*, movie_genres(genres(*)), movie_actors(character_name, sort_order, actors(*))'
        : '*, series_genres(genres(*)), series_actors(character_name, sort_order, actors(*))';
    final row = await _db.from(isMovie ? 'movies' : 'series').select(select).eq('id', id).single();
    return MediaItem.fromJson(row, kind: kind);
  }

  @override
  Future<List<MediaItem>> similar(MediaItem item) async {
    final query = CatalogQuery(
      kind: item.kind,
      genreId: item.genres.isNotEmpty ? item.genres.first.id : null,
      origin: item.genres.isEmpty ? item.origin : null,
      sort: 'popular',
    );
    final list = await browse(query, offset: 0, limit: 14);
    return list.where((e) => e.id != item.id).toList();
  }

  @override
  Future<List<Season>> seasons(String seriesId) async {
    final data = await _db.from('seasons').select().eq('series_id', seriesId).order('season_number');
    return jMapList(data).map(Season.fromJson).toList();
  }

  @override
  Future<List<Episode>> allEpisodes(String seriesId) async {
    final data = await _db
        .from('episodes')
        .select('*, seasons(season_number)')
        .eq('series_id', seriesId)
        .eq('is_published', true);
    final list = jMapList(data).map(Episode.fromJson).toList();
    list.sort((a, b) {
      final s = a.seasonNumber.compareTo(b.seasonNumber);
      return s != 0 ? s : a.number.compareTo(b.number);
    });
    return list;
  }

  @override
  Future<List<VideoSource>> playbackSources({String? movieId, String? episodeId}) async {
    final data = await _db.rpc('get_playback_sources', params: {
      'p_movie_id': movieId,
      'p_episode_id': episodeId,
    });
    return jMapList(data).map(VideoSource.fromJson).where((s) => s.url.isNotEmpty).toList();
  }

  @override
  Future<List<SubtitleItem>> subtitles({String? movieId, String? episodeId}) async {
    if (movieId == null && episodeId == null) return const [];
    final data = movieId != null
        ? await _db.from('subtitles').select().eq('movie_id', movieId)
        : await _db.from('subtitles').select().eq('episode_id', episodeId!);
    return jMapList(data).map(SubtitleItem.fromJson).where((s) => s.url.isNotEmpty).toList();
  }

  @override
  Future<void> logView({
    required MediaKind kind,
    required String titleId,
    String? episodeId,
  }) async {
    try {
      await _db.rpc('log_view', params: {
        'p_kind': kind == MediaKind.movie ? 'movie' : 'episode',
        'p_movie_id': kind == MediaKind.movie ? titleId : null,
        'p_series_id': kind == MediaKind.series ? titleId : null,
        'p_episode_id': episodeId,
      });
    } catch (_) {
      // الإحصائيات لا يجب أن تعطّل التشغيل
    }
  }

  @override
  Future<Map<String, dynamic>> publicSettings() async {
    final data = await _db.from('app_settings').select('key, value');
    final out = <String, dynamic>{};
    for (final row in jMapList(data)) {
      final k = jStr(row['key']);
      if (k != null) out[k] = row['value'];
    }
    return out;
  }

  @override
  Future<List<SubscriptionPlan>> plans() async {
    final data = await _db.from('subscription_plans').select().eq('is_active', true).order('sort_order');
    return jMapList(data).map(SubscriptionPlan.fromJson).toList();
  }

  @override
  Future<SubscriptionPlan?> currentPlan() async {
    final data = await _db.rpc('current_plan');
    final map = data is List ? (data.isEmpty ? null : jMap(data.first)) : jMap(data);
    if (map == null || map['id'] == null) return null;
    return SubscriptionPlan.fromJson(map);
  }
}

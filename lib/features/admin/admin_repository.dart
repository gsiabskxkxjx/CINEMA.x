import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/errors.dart';
import '../../data/models/json_helpers.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

/// ممثل مرتبط بعمل (للنموذج).
class AdminCast {
  AdminCast({required this.actorId, required this.name, this.photoUrl, this.character});

  final String actorId;
  final String name;
  final String? photoUrl;
  String? character;
}

/// عمليات المسؤول على Supabase. الأمان الحقيقي في سياسات RLS على الخادم؛
/// هذا الصنف لا يتحقق من الصلاحية وإنما يرسل الطلبات والخادم يرفضها لغير المسؤول.
class AdminRepository {
  AdminRepository(this._db);

  final SupabaseClient _db;

  String _table(MediaKind k) => k == MediaKind.movie ? 'movies' : 'series';
  String _idCol(MediaKind k) => k == MediaKind.movie ? 'movie_id' : 'series_id';
  String _genreTable(MediaKind k) => k == MediaKind.movie ? 'movie_genres' : 'series_genres';
  String _actorTable(MediaKind k) => k == MediaKind.movie ? 'movie_actors' : 'series_actors';

  /// يزيل المحارف التي تكسر صيغة فلاتر PostgREST (or/ilike).
  static String sanitizeQuery(String q) =>
      q.replaceAll(RegExp(r'[,()%*\\"]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  // ------------------------------------------------------------------ إحصائيات
  Future<Map<String, dynamic>> stats() async {
    final data = await _db.rpc('admin_stats');
    return jMap(data) ?? <String, dynamic>{};
  }

  // ------------------------------------------------------------------ الأفلام والمسلسلات
  Future<List<Map<String, dynamic>>> titles(
    MediaKind kind, {
    String query = '',
    int offset = 0,
    int limit = 40,
  }) async {
    var q = _db.from(_table(kind)).select(
          'id, title_ar, title_en, poster_url, release_year, is_published, is_featured, featured_order, is_premium, view_count',
        );
    final s = sanitizeQuery(query);
    if (s.isNotEmpty) q = q.or('title_ar.ilike.%$s%,title_en.ilike.%$s%');
    final data = await q.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return jMapList(data);
  }

  /// صف العمل كاملاً + `_genre_ids` + `_cast`.
  Future<Map<String, dynamic>> title(MediaKind kind, String id) async {
    final row = await _db.from(_table(kind)).select().eq('id', id).single();
    final genres = await _db.from(_genreTable(kind)).select('genre_id').eq(_idCol(kind), id);
    final cast = await _db
        .from(_actorTable(kind))
        .select('actor_id, character_name, sort_order, actors(id, name_ar, name_en, photo_url)')
        .eq(_idCol(kind), id)
        .order('sort_order');
    return {
      ...Map<String, dynamic>.from(row),
      '_genre_ids': jMapList(genres).map((e) => e['genre_id'].toString()).toList(),
      '_cast': jMapList(cast),
    };
  }

  /// يحفظ العمل (إنشاء أو تعديل) مع الأنواع والممثلين ويعيد المعرّف.
  Future<String> saveTitle(
    MediaKind kind, {
    String? id,
    required Map<String, dynamic> values,
    required List<String> genreIds,
    required List<AdminCast> cast,
  }) async {
    final table = _table(kind);
    final String titleId;
    if (id == null) {
      final row = await _db.from(table).insert(values).select('id').single();
      titleId = row['id'].toString();
    } else {
      await _db.from(table).update(values).eq('id', id);
      titleId = id;
    }
    await _syncGenres(kind, titleId, genreIds);
    await _syncCast(kind, titleId, cast);
    return titleId;
  }

  Future<void> _syncGenres(MediaKind kind, String titleId, List<String> genreIds) async {
    final table = _genreTable(kind);
    final col = _idCol(kind);
    if (genreIds.isNotEmpty) {
      await _db
          .from(table)
          .upsert([for (final g in genreIds) {col: titleId, 'genre_id': g}], onConflict: '$col,genre_id');
      await _db.from(table).delete().eq(col, titleId).not('genre_id', 'in', '(${genreIds.join(',')})');
    } else {
      await _db.from(table).delete().eq(col, titleId);
    }
  }

  Future<void> _syncCast(MediaKind kind, String titleId, List<AdminCast> cast) async {
    final table = _actorTable(kind);
    final col = _idCol(kind);
    if (cast.isNotEmpty) {
      await _db.from(table).upsert(
        [
          for (var i = 0; i < cast.length; i++)
            {
              col: titleId,
              'actor_id': cast[i].actorId,
              'character_name': (cast[i].character ?? '').trim().isEmpty ? null : cast[i].character!.trim(),
              'sort_order': i,
            },
        ],
        onConflict: '$col,actor_id',
      );
      await _db
          .from(table)
          .delete()
          .eq(col, titleId)
          .not('actor_id', 'in', '(${cast.map((c) => c.actorId).join(',')})');
    } else {
      await _db.from(table).delete().eq(col, titleId);
    }
  }

  Future<void> deleteTitle(MediaKind kind, String id) async {
    await _db.from(_table(kind)).delete().eq('id', id);
  }

  Future<void> setPublished(MediaKind kind, String id, bool value) async {
    await _db.from(_table(kind)).update({'is_published': value}).eq('id', id);
  }

  Future<void> setFeatured(MediaKind kind, String id, bool value, {int? order}) async {
    await _db.from(_table(kind)).update({
      'is_featured': value,
      if (order != null) 'featured_order': order,
    }).eq('id', id);
  }

  Future<void> setFeaturedOrder(MediaKind kind, String id, int order) async {
    await _db.from(_table(kind)).update({'featured_order': order}).eq('id', id);
  }

  /// كل الأعمال المميّزة (أفلام ومسلسلات) مرتبة.
  Future<List<Map<String, dynamic>>> featured() async {
    final out = <Map<String, dynamic>>[];
    for (final kind in MediaKind.values) {
      final data = await _db
          .from(_table(kind))
          .select('id, title_ar, title_en, poster_url, featured_order, is_published')
          .eq('is_featured', true);
      for (final r in jMapList(data)) {
        out.add({...r, '_kind': kind.name});
      }
    }
    out.sort((a, b) => (jInt(a['featured_order']) ?? 0).compareTo(jInt(b['featured_order']) ?? 0));
    return out;
  }

  // ------------------------------------------------------------------ المواسم والحلقات
  Future<List<Map<String, dynamic>>> seasons(String seriesId) async {
    final data = await _db.from('seasons').select().eq('series_id', seriesId).order('season_number');
    return jMapList(data);
  }

  Future<void> saveSeason({
    String? id,
    required String seriesId,
    required int number,
    String? titleAr,
    String? titleEn,
  }) async {
    final values = {'season_number': number, 'title_ar': titleAr, 'title_en': titleEn};
    if (id == null) {
      await _db.from('seasons').insert({...values, 'series_id': seriesId});
    } else {
      await _db.from('seasons').update(values).eq('id', id);
    }
  }

  Future<void> deleteSeason(String id) async {
    await _db.from('seasons').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> episodes(String seasonId) async {
    final data = await _db.from('episodes').select().eq('season_id', seasonId).order('episode_number');
    return jMapList(data);
  }

  /// يحفظ حلقة ويعيد معرّفها. series_id يُملأ بمشغّل في قاعدة البيانات.
  Future<String> saveEpisode({
    String? id,
    required String seasonId,
    required Map<String, dynamic> values,
  }) async {
    if (id == null) {
      final row = await _db
          .from('episodes')
          .insert({...values, 'season_id': seasonId})
          .select('id')
          .single();
      return row['id'].toString();
    }
    await _db.from('episodes').update(values).eq('id', id);
    return id;
  }

  Future<void> deleteEpisode(String id) async {
    await _db.from('episodes').delete().eq('id', id);
  }

  // ------------------------------------------------------------------ المصادر والترجمات
  Future<List<Map<String, dynamic>>> sources({String? movieId, String? episodeId}) async {
    final data = await _db
        .from('video_sources')
        .select()
        .eq(movieId != null ? 'movie_id' : 'episode_id', (movieId ?? episodeId)!)
        .order('sort_order')
        .order('created_at');
    return jMapList(data);
  }

  Future<void> saveSource({
    String? id,
    String? movieId,
    String? episodeId,
    required Map<String, dynamic> values,
  }) async {
    if (id == null) {
      await _db.from('video_sources').insert({
        ...values,
        if (movieId != null) 'movie_id': movieId else 'episode_id': episodeId,
      });
    } else {
      await _db.from('video_sources').update(values).eq('id', id);
    }
  }

  /// يحذف المصدر. إن كان ملفاً مرفوعاً في حاوية videos يُحذف الملف أيضاً (محاولة بلا إيقاف عند الفشل).
  Future<void> deleteSource(String id, {String? url}) async {
    await _db.from('video_sources').delete().eq('id', id);
    if (url != null) {
      try {
        await removeVideoFile(url);
      } catch (_) {
        // الصف حُذف؛ بقاء الملف لا يكسر شيئاً، ويمكن حذفه يدوياً من Storage.
      }
    }
  }

  Future<List<Map<String, dynamic>>> subtitles({String? movieId, String? episodeId}) async {
    final data = await _db
        .from('subtitles')
        .select()
        .eq(movieId != null ? 'movie_id' : 'episode_id', (movieId ?? episodeId)!)
        .order('created_at');
    return jMapList(data);
  }

  Future<void> saveSubtitle({
    String? id,
    String? movieId,
    String? episodeId,
    required Map<String, dynamic> values,
  }) async {
    if (id == null) {
      await _db.from('subtitles').insert({
        ...values,
        if (movieId != null) 'movie_id': movieId else 'episode_id': episodeId,
      });
    } else {
      await _db.from('subtitles').update(values).eq('id', id);
    }
    await syncSubtitleLanguages(movieId: movieId, episodeId: episodeId);
  }

  Future<void> deleteSubtitle(String id, {String? movieId, String? episodeId}) async {
    await _db.from('subtitles').delete().eq('id', id);
    await syncSubtitleLanguages(movieId: movieId, episodeId: episodeId);
  }

  /// يحدّث عمود subtitle_languages (المعروض في التفاصيل) من الترجمات الفعلية. أفضل جهد.
  Future<void> syncSubtitleLanguages({String? movieId, String? episodeId}) async {
    try {
      if (movieId != null) {
        final rows = await _db.from('subtitles').select('language').eq('movie_id', movieId);
        final langs = jMapList(rows).map((e) => e['language'].toString().toLowerCase()).toSet().toList()..sort();
        await _db.from('movies').update({'subtitle_languages': langs}).eq('id', movieId);
      } else if (episodeId != null) {
        final ep = await _db.from('episodes').select('series_id').eq('id', episodeId).single();
        final seriesId = ep['series_id'].toString();
        final rows = await _db
            .from('subtitles')
            .select('language, episodes!inner(series_id)')
            .eq('episodes.series_id', seriesId);
        final langs = jMapList(rows).map((e) => e['language'].toString().toLowerCase()).toSet().toList()..sort();
        await _db.from('series').update({'subtitle_languages': langs}).eq('id', seriesId);
      }
    } catch (_) {
      // غير حرج: يمكن للمسؤول تعديل الحقل يدوياً.
    }
  }

  // ------------------------------------------------------------------ الأنواع والفئات
  Future<List<Map<String, dynamic>>> genres() async =>
      jMapList(await _db.from('genres').select().order('sort_order').order('name_ar'));

  Future<void> saveGenre({String? id, required Map<String, dynamic> values}) async {
    if (id == null) {
      await _db.from('genres').insert(values);
    } else {
      await _db.from('genres').update(values).eq('id', id);
    }
  }

  Future<void> deleteGenre(String id) async {
    await _db.from('genres').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> categories() async =>
      jMapList(await _db.from('categories').select().order('sort_order'));

  Future<void> saveCategory({String? id, required Map<String, dynamic> values}) async {
    if (id == null) {
      await _db.from('categories').insert(values);
    } else {
      await _db.from('categories').update(values).eq('id', id);
    }
  }

  Future<void> deleteCategory(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }

  // ------------------------------------------------------------------ الممثلون
  Future<List<Map<String, dynamic>>> actors({String query = '', int limit = 30}) async {
    var q = _db.from('actors').select();
    final s = sanitizeQuery(query);
    if (s.isNotEmpty) q = q.or('name_ar.ilike.%$s%,name_en.ilike.%$s%');
    return jMapList(await q.order('name_ar').limit(limit));
  }

  Future<Map<String, dynamic>> createActor({
    required String nameAr,
    String? nameEn,
    String? photoUrl,
  }) async {
    final row = await _db
        .from('actors')
        .insert({'name_ar': nameAr, 'name_en': nameEn, 'photo_url': photoUrl})
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  // ------------------------------------------------------------------ المستخدمون
  Future<List<Map<String, dynamic>>> users({String query = '', int offset = 0, int limit = 40}) async {
    var q = _db.from('profiles').select('id, email, display_name, avatar_url, role, is_blocked, created_at');
    final s = sanitizeQuery(query);
    if (s.isNotEmpty) q = q.or('email.ilike.%$s%,display_name.ilike.%$s%');
    return jMapList(await q.order('created_at', ascending: false).range(offset, offset + limit - 1));
  }

  Future<void> setRole(String userId, String role) async {
    await _db.from('profiles').update({'role': role}).eq('id', userId);
  }

  Future<void> setBlocked(String userId, bool blocked) async {
    await _db.from('profiles').update({'is_blocked': blocked}).eq('id', userId);
  }

  // ------------------------------------------------------------------ الإعدادات
  Future<Map<String, dynamic>> settings() async {
    final data = await _db.from('app_settings').select('key, value');
    return {for (final r in jMapList(data)) r['key'].toString(): r['value']};
  }

  Future<void> setSetting(String key, Object? value) async {
    await _db.from('app_settings').upsert({'key': key, 'value': value}, onConflict: 'key');
  }

  // ------------------------------------------------------------------ استيراد TMDB
  /// يشغّل دالة الخادم tmdb-import لصف واحد من الصفحة الرئيسية (slug الفئة).
  /// الدالة تتحقق من أنك مسؤول، ومفتاح TMDB محفوظ على الخادم ولا يصل للتطبيق.
  Future<Map<String, dynamic>> importTmdb(String category) async {
    final res = await _db.functions
        .invoke('tmdb-import', body: {'category': category})
        .timeout(const Duration(minutes: 4));
    return jMap(res.data) ?? <String, dynamic>{};
  }

  // ------------------------------------------------------------------ رفع الفيديو
  static const _videoBucket = 'videos';
  static const _videoMime = {
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
    'mkv': 'video/x-matroska',
  };

  /// مسار الملف داخل حاوية videos إن كان الرابط رابط ملف مرفوع من هذا المشروع، وإلا null.
  static String? videoPathFromUrl(String url) {
    if (AppConfig.supabaseUrl.isEmpty) return null;
    final prefix = '${AppConfig.supabaseUrl}/storage/v1/object/public/$_videoBucket/';
    if (!url.startsWith(prefix)) return null;
    try {
      final path = Uri.decodeComponent(url.substring(prefix.length).split('?').first);
      return path.isEmpty || path.contains('..') ? null : path;
    } on FormatException {
      return null;
    }
  }

  /// يرفع ملف فيديو من الجهاز إلى حاوية videos (للمسؤول فقط عبر RLS) ويعيد رابطه العام.
  /// الرفع بالبثّ (Stream) فلا يُحمَّل الملف كله في الذاكرة، ويُبلَّغ التقدّم عبر [onProgress].
  /// ⚠️ حدّ الحجم يفرضه الخادم (الخطة المجانية 50 MB للملف).
  Future<String> uploadVideo({
    required File file,
    required void Function(int sent, int total) onProgress,
    required VideoUploadCancel cancel,
  }) async {
    final name = file.path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    final mime = _videoMime[ext];
    if (mime == null) throw const AppException('admin_upload_type');

    final token = _db.auth.currentSession?.accessToken;
    if (token == null) throw const AppException('err_not_authenticated');

    final total = await file.length();
    final rnd = Random.secure().nextInt(1 << 31).toRadixString(36);
    final path = 'uploads/${DateTime.now().millisecondsSinceEpoch}_$rnd.$ext';
    final uri = Uri.parse('${AppConfig.supabaseUrl}/storage/v1/object/$_videoBucket/$path');

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    cancel._client = client;
    try {
      if (cancel.isCancelled) throw const VideoUploadCancelled();
      final req = await client.postUrl(uri);
      req.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set('apikey', AppConfig.supabaseAnonKey)
        ..set(HttpHeaders.contentTypeHeader, mime)
        ..set('x-upsert', 'false')
        ..set('cache-control', 'max-age=3600');
      req.contentLength = total;

      var sent = 0;
      onProgress(0, total);
      await req.addStream(file.openRead().map((chunk) {
        if (cancel.isCancelled) throw const VideoUploadCancelled();
        sent += chunk.length;
        onProgress(sent, total);
        return chunk;
      }));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final code = res.statusCode;
      if (code < 200 || code >= 300) {
        final b = body.toLowerCase();
        if (code == 413 || b.contains('exceeded') || b.contains('too large') || b.contains('maximum allowed size')) {
          throw const AppException('admin_upload_server_limit');
        }
        if (code == 401 || code == 403 || b.contains('row-level security') || b.contains('unauthorized')) {
          throw const AppException('err_forbidden');
        }
        if (b.contains('mime')) throw const AppException('admin_upload_type');
        throw const AppException('err_upload');
      }
    } on VideoUploadCancelled {
      rethrow;
    } catch (_) {
      // إلغاء المستخدم يغلق الاتصال قسراً فيظهر كخطأ شبكة؛ نحوّله إلى إلغاء.
      if (cancel.isCancelled) throw const VideoUploadCancelled();
      rethrow;
    } finally {
      cancel._client = null;
      client.close(force: true);
    }
    return _db.storage.from(_videoBucket).getPublicUrl(path);
  }

  /// يحذف ملفاً مرفوعاً سابقاً (إن كان الرابط يعود لحاوية videos في هذا المشروع).
  Future<void> removeVideoFile(String url) async {
    final path = videoPathFromUrl(url);
    if (path == null) return;
    await _db.storage.from(_videoBucket).remove([path]);
  }

  // ------------------------------------------------------------------ رفع الصور
  /// يرفع صورة إلى حاوية عامة ويعيد رابطها العام.
  Future<String> uploadImage({
    required String bucket,
    required Uint8List bytes,
    required String extension,
    String folder = 'content',
  }) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final safeExt = const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext) ? ext : 'jpg';
    final rnd = Random.secure().nextInt(1 << 31).toRadixString(36);
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$rnd.$safeExt';
    await _db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeForExtension(safeExt), upsert: false),
        );
    return _db.storage.from(bucket).getPublicUrl(path);
  }
}

/// يُلقى عند إلغاء رفع الفيديو من قِبل المستخدم.
class VideoUploadCancelled implements Exception {
  const VideoUploadCancelled();
}

/// مقبض لإلغاء رفع جارٍ: يغلق الاتصال فوراً.
class VideoUploadCancel {
  bool _cancelled = false;
  HttpClient? _client;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }
}

final adminRepoProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(Supabase.instance.client),
);

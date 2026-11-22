import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'demo_data.dart';

/// مستودع المحتوى في الوضع التجريبي (بيانات في الذاكرة).
class DemoContentRepository implements ContentRepository {
  DemoContentRepository();

  final DemoData _d = DemoData.instance;

  Future<T> _latency<T>(T value) async {
    // تأخير بسيط ليظهر Skeleton Loading ويشبه الشبكة الحقيقية
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return value;
  }

  List<MediaItem> _sorted(Iterable<MediaItem> src, String sort) {
    final list = src.toList();
    int cmpDate(MediaItem a, MediaItem b) =>
        (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
    switch (sort) {
      case 'popular':
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      case 'rating':
        list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case 'year':
        list.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      default:
        list.sort(cmpDate);
    }
    return list;
  }

  bool _matchesText(MediaItem i, String q) {
    final n = normalizeSearch(q);
    if (n.isEmpty) return true;
    bool has(String? s) => s != null && normalizeSearch(s).contains(n);
    if (has(i.titleAr) || has(i.titleEn) || has(i.director)) return true;
    for (final a in i.cast) {
      if (has(a.nameAr) || has(a.nameEn)) return true;
    }
    return false;
  }

  @override
  Future<List<MediaItem>> featured() async {
    final list = _d.items.where((i) => i.isFeatured).toList()
      ..sort((a, b) => a.featuredOrder.compareTo(b.featuredOrder));
    return _latency(list.take(6).toList());
  }

  @override
  Future<List<MediaItem>> mostWatched({int limit = 15}) async =>
      _latency(_sorted(_d.items, 'popular').take(limit).toList());

  @override
  Future<List<MediaItem>> latest({int limit = 15}) async =>
      _latency(_sorted(_d.items, 'latest').take(limit).toList());

  @override
  Future<List<CategoryRow>> homeCategories() async => _latency(
      _d.categories.where((c) => c.isActive && c.showOnHome).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  @override
  Future<List<MediaItem>> browse(CatalogQuery query, {required int offset, required int limit}) async {
    Iterable<MediaItem> r = _d.items;
    if (query.kind != null) r = r.where((i) => i.kind == query.kind);
    if (query.origin != null) r = r.where((i) => i.origin == query.origin);
    if (query.genreId != null) r = r.where((i) => i.genres.any((g) => g.id == query.genreId));
    if (query.year != null) r = r.where((i) => i.year == query.year);
    if (query.country != null) r = r.where((i) => i.country == query.country);
    final text = query.text;
    if (text != null && text.trim().isNotEmpty) r = r.where((i) => _matchesText(i, text));
    final sorted = _sorted(r, query.sort);
    final page = sorted.skip(offset).take(limit).toList();
    return _latency(page);
  }

  @override
  Future<List<String>> suggestions(String text) async {
    final t = text.trim();
    if (t.isEmpty) return const [];
    final out = <String>[];
    for (final i in _sorted(_d.items, 'popular')) {
      if (_matchesText(i, t)) {
        final title = normalizeSearch(i.titleAr).contains(normalizeSearch(t)) ? i.titleAr : (i.titleEn ?? i.titleAr);
        if (!out.contains(title)) out.add(title);
      }
      if (out.length >= 6) break;
    }
    return out;
  }

  @override
  Future<List<Genre>> genres() async => _d.genres;

  @override
  Future<List<String>> countries() async {
    final set = <String>{};
    for (final i in _d.items) {
      if (i.country != null) set.add(i.country!);
    }
    return set.toList()..sort();
  }

  @override
  Future<MediaItem> details(MediaKind kind, String id) async {
    final item = _d.byId(id);
    if (item == null) throw const AppException('err_not_found');
    return _latency(item);
  }

  @override
  Future<List<MediaItem>> similar(MediaItem item) async {
    final ids = item.genres.map((g) => g.id).toSet();
    final list = _d.items
        .where((i) => i.id != item.id && i.kind == item.kind && i.genres.any((g) => ids.contains(g.id)))
        .toList();
    return _sorted(list, 'popular').take(14).toList();
  }

  @override
  Future<List<Season>> seasons(String seriesId) async => _d.seasonsBySeries[seriesId] ?? const [];

  @override
  Future<List<Episode>> allEpisodes(String seriesId) async => _d.episodesBySeries[seriesId] ?? const [];

  @override
  Future<List<VideoSource>> playbackSources({String? movieId, String? episodeId}) async {
    final list = _d.sourcesByContent[movieId ?? episodeId] ?? const <VideoSource>[];
    return _latency(list);
  }

  @override
  Future<List<SubtitleItem>> subtitles({String? movieId, String? episodeId}) async =>
      _d.subtitlesByContent[movieId ?? episodeId] ?? const [];

  @override
  Future<void> logView({required MediaKind kind, required String titleId, String? episodeId}) async {}

  @override
  Future<Map<String, dynamic>> publicSettings() async => const {};

  @override
  Future<List<SubscriptionPlan>> plans() async => _d.plans;

  @override
  Future<SubscriptionPlan?> currentPlan() async => _d.plans.first;
}

/// بيانات المستخدم في الوضع التجريبي: تُحفظ محلياً في SharedPreferences.
class LocalUserRepository implements UserRepository {
  LocalUserRepository(this._prefs, this._content);

  final SharedPreferences _prefs;
  final ContentRepository _content;

  static const String _favKey = 'demo_favorites';
  static const String _histKey = 'demo_history';

  // -------------------------------------------------------------- المفضلة
  @override
  Future<List<MediaItem>> favorites() async {
    final ids = _prefs.getStringList(_favKey) ?? const <String>[];
    final out = <MediaItem>[];
    for (final entry in ids.reversed) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      try {
        out.add(await _content.details(MediaKind.parse(parts[0]), parts[1]));
      } catch (_) {}
    }
    return out;
  }

  @override
  Future<void> setFavorite(MediaItem item, bool value) async {
    final key = '${item.kind.name}:${item.id}';
    final list = [...(_prefs.getStringList(_favKey) ?? const <String>[])];
    list.remove(key);
    if (value) list.add(key);
    await _prefs.setStringList(_favKey, list);
  }

  // -------------------------------------------------------------- السجل
  List<Map<String, dynamic>> _rows() {
    final raw = _prefs.getString(_histKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> rows) => _prefs.setString(_histKey, jsonEncode(rows));

  Future<WatchEntry?> _toEntry(Map<String, dynamic> r) async {
    try {
      final isEpisode = r['episodeId'] != null;
      final item = await _content.details(isEpisode ? MediaKind.series : MediaKind.movie, r['titleId'] as String);
      Episode? ep;
      if (isEpisode) {
        final eps = await _content.allEpisodes(item.id);
        ep = eps.firstWhere((e) => e.id == r['episodeId']);
      }
      return WatchEntry(
        item: item,
        episode: ep,
        positionSeconds: (r['pos'] as num).toInt(),
        durationSeconds: (r['dur'] as num).toInt(),
        completed: r['done'] == true,
        updatedAt: DateTime.fromMillisecondsSinceEpoch((r['ts'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<WatchEntry>> _entries() async {
    final rows = _rows()..sort((a, b) => (b['ts'] as num).compareTo(a['ts'] as num));
    final out = <WatchEntry>[];
    for (final r in rows) {
      final e = await _toEntry(r);
      if (e != null) out.add(e);
    }
    return out;
  }

  @override
  Future<List<WatchEntry>> history({int limit = 100}) async => (await _entries()).take(limit).toList();

  @override
  Future<List<WatchEntry>> continueWatching() async {
    final seen = <String>{};
    final out = <WatchEntry>[];
    for (final e in await _entries()) {
      if (e.completed || e.positionSeconds <= 10) continue;
      if (seen.add(e.item.id)) out.add(e);
      if (out.length >= 15) break;
    }
    return out;
  }

  @override
  Future<WatchEntry?> movieProgress(String movieId) async {
    for (final r in _rows()) {
      if (r['episodeId'] == null && r['titleId'] == movieId) return _toEntry(r);
    }
    return null;
  }

  @override
  Future<Map<String, WatchEntry>> seriesProgress(String seriesId) async {
    final out = <String, WatchEntry>{};
    for (final r in _rows()) {
      if (r['episodeId'] != null && r['titleId'] == seriesId) {
        final e = await _toEntry(r);
        if (e != null) out[e.episode!.id] = e;
      }
    }
    return out;
  }

  @override
  Future<void> saveProgress({
    required MediaItem item,
    Episode? episode,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final rows = _rows();
    final key = episode?.id ?? item.id;
    rows.removeWhere((r) => (r['episodeId'] ?? r['titleId']) == key);
    final done = durationSeconds > 0 &&
        (positionSeconds >= durationSeconds * 0.95 || durationSeconds - positionSeconds < 45);
    rows.add({
      'titleId': item.id,
      'episodeId': episode?.id,
      'pos': positionSeconds,
      'dur': durationSeconds,
      'done': done,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    await _write(rows);
  }

  @override
  Future<void> removeFromHistory(WatchEntry entry) async {
    final rows = _rows()..removeWhere((r) => (r['episodeId'] ?? r['titleId']) == entry.key);
    await _write(rows);
  }

  @override
  Future<void> clearHistory() => _prefs.remove(_histKey);

  // -------------------------------------------------------------- الملف الشخصي
  @override
  Future<AppProfile> profile() async => AppProfile.demo();

  @override
  Future<void> updateProfile(Map<String, dynamic> changes) async {}

  @override
  Future<String> uploadAvatar(Uint8List bytes, String extension) async =>
      throw const AppException('err_demo_mode');

  @override
  Future<void> registerDevice(String deviceId, String name, String platform) async {}
}

/// مصادقة تجريبية: مستخدم محلي ثابت.
class DemoAuthService implements AuthService {
  static const SessionUser _user = SessionUser(id: 'demo');

  @override
  SessionUser? get current => _user;

  @override
  Stream<SessionUser?> get changes => Stream<SessionUser?>.value(_user);

  @override
  Stream<void> get passwordRecovery => const Stream<void>.empty();

  @override
  Future<bool> signUp({required String email, required String password, required String name}) =>
      throw const AppException('err_demo_mode');

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw const AppException('err_demo_mode');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) => throw const AppException('err_demo_mode');

  @override
  Future<void> updatePassword(String newPassword) => throw const AppException('err_demo_mode');
}

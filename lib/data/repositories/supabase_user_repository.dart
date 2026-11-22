import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/errors.dart';
import '../models/json_helpers.dart';
import '../models/models.dart';
import 'repositories.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this._db);

  final SupabaseClient _db;

  String get _uid {
    final u = _db.auth.currentUser;
    if (u == null) throw const AppException('err_not_authenticated');
    return u.id;
  }

  static const String _historySelect = '*, movies(*), series(*), episodes(*, seasons(season_number))';

  // ---------------------------------------------------------------- المفضلة
  @override
  Future<List<MediaItem>> favorites() async {
    final data = await _db
        .from('favorites')
        .select('kind, movies(*), series(*)')
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    final out = <MediaItem>[];
    for (final row in jMapList(data)) {
      final isMovie = row['kind'] == 'movie';
      final m = jMap(isMovie ? row['movies'] : row['series']);
      if (m != null) {
        out.add(MediaItem.fromJson(m, kind: isMovie ? MediaKind.movie : MediaKind.series));
      }
    }
    return out;
  }

  @override
  Future<void> setFavorite(MediaItem item, bool value) async {
    final uid = _uid;
    if (value) {
      await _db.from('favorites').upsert(
        {
          'user_id': uid,
          'kind': item.kind.name,
          if (item.kind == MediaKind.movie) 'movie_id': item.id else 'series_id': item.id,
        },
        onConflict: 'user_id,title_id',
        ignoreDuplicates: true,
      );
    } else {
      await _db.from('favorites').delete().eq('user_id', uid).eq('title_id', item.id);
    }
  }

  // ---------------------------------------------------------------- السجل
  @override
  Future<List<WatchEntry>> history({int limit = 100}) async {
    final data = await _db
        .from('watch_history')
        .select(_historySelect)
        .eq('user_id', _uid)
        .order('updated_at', ascending: false)
        .limit(limit);
    return jMapList(data).map(WatchEntry.tryParse).whereType<WatchEntry>().toList();
  }

  @override
  Future<List<WatchEntry>> continueWatching() async {
    final data = await _db
        .from('watch_history')
        .select(_historySelect)
        .eq('user_id', _uid)
        .eq('completed', false)
        .gt('position_seconds', 10)
        .order('updated_at', ascending: false)
        .limit(40);
    final seen = <String>{};
    final out = <WatchEntry>[];
    for (final e in jMapList(data).map(WatchEntry.tryParse).whereType<WatchEntry>()) {
      if (seen.add(e.item.id)) out.add(e); // آخر حلقة لكل مسلسل
      if (out.length >= 15) break;
    }
    return out;
  }

  @override
  Future<WatchEntry?> movieProgress(String movieId) async {
    final data = await _db
        .from('watch_history')
        .select(_historySelect)
        .eq('user_id', _uid)
        .eq('movie_id', movieId)
        .maybeSingle();
    return data == null ? null : WatchEntry.tryParse(data);
  }

  @override
  Future<Map<String, WatchEntry>> seriesProgress(String seriesId) async {
    final data = await _db
        .from('watch_history')
        .select(_historySelect)
        .eq('user_id', _uid)
        .eq('series_id', seriesId);
    final out = <String, WatchEntry>{};
    for (final e in jMapList(data).map(WatchEntry.tryParse).whereType<WatchEntry>()) {
      final id = e.episode?.id;
      if (id != null) out[id] = e;
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
    await _db.rpc('save_progress', params: {
      'p_kind': episode == null ? 'movie' : 'episode',
      'p_movie_id': episode == null ? item.id : null,
      'p_series_id': episode == null ? null : item.id,
      'p_episode_id': episode?.id,
      'p_position': positionSeconds,
      'p_duration': durationSeconds,
    });
  }

  @override
  Future<void> removeFromHistory(WatchEntry entry) async {
    final col = entry.episode == null ? 'movie_id' : 'episode_id';
    await _db.from('watch_history').delete().eq('user_id', _uid).eq(col, entry.key);
  }

  @override
  Future<void> clearHistory() async {
    await _db.from('watch_history').delete().eq('user_id', _uid);
  }

  // ---------------------------------------------------------------- الملف الشخصي
  @override
  Future<AppProfile> profile() async {
    final row = await _db.from('profiles').select().eq('id', _uid).single();
    return AppProfile.fromJson(row);
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    await _db.from('profiles').update(changes).eq('id', _uid);
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final uid = _uid;
    final ext = extension.toLowerCase().replaceAll('.', '');
    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeForExtension(ext), upsert: true),
        );
    final url = _db.storage.from('avatars').getPublicUrl(path);
    await updateProfile({'avatar_url': url});
    return url;
  }

  @override
  Future<void> registerDevice(String deviceId, String name, String platform) async {
    await _db.rpc('register_device', params: {
      'p_device_id': deviceId,
      'p_name': name,
      'p_platform': platform,
    });
  }
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  AuthUser? _map(User? u) => u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  AuthUser? get current => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> get changes async* {
    // distinct: تجديد الرمز (tokenRefreshed) لا يجب أن يعيد بناء كل المزوّدات.
    AuthUser? last = current;
    yield last;
    await for (final state in _auth.onAuthStateChange) {
      final next = _map(state.session?.user);
      if (next != last) {
        last = next;
        yield next;
      }
    }
  }

  @override
  Stream<void> get passwordRecovery => _auth.onAuthStateChange
      .where((s) => s.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
      emailRedirectTo: _redirect,
    );
    return res.session != null;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> resetPassword(String email) =>
      _auth.resetPasswordForEmail(email.trim(), redirectTo: _redirect);

  @override
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  static const String _redirect = 'io.cinemax.app://login-callback';
}

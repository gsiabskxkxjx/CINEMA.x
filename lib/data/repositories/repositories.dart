import 'dart:typed_data';

import '../models/models.dart';

/// قراءة المحتوى (أفلام، مسلسلات، بحث، روابط التشغيل).
abstract class ContentRepository {
  Future<List<MediaItem>> featured();
  Future<List<MediaItem>> mostWatched({int limit = 15});
  Future<List<MediaItem>> latest({int limit = 15});
  Future<List<CategoryRow>> homeCategories();
  Future<List<MediaItem>> browse(CatalogQuery query, {required int offset, required int limit});
  Future<List<String>> suggestions(String text);
  Future<List<Genre>> genres();
  Future<List<String>> countries();
  Future<MediaItem> details(MediaKind kind, String id);
  Future<List<MediaItem>> similar(MediaItem item);
  Future<List<Season>> seasons(String seriesId);
  Future<List<Episode>> allEpisodes(String seriesId);

  /// روابط التشغيل. في Supabase تأتي عبر دالة محمية على الخادم.
  Future<List<VideoSource>> playbackSources({String? movieId, String? episodeId});
  Future<List<SubtitleItem>> subtitles({String? movieId, String? episodeId});

  /// تسجيل مشاهدة (للإحصائيات). لا يرمي أخطاء.
  Future<void> logView({
    required MediaKind kind,
    required String titleId,
    String? episodeId,
  });

  /// إعدادات عامة (وضع الصيانة...).
  Future<Map<String, dynamic>> publicSettings();

  Future<List<SubscriptionPlan>> plans();
  Future<SubscriptionPlan?> currentPlan();
}

/// بيانات المستخدم: المفضلة، السجل، الملف الشخصي.
abstract class UserRepository {
  Future<List<MediaItem>> favorites();
  Future<void> setFavorite(MediaItem item, bool value);

  Future<List<WatchEntry>> continueWatching();
  Future<List<WatchEntry>> history({int limit = 100});
  Future<WatchEntry?> movieProgress(String movieId);
  Future<Map<String, WatchEntry>> seriesProgress(String seriesId);
  Future<void> saveProgress({
    required MediaItem item,
    Episode? episode,
    required int positionSeconds,
    required int durationSeconds,
  });
  Future<void> removeFromHistory(WatchEntry entry);
  Future<void> clearHistory();

  Future<AppProfile> profile();
  Future<void> updateProfile(Map<String, dynamic> changes);
  Future<String> uploadAvatar(Uint8List bytes, String extension);
  Future<void> registerDevice(String deviceId, String name, String platform);
}

/// المصادقة.
abstract class AuthService {
  SessionUser? get current;
  Stream<SessionUser?> get changes;
  Stream<void> get passwordRecovery;

  /// true = تم تسجيل الدخول فوراً، false = يلزم تأكيد البريد.
  Future<bool> signUp({required String email, required String password, required String name});
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String newPassword);
}

String mimeForExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

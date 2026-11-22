import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../data/demo/demo_repositories.dart';
import '../data/models/models.dart';
import '../data/repositories/repositories.dart';
import '../data/repositories/supabase_content_repository.dart';
import '../data/repositories/supabase_user_repository.dart';

// ====================================================================== الأساس
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden in main()'),
);

final contentRepoProvider = Provider<ContentRepository>((ref) {
  return AppConfig.hasBackend
      ? SupabaseContentRepository(Supabase.instance.client)
      : DemoContentRepository();
});

final userRepoProvider = Provider<UserRepository>((ref) {
  if (AppConfig.hasBackend) return SupabaseUserRepository(Supabase.instance.client);
  return LocalUserRepository(ref.watch(sharedPrefsProvider), ref.watch(contentRepoProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AppConfig.hasBackend ? SupabaseAuthService(Supabase.instance.client) : DemoAuthService();
});

final authUserProvider = StreamProvider<SessionUser?>((ref) => ref.watch(authServiceProvider).changes);

/// يصبح true عند فتح رابط استعادة كلمة المرور.
final recoveryActiveProvider = StateProvider<bool>((ref) => false);

final profileProvider = FutureProvider<AppProfile>((ref) async {
  if (!AppConfig.hasBackend) return AppProfile.demo();
  final user = ref.watch(authUserProvider).valueOrNull;
  if (user == null) throw StateError('no signed-in user');
  return ref.read(userRepoProvider).profile();
});

final isAdminProvider = Provider<bool>((ref) {
  if (!AppConfig.hasBackend) return false;
  return ref.watch(profileProvider).valueOrNull?.isAdmin ?? false;
});

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});

final publicSettingsProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(contentRepoProvider).publicSettings(),
);

// ====================================================================== اللغة والإعدادات
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.read(sharedPrefsProvider).getString('locale') ?? 'ar');

  Future<void> set(String code, {bool syncProfile = true}) async {
    if (state.languageCode == code) return;
    state = Locale(code);
    await ref.read(sharedPrefsProvider).setString('locale', code);
    if (syncProfile && AppConfig.hasBackend) {
      unawaited(ref.read(userRepoProvider).updateProfile({'language': code}).catchError((_) {}));
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

class AppSettings {
  const AppSettings({this.quality = 'auto', this.subtitle = 'off', this.autoplayNext = true});

  final String quality; // auto | 1080 | 720 | 480 | 360
  final String subtitle; // off | ar | en
  final bool autoplayNext;

  AppSettings copyWith({String? quality, String? subtitle, bool? autoplayNext}) => AppSettings(
        quality: quality ?? this.quality,
        subtitle: subtitle ?? this.subtitle,
        autoplayNext: autoplayNext ?? this.autoplayNext,
      );
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final p = ref.read(sharedPrefsProvider);
    return AppSettings(
      quality: p.getString('quality') ?? 'auto',
      subtitle: p.getString('subtitle') ?? 'off',
      autoplayNext: p.getBool('autoplay') ?? true,
    );
  }

  Future<void> _persist(AppSettings s) async {
    final p = ref.read(sharedPrefsProvider);
    await p.setString('quality', s.quality);
    await p.setString('subtitle', s.subtitle);
    await p.setBool('autoplay', s.autoplayNext);
  }

  Future<void> update({String? quality, String? subtitle, bool? autoplayNext}) async {
    final next = state.copyWith(quality: quality, subtitle: subtitle, autoplayNext: autoplayNext);
    state = next;
    await _persist(next);
    if (AppConfig.hasBackend) {
      unawaited(ref.read(userRepoProvider).updateProfile({
        'preferred_quality': next.quality,
        'subtitle_language': next.subtitle,
        'autoplay_next': next.autoplayNext,
      }).catchError((_) {}));
    }
  }

  /// تطبيق إعدادات الحساب المحفوظة على الخادم (عند تسجيل الدخول).
  void applyFromProfile(AppProfile p) {
    final next = AppSettings(
      quality: p.preferredQuality,
      subtitle: p.subtitleLanguage,
      autoplayNext: p.autoplayNext,
    );
    state = next;
    unawaited(_persist(next));
    unawaited(ref.read(localeProvider.notifier).set(p.language, syncProfile: false));
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// معرّف الجهاز (يُولَّد مرة واحدة) لحدود الأجهزة المستقبلية.
final deviceIdProvider = Provider<String>((ref) {
  final p = ref.read(sharedPrefsProvider);
  var id = p.getString('device_id');
  if (id == null) {
    final r = Random.secure();
    id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${r.nextInt(1 << 32).toRadixString(36)}';
    unawaited(p.setString('device_id', id));
  }
  return id;
});

// ====================================================================== الصفحة الرئيسية
final homeProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final repo = ref.watch(contentRepoProvider);
  final (featured, most, latest, cats) =
      await (repo.featured(), repo.mostWatched(), repo.latest(), repo.homeCategories()).wait;

  final rows = await Future.wait(cats.map((c) async {
    final items = await repo.browse(
      CatalogQuery(kind: c.kind, origin: c.origin, genreId: c.genreId, sort: 'popular'),
      offset: 0,
      limit: AppConfig.rowSize,
    );
    return HomeRow(c, items);
  }));

  return HomeData(
    featured: featured,
    mostWatched: most,
    latest: latest,
    rows: rows.where((r) => r.items.isNotEmpty).toList(),
  );
});

final continueWatchingProvider = FutureProvider.autoDispose<List<WatchEntry>>((ref) {
  ref.watch(authUserProvider);
  return ref.watch(userRepoProvider).continueWatching();
});

final historyProvider = FutureProvider.autoDispose<List<WatchEntry>>((ref) {
  ref.watch(authUserProvider);
  return ref.watch(userRepoProvider).history();
});

// ====================================================================== المفضلة
class FavoritesController extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    ref.watch(authUserProvider);
    return ref.read(userRepoProvider).favorites();
  }

  bool contains(String id) => state.valueOrNull?.any((e) => e.id == id) ?? false;

  /// تبديل المفضلة بتحديث فوري (Optimistic) مع تراجع عند الفشل.
  Future<void> toggle(MediaItem item) async {
    final current = state.valueOrNull ?? const <MediaItem>[];
    final exists = current.any((e) => e.id == item.id);
    final next = exists ? current.where((e) => e.id != item.id).toList() : [item, ...current];
    state = AsyncData(next);
    try {
      await ref.read(userRepoProvider).setFavorite(item, !exists);
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesController, List<MediaItem>>(FavoritesController.new);

final isFavoriteProvider = Provider.family<bool, String>((ref, id) {
  return ref.watch(favoritesProvider).valueOrNull?.any((e) => e.id == id) ?? false;
});

// ====================================================================== التفاصيل
final genresProvider = FutureProvider<List<Genre>>((ref) => ref.watch(contentRepoProvider).genres());

final countriesProvider = FutureProvider<List<String>>((ref) => ref.watch(contentRepoProvider).countries());

final detailsProvider = FutureProvider.autoDispose.family<MediaItem, MediaRef>(
  (ref, r) => ref.watch(contentRepoProvider).details(r.kind, r.id),
);

final similarProvider = FutureProvider.autoDispose.family<List<MediaItem>, MediaRef>((ref, r) async {
  final item = await ref.watch(detailsProvider(r).future);
  return ref.watch(contentRepoProvider).similar(item);
});

final seriesContentProvider = FutureProvider.autoDispose.family<SeriesContent, String>((ref, id) async {
  final repo = ref.watch(contentRepoProvider);
  final (seasons, episodes) = await (repo.seasons(id), repo.allEpisodes(id)).wait;
  return SeriesContent(seasons: seasons, episodes: episodes);
});

final seriesProgressProvider = FutureProvider.autoDispose.family<Map<String, WatchEntry>, String>((ref, id) {
  ref.watch(authUserProvider);
  return ref.watch(userRepoProvider).seriesProgress(id);
});

final movieProgressProvider = FutureProvider.autoDispose.family<WatchEntry?, String>((ref, id) {
  ref.watch(authUserProvider);
  return ref.watch(userRepoProvider).movieProgress(id);
});

// ====================================================================== الشبكات المرقّمة (Pagination)
class PagerState {
  const PagerState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.initialized = false,
    this.error,
  });

  final List<MediaItem> items;
  final bool loading;
  final bool hasMore;
  final bool initialized;
  final Object? error;

  PagerState copyWith({
    List<MediaItem>? items,
    bool? loading,
    bool? hasMore,
    bool? initialized,
    Object? error,
    bool clearError = false,
  }) =>
      PagerState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        hasMore: hasMore ?? this.hasMore,
        initialized: initialized ?? this.initialized,
        error: clearError ? null : (error ?? this.error),
      );
}

class CatalogPager extends StateNotifier<PagerState> {
  CatalogPager(this._repo, this.query) : super(const PagerState()) {
    loadMore();
  }

  final ContentRepository _repo;
  final CatalogQuery query;

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _repo.browse(query, offset: state.items.length, limit: AppConfig.pageSize);
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...page],
        loading: false,
        hasMore: page.length >= AppConfig.pageSize,
        initialized: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, initialized: true, error: e);
    }
  }

  Future<void> refresh() async {
    state = const PagerState();
    await loadMore();
  }
}

final catalogPagerProvider =
    StateNotifierProvider.autoDispose.family<CatalogPager, PagerState, CatalogQuery>(
  (ref, query) => CatalogPager(ref.watch(contentRepoProvider), query),
);

// ====================================================================== البحث
class SearchHistoryController extends Notifier<List<String>> {
  static const String _key = 'search_history';

  @override
  List<String> build() => ref.read(sharedPrefsProvider).getStringList(_key) ?? <String>[];

  Future<void> add(String query) async {
    final t = query.trim();
    if (t.isEmpty) return;
    final list = [t, ...state.where((e) => e != t)].take(12).toList();
    state = list;
    await ref.read(sharedPrefsProvider).setStringList(_key, list);
  }

  Future<void> remove(String query) async {
    final list = state.where((e) => e != query).toList();
    state = list;
    await ref.read(sharedPrefsProvider).setStringList(_key, list);
  }

  Future<void> clear() async {
    state = <String>[];
    await ref.read(sharedPrefsProvider).remove(_key);
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryController, List<String>>(SearchHistoryController.new);

final suggestionsProvider = FutureProvider.autoDispose.family<List<String>, String>((ref, text) {
  if (text.trim().isEmpty) return Future.value(const <String>[]);
  return ref.watch(contentRepoProvider).suggestions(text);
});

// ====================================================================== الاشتراكات (عرض فقط)
final plansProvider = FutureProvider.autoDispose<List<SubscriptionPlan>>(
  (ref) => ref.watch(contentRepoProvider).plans(),
);

final currentPlanProvider = FutureProvider.autoDispose<SubscriptionPlan?>(
  (ref) => ref.watch(contentRepoProvider).currentPlan(),
);

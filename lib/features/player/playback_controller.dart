import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/utils/errors.dart' as err;
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import 'playback_logic.dart';

enum PlayPhase {
  loadingSources,
  opening,
  ready,
  reconnecting,
  waitingNetwork,
  error,
  ended,
}

/// خيار جودة في القائمة.
class QualityChoice {
  const QualityChoice(this.key, this.label, {this.subtitle});
  final String key; // auto | src:<id> | trk:<id>
  final String label;
  final String? subtitle;
}

/// يملك Player ويدير: فتح المصادر، الاستئناف، الترجمة، إعادة الاتصال، حفظ التقدّم، الحلقة التالية.
/// لا يعتمد على Riverpod كي يبقى سلوك الإنهاء آمناً داخل dispose.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required this.content,
    required this.user,
    required this.item,
    required Episode? episode,
    required this.episodes,
    required this.isOnline,
    required this.preferredQuality,
    required this.defaultSubtitle,
    required this.autoplayNext,
  }) : _episode = episode {
    _bind();
  }

  final ContentRepository content;
  final UserRepository user;
  final MediaItem item;
  final List<Episode> episodes;
  final bool Function() isOnline;
  final String preferredQuality;
  final String defaultSubtitle;
  final bool autoplayNext;

  final Player player = Player(configuration: const PlayerConfiguration(title: 'CINEMA X'));
  late final VideoController video = VideoController(player);

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> buffer = ValueNotifier(Duration.zero);

  static const int _maxAttempts = 3;

  Episode? _episode;
  PlayPhase _phase = PlayPhase.loadingSources;
  String? _errorKey;
  bool _playing = false;
  bool _buffering = false;
  bool _userPaused = false;
  double _rate = 1.0;
  double _volume = 100.0;
  Tracks _tracks = Tracks();

  List<VideoSource> _sources = const [];
  VideoSource? _src;
  final Set<String> _failedSources = {};
  List<SubtitleItem> _subtitles = const [];
  String _subtitleKey = 'off';
  String _qualityKey = 'auto';
  String _audioKey = 'auto';

  int _attempt = 0;
  int _openToken = 0;
  Duration _lastGoodPosition = Duration.zero;
  Duration _attemptStartPos = Duration.zero;
  int _lastSavedPos = -1;
  bool _viewLogged = false;
  bool _showNextUp = false;
  bool _nextDismissed = false;
  bool _showSkipIntro = false;
  bool _disposed = false;

  Map<String, WatchEntry>? _seriesProgress;
  final Map<String, int> _localResume = {};

  Completer<void>? _durationWaiter;
  Timer? _stallTimer;
  Timer? _openTimer;
  Timer? _retryTimer;
  Timer? _errorCheck;
  Timer? _saveTimer;
  final List<StreamSubscription<dynamic>> _subs = [];

  // ------------------------------------------------------------------ getters
  PlayPhase get phase => _phase;
  String? get errorKey => _errorKey;
  bool get playing => _playing;
  bool get buffering => _buffering;
  double get rate => _rate;
  double get volume => _volume;
  Episode? get episode => _episode;
  List<VideoSource> get sources => _sources;
  VideoSource? get source => _src;
  List<SubtitleItem> get subtitles => _subtitles;
  String get subtitleKey => _subtitleKey;
  String get qualityKey => _qualityKey;
  String get audioKey => _audioKey;
  Tracks get tracks => _tracks;
  int get attempt => _attempt;
  int get maxAttempts => _maxAttempts;
  bool get showNextUp => _showNextUp;
  bool get showSkipIntro => _showSkipIntro;
  Episode? get nextEpisode => nextEpisodeOf(episodes, _episode);
  bool get hasAlternativeSource => _sources.any((s) => s.id != _src?.id);
  ({int start, int end})? get intro => introWindow(item, _episode);
  bool get isBusy =>
      _phase == PlayPhase.loadingSources ||
      _phase == PlayPhase.opening ||
      (_buffering && _phase == PlayPhase.ready);

  /// مسارات صوت حقيقية (بدون auto/no).
  List<AudioTrack> get audioTracks =>
      _tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();

  /// ترجمات مدمجة في الملف (بدون المضافة خارجياً).
  List<SubtitleTrack> get embeddedSubtitles {
    final externalLabels = _subtitles.map((s) => s.displayLabel()).toSet();
    return _tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .where((t) => t.title == null || !externalLabels.contains(t.title))
        .toList();
  }

  /// مسارات الفيديو (دقّات) لو كان المصدر تكيّفياً ويكشفها.
  List<VideoTrack> get videoTracks {
    final byHeight = <int, VideoTrack>{};
    for (final t in _tracks.video) {
      if (t.id == 'auto' || t.id == 'no') continue;
      final h = t.h ?? 0;
      if (h <= 0) continue;
      final old = byHeight[h];
      if (old == null || (t.bitrate ?? 0) > (old.bitrate ?? 0)) byHeight[h] = t;
    }
    final list = byHeight.values.toList()..sort((a, b) => (b.h ?? 0).compareTo(a.h ?? 0));
    return list;
  }

  List<QualityChoice> get qualityChoices {
    if (_sources.length > 1) {
      final sorted = [..._sources]
        ..sort((a, b) => (b.qualityHeight ?? 0).compareTo(a.qualityHeight ?? 0));
      return [for (final s in sorted) QualityChoice('src:${s.id}', s.label)];
    }
    final tracks = videoTracks;
    if (tracks.length > 1) {
      return [
        const QualityChoice('auto', 'Auto'),
        for (final t in tracks) QualityChoice('trk:${t.id}', '${t.h}p'),
      ];
    }
    return const [];
  }

  // ------------------------------------------------------------------ init
  void _bind() {
    _subs.addAll([
      player.stream.position.listen(_onPosition),
      player.stream.duration.listen((d) {
        duration.value = d;
        if (d > Duration.zero) {
          final w = _durationWaiter;
          if (w != null && !w.isCompleted) w.complete();
          if (_phase == PlayPhase.opening) _openTimer?.cancel();
        }
      }),
      player.stream.buffer.listen((b) => buffer.value = b),
      player.stream.playing.listen((p) {
        _playing = p;
        _syncSaveTimer();
        _notify();
      }),
      player.stream.buffering.listen((b) {
        _buffering = b;
        _syncStallTimer();
        _notify();
      }),
      player.stream.completed.listen((c) {
        if (c) _onCompleted();
      }),
      player.stream.error.listen(_onError),
      player.stream.rate.listen((r) {
        _rate = r;
        _notify();
      }),
      player.stream.volume.listen((v) {
        _volume = v;
        _notify();
      }),
      player.stream.tracks.listen((t) {
        _tracks = t;
        _notify();
      }),
    ]);
  }

  /// يبدأ التحميل: يجلب الاستئناف والمصادر والترجمات ثم يفتح.
  Future<void> start() => _loadAndOpen();

  Future<void> _loadAndOpen() async {
    if (_disposed) return;
    _setPhase(PlayPhase.loadingSources);
    _errorKey = null;
    try {
      final resumeFuture = _resolveResume();
      final movieId = item.isSeries ? null : item.id;
      final episodeId = _episode?.id;
      final (srcs, subs) = await (
        content.playbackSources(movieId: movieId, episodeId: episodeId),
        content.subtitles(movieId: movieId, episodeId: episodeId).catchError((_) => <SubtitleItem>[]),
      ).wait;
      final resume = await resumeFuture;
      if (_disposed) return;

      if (srcs.isEmpty) {
        _fail('err_no_sources');
        return;
      }
      _sources = srcs;
      _subtitles = subs;
      _failedSources.clear();
      _attempt = 0;
      _subtitleKey = defaultSubtitleKey(subs, defaultSubtitle);
      final first = pickSource(srcs, preferredQuality);
      _qualityKey = _sources.length > 1 ? 'src:${first.id}' : 'auto';
      _lastGoodPosition = Duration(seconds: resume);
      await _open(first, startAt: _lastGoodPosition);
    } catch (e) {
      if (_disposed) return;
      _fail(err.errorKey(e));
    }
  }

  Future<int> _resolveResume() async {
    final id = _episode?.id ?? item.id;
    final local = _localResume[id];
    if (local != null) return local;
    try {
      if (item.isSeries) {
        _seriesProgress ??= await user.seriesProgress(item.id);
        return resumePositionSeconds(_seriesProgress![id]);
      }
      return resumePositionSeconds(await user.movieProgress(item.id));
    } catch (_) {
      return 0;
    }
  }

  // ------------------------------------------------------------------ open
  Future<void> _open(VideoSource s, {Duration startAt = Duration.zero}) async {
    if (_disposed) return;
    final token = ++_openToken;
    _src = s;
    _userPaused = false;
    _errorCheck?.cancel();
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    position.value = startAt;
    duration.value = Duration.zero;
    buffer.value = Duration.zero;
    _setPhase(PlayPhase.opening);

    _openTimer?.cancel();
    _openTimer = Timer(const Duration(seconds: 30), () {
      if (_phase == PlayPhase.opening && token == _openToken) _onFailure();
    });

    final waiter = Completer<void>();
    _durationWaiter = waiter;
    try {
      final resume = startAt.inSeconds > 5 ? startAt : Duration.zero;
      await player.open(Media(s.url), play: resume == Duration.zero);
      if (_disposed || token != _openToken) return;

      await waiter.future.timeout(const Duration(seconds: 10), onTimeout: () {});
      if (_disposed || token != _openToken) return;

      if (resume > Duration.zero && duration.value > Duration.zero) {
        await player.seek(resume);
        if (_disposed || token != _openToken) return;
      }
      if (resume > Duration.zero) {
        await player.play();
        if (_disposed || token != _openToken) return;
      }
      await player.setRate(_rate);
      await _applySubtitleSelection();
    } catch (_) {
      if (!_disposed && token == _openToken) _onFailure();
    }
  }

  Future<void> _applySubtitleSelection() async {
    try {
      if (_subtitleKey.startsWith('ext:')) {
        final id = _subtitleKey.substring(4);
        final s = _subtitles.where((e) => e.id == id).firstOrNull;
        if (s != null) {
          await player.setSubtitleTrack(
            SubtitleTrack.uri(s.url, title: s.displayLabel(), language: s.language),
          );
          return;
        }
      }
      if (_subtitleKey == 'off') {
        await player.setSubtitleTrack(SubtitleTrack.no());
      }
    } catch (_) {
      // فشل تحميل ملف ترجمة لا يوقف الفيديو.
    }
  }

  // ------------------------------------------------------------------ events
  void _onPosition(Duration p) {
    position.value = p;
    if (_phase == PlayPhase.opening && p > Duration.zero) {
      _openTimer?.cancel();
      _setPhase(PlayPhase.ready);
    }
    if (_playing) {
      _lastGoodPosition = p;
      if (_attempt > 0 && p >= _attemptStartPos + const Duration(seconds: 3)) {
        _attempt = 0;
        _failedSources.clear();
      }
    }

    if (!_viewLogged && _playing && p.inSeconds >= 10) {
      _viewLogged = true;
      unawaited(content
          .logView(kind: item.kind, titleId: item.id, episodeId: _episode?.id)
          .catchError((_) {}));
    }

    final dur = duration.value;
    final next = nextEpisode;
    if (next != null && autoplayNext && !_nextDismissed && dur.inSeconds > 90) {
      final remaining = (dur - p).inSeconds;
      final show = remaining <= 20 && remaining >= 0;
      if (show != _showNextUp) {
        _showNextUp = show;
        _notify();
      }
    }

    final w = intro;
    final skip = w != null && p.inSeconds >= w.start && p.inSeconds < w.end - 1;
    if (skip != _showSkipIntro) {
      _showSkipIntro = skip;
      _notify();
    }
  }

  void _onCompleted() {
    if (_disposed) return;
    final genuine = isGenuineEnd(position.value, duration.value);
    if (!genuine && duration.value > Duration.zero) {
      // انتهى الملف مبكراً (غالباً انقطاع شبكة) فنعامله كفشل لا كنهاية.
      _onFailure();
      return;
    }
    unawaited(saveProgress(completed: true));
    final next = nextEpisode;
    if (next != null && autoplayNext && !_nextDismissed) {
      unawaited(loadEpisode(next));
      return;
    }
    _setPhase(PlayPhase.ended);
  }

  void _onError(String message) {
    if (_disposed || message.isEmpty) return;
    _errorCheck?.cancel();
    _errorCheck = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      final alive = _playing ||
          _buffering ||
          _userPaused ||
          (_phase == PlayPhase.opening && duration.value > Duration.zero);
      final settled = _phase == PlayPhase.ended ||
          _phase == PlayPhase.error ||
          _phase == PlayPhase.waitingNetwork ||
          _phase == PlayPhase.reconnecting ||
          _phase == PlayPhase.loadingSources;
      if (!alive && !settled) _onFailure();
    });
  }

  void _syncStallTimer() {
    _stallTimer?.cancel();
    if (_buffering && !_userPaused && (_phase == PlayPhase.ready || _phase == PlayPhase.opening)) {
      final token = _openToken;
      _stallTimer = Timer(const Duration(seconds: 25), () {
        if (_buffering && token == _openToken) _onFailure();
      });
    }
  }

  void _syncSaveTimer() {
    if (_playing) {
      _saveTimer ??= Timer.periodic(const Duration(seconds: 15), (_) => unawaited(saveProgress()));
    } else {
      _saveTimer?.cancel();
      _saveTimer = null;
    }
  }

  // ------------------------------------------------------------------ failure / reconnect
  void _onFailure() {
    final s = _src;
    if (_disposed || s == null) return;
    _stallTimer?.cancel();
    _openTimer?.cancel();
    _retryTimer?.cancel();
    _openToken++; // يُبطل أي فتح جارٍ

    if (!isOnline()) {
      _setPhase(PlayPhase.waitingNetwork);
      return;
    }

    _attempt++;
    _attemptStartPos = _lastGoodPosition;
    if (_attempt > _maxAttempts) {
      _failedSources.add(s.id);
      final alt = _untriedSource();
      if (alt != null) {
        _attempt = 1;
        _setPhase(PlayPhase.reconnecting);
        _retryTimer = Timer(const Duration(seconds: 1), () => unawaited(_switchTo(alt)));
        return;
      }
      _fail('err_playback');
      return;
    }
    _setPhase(PlayPhase.reconnecting);
    _retryTimer = Timer(
      Duration(seconds: 2 * _attempt),
      () => unawaited(_open(s, startAt: _lastGoodPosition)),
    );
  }

  VideoSource? _untriedSource() {
    final sorted = [..._sources]
      ..sort((a, b) => (b.qualityHeight ?? 0).compareTo(a.qualityHeight ?? 0));
    return sorted.where((s) => !_failedSources.contains(s.id)).firstOrNull;
  }

  Future<void> _switchTo(VideoSource s) async {
    _qualityKey = _sources.length > 1 ? 'src:${s.id}' : _qualityKey;
    await _open(s, startAt: _lastGoodPosition);
  }

  void _fail(String key) {
    _errorKey = key;
    _setPhase(PlayPhase.error);
  }

  /// يُستدعى عند تغيّر الاتصال.
  void onConnectivity(bool online) {
    if (_disposed) return;
    if (online && _phase == PlayPhase.waitingNetwork) {
      final s = _src;
      if (s != null) unawaited(_open(s, startAt: _lastGoodPosition));
    }
  }

  /// إعادة محاولة يدوية من شاشة الخطأ.
  Future<void> retry() async {
    _attempt = 0;
    _failedSources.clear();
    final s = _src;
    if (s == null || _sources.isEmpty) {
      await _loadAndOpen();
    } else {
      await _open(s, startAt: _lastGoodPosition);
    }
  }

  /// جرّب مصدراً آخر يدوياً.
  Future<void> tryAnotherSource() async {
    if (_sources.length < 2) return;
    _failedSources.add(_src?.id ?? '');
    final alt = _untriedSource() ?? _sources.firstWhere((s) => s.id != _src?.id);
    _attempt = 0;
    await _switchTo(alt);
  }

  // ------------------------------------------------------------------ user actions
  Future<void> togglePlay() async {
    if (_phase == PlayPhase.ended) {
      await replay();
      return;
    }
    if (_playing) {
      _userPaused = true;
      await player.pause();
      unawaited(saveProgress());
    } else {
      _userPaused = false;
      await player.play();
    }
  }

  Future<void> pause() async {
    if (!_playing) return;
    _userPaused = true;
    await player.pause();
    unawaited(saveProgress());
  }

  Future<void> replay() async {
    _nextDismissed = true;
    _showNextUp = false;
    _lastGoodPosition = Duration.zero;
    final s = _src;
    if (s != null) await _open(s);
  }

  Future<void> seekTo(Duration target) async {
    final dur = duration.value;
    var t = target;
    if (t < Duration.zero) t = Duration.zero;
    if (dur > Duration.zero && t > dur) t = dur;
    position.value = t;
    _lastGoodPosition = t;
    await player.seek(t);
  }

  Future<void> seekBy(Duration delta) => seekTo(position.value + delta);

  Future<void> skipIntro() async {
    final w = intro;
    if (w == null) return;
    await seekTo(Duration(seconds: w.end));
  }

  void dismissNextUp() {
    _nextDismissed = true;
    _showNextUp = false;
    _notify();
  }

  Future<void> playNext() async {
    final next = nextEpisode;
    if (next != null) await loadEpisode(next);
  }

  Future<void> setRate(double r) async {
    _rate = r;
    _notify();
    await player.setRate(r);
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0, 100).toDouble();
    _notify();
    await player.setVolume(_volume);
  }

  /// يغيّر المصدر/الدقة (يحافظ على الموضع).
  Future<void> selectQuality(String key) async {
    if (key.startsWith('src:')) {
      final id = key.substring(4);
      final s = _sources.where((e) => e.id == id).firstOrNull;
      if (s == null || s.id == _src?.id) return;
      _qualityKey = key;
      _attempt = 0;
      _failedSources.clear();
      await _open(s, startAt: position.value > Duration.zero ? position.value : _lastGoodPosition);
    } else if (key == 'auto') {
      _qualityKey = key;
      _notify();
      await player.setVideoTrack(VideoTrack.auto());
    } else if (key.startsWith('trk:')) {
      final id = key.substring(4);
      final t = _tracks.video.where((e) => e.id == id).firstOrNull;
      if (t == null) return;
      _qualityKey = key;
      _notify();
      await player.setVideoTrack(t);
    }
  }

  Future<void> selectSubtitle(String key) async {
    _subtitleKey = key;
    _notify();
    try {
      if (key == 'off') {
        await player.setSubtitleTrack(SubtitleTrack.no());
      } else if (key.startsWith('ext:')) {
        await _applySubtitleSelection();
      } else if (key.startsWith('emb:')) {
        final id = key.substring(4);
        final t = _tracks.subtitle.where((e) => e.id == id).firstOrNull;
        if (t != null) await player.setSubtitleTrack(t);
      }
    } catch (_) {}
  }

  Future<void> selectAudio(String id) async {
    final t = _tracks.audio.where((e) => e.id == id).firstOrNull;
    if (t == null) return;
    _audioKey = id;
    _notify();
    await player.setAudioTrack(t);
  }

  /// الانتقال لحلقة أخرى.
  Future<void> loadEpisode(Episode ep) async {
    if (_disposed || ep.id == _episode?.id) return;
    final prev = _episode;
    await saveProgress();
    if (prev != null && position.value.inSeconds > 0) {
      _localResume[prev.id] = position.value.inSeconds;
    }
    _episode = ep;
    _lastSavedPos = -1;
    _viewLogged = false;
    _nextDismissed = false;
    _showNextUp = false;
    _showSkipIntro = false;
    _lastGoodPosition = Duration.zero;
    _src = null;
    _sources = const [];
    _subtitles = const [];
    await _loadAndOpen();
  }

  // ------------------------------------------------------------------ progress
  Future<void> saveProgress({bool completed = false}) async {
    final dur = duration.value.inSeconds;
    var pos = position.value.inSeconds;
    if (dur <= 0) return;
    if (completed) pos = dur;
    if (!completed && (pos < 5 || pos == _lastSavedPos)) return;
    _lastSavedPos = pos;
    final ep = _episode;
    if (ep != null) _localResume[ep.id] = completed ? 0 : pos;
    try {
      await user.saveProgress(
        item: item,
        episode: ep,
        positionSeconds: pos,
        durationSeconds: dur,
      );
    } catch (_) {
      // الحفظ يعاد في الدورة التالية؛ لا نزعج المستخدم.
    }
  }

  /// حفظ قبل الخروج مع مهلة كي لا نعلّق المستخدم على شبكة سيئة.
  Future<void> saveBeforeExit() async {
    await saveProgress().timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  // ------------------------------------------------------------------ helpers
  void _setPhase(PlayPhase p) {
    if (_phase == p) return;
    _phase = p;
    _syncStallTimer();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _openToken++;
    for (final t in [_stallTimer, _openTimer, _retryTimer, _errorCheck, _saveTimer]) {
      t?.cancel();
    }
    for (final s in _subs) {
      s.cancel();
    }
    // التقاط القيم الآن قبل التخلص من المُخطِرات.
    final save = saveProgress();
    unawaited(save.whenComplete(() {
      position.dispose();
      duration.dispose();
      buffer.dispose();
    }));
    unawaited(player.dispose());
    super.dispose();
  }
}

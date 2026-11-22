import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import 'playback_controller.dart';
import 'playback_logic.dart';
import 'player_widgets.dart';

/// المشغّل الداخلي (media_kit/libmpv): MP4 و HLS(M3U8) و DASH، ترجمات SRT/VTT، استئناف، حلقة تالية.
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, required this.args});

  final PlayerArgs args;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> with WidgetsBindingObserver {
  late final PlaybackController _c;
  final GlobalKey _playerKey = GlobalKey();

  bool _fullscreen = true;
  bool _controlsVisible = true;
  bool _sheetOpen = false;
  bool _exiting = false;
  bool _dragOnRight = false;
  BoxFit _fit = BoxFit.contain;
  Offset _tapPos = Offset.zero;
  (IconData, String)? _hud;
  Timer? _hideTimer;
  Timer? _hudTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = ref.read(settingsProvider);
    final a = widget.args;
    _c = PlaybackController(
      content: ref.read(contentRepoProvider),
      user: ref.read(userRepoProvider),
      item: a.item,
      episode: a.episode,
      episodes: a.episodes,
      isOnline: () => ref.read(connectivityProvider).valueOrNull ?? true,
      preferredQuality: settings.quality,
      defaultSubtitle: settings.subtitle,
      autoplayNext: settings.autoplayNext,
    );
    _c.addListener(_onControllerChanged);
    ref.listenManual<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      final online = next.valueOrNull;
      if (online != null) _c.onConnectivity(online);
    });
    unawaited(_applyOrientation());
    unawaited(_c.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    unawaited(SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_c.pause());
  }

  // ------------------------------------------------------------------ helpers
  Future<void> _applyOrientation() async {
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_c.playing && _controlsVisible && !(_hideTimer?.isActive ?? false)) _scheduleHide();
    if (!_c.playing && !_controlsVisible) setState(() => _controlsVisible = true);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_controlsVisible) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _sheetOpen) return;
      if (_c.playing) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _flashHud(IconData icon, String text) {
    _hudTimer?.cancel();
    setState(() => _hud = (icon, text));
    _hudTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _hud = null);
    });
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    _showControls();
    await _applyOrientation();
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    await _c.saveBeforeExit();
    if (mounted) Navigator.of(context).pop();
  }

  Future<T?> _withSheet<T>(Future<T?> Function() show) async {
    _sheetOpen = true;
    _hideTimer?.cancel();
    try {
      return await show();
    } finally {
      _sheetOpen = false;
      if (mounted) _showControls();
    }
  }

  // ------------------------------------------------------------------ gestures
  void _onDoubleTap(double width) {
    final back = _tapPos.dx < width / 2;
    unawaited(_c.seekBy(Duration(seconds: back ? -10 : 10)));
    _flashHud(back ? Icons.replay_10_rounded : Icons.forward_10_rounded, back ? '-10' : '+10');
  }

  void _onVolumeDrag(double dy, double height) {
    if (!_dragOnRight) return;
    final next = (_c.volume - dy / (height * 0.55) * 100).clamp(0.0, 100.0).toDouble();
    unawaited(_c.setVolume(next));
    _flashHud(
      next <= 0 ? Icons.volume_off_rounded : (next < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
      '${next.round()}%',
    );
  }

  // ------------------------------------------------------------------ sheets
  Future<void> _openSubtitles() async {
    final embedded = _c.embeddedSubtitles;
    final options = <ChoiceOption<String>>[
      ChoiceOption('off', context.tr('subtitle_off')),
      for (final s in _c.subtitles) ChoiceOption('ext:${s.id}', s.displayLabel()),
      for (final t in embedded)
        ChoiceOption('emb:${t.id}', t.title ?? t.language ?? '${context.tr('subtitles')} ${t.id}'),
    ];
    if (options.length == 1) {
      showAppSnack(context, context.tr('no_subtitles'));
      return;
    }
    final v = await _withSheet(() => showChoiceSheet<String>(
          context,
          title: context.tr('subtitles'),
          options: options,
          selected: _c.subtitleKey,
        ));
    if (v != null) await _c.selectSubtitle(v);
  }

  Future<void> _openQuality() async {
    final choices = _c.qualityChoices;
    if (choices.isEmpty) return;
    final v = await _withSheet(() => showChoiceSheet<String>(
          context,
          title: context.tr('video_quality'),
          options: [for (final q in choices) ChoiceOption(q.key, q.label, subtitle: q.subtitle)],
          selected: _c.qualityKey,
        ));
    if (v != null) await _c.selectQuality(v);
  }

  Future<void> _openSpeed() async {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final v = await _withSheet(() => showChoiceSheet<double>(
          context,
          title: context.tr('playback_speed'),
          options: [for (final s in speeds) ChoiceOption(s, s == 1.0 ? '1x (${context.tr('normal')})' : '${s}x')],
          selected: speeds.contains(_c.rate) ? _c.rate : null,
        ));
    if (v != null) await _c.setRate(v);
  }

  Future<void> _openAudio() async {
    final tracks = _c.audioTracks;
    if (tracks.length < 2) return;
    final v = await _withSheet(() => showChoiceSheet<String>(
          context,
          title: context.tr('audio_track'),
          options: [
            for (final t in tracks)
              ChoiceOption(t.id, t.title ?? t.language ?? '${context.tr('audio_track')} ${t.id}'),
          ],
          selected: _c.audioKey,
        ));
    if (v != null) await _c.selectAudio(v);
  }

  Future<void> _openEpisodes() async {
    final ar = context.isAr;
    final v = await _withSheet(() => showChoiceSheet<String>(
          context,
          title: context.tr('episodes'),
          options: [
            for (final e in _c.episodes)
              ChoiceOption(e.id, '${episodeTag(e)}  ${e.displayTitle(ar)}'),
          ],
          selected: _c.episode?.id,
        ));
    if (v == null) return;
    final ep = _c.episodes.where((e) => e.id == v).firstOrNull;
    if (ep != null) await _c.loadEpisode(ep);
  }

  void _toggleFit() {
    setState(() => _fit = _fit == BoxFit.contain ? BoxFit.cover : BoxFit.contain);
    _flashHud(Icons.aspect_ratio_rounded, _fit == BoxFit.cover ? context.tr('fit_cover') : context.tr('fit_contain'));
    _showControls();
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final player = _buildPlayerArea(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        backgroundColor: _fullscreen ? Colors.black : AppColors.background,
        body: _fullscreen
            ? player
            : Column(
                children: [
                  SafeArea(bottom: false, child: AspectRatio(aspectRatio: 16 / 9, child: player)),
                  Expanded(child: _InlineInfo(controller: _c)),
                ],
              ),
      ),
    );
  }

  Widget _buildPlayerArea(BuildContext context) {
    return Container(
      key: _playerKey,
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = (box.maxWidth / 1100).clamp(0.5, 0.7).toDouble();
          return Stack(
            fit: StackFit.expand,
            children: [
              Video(
                controller: _c.video,
                controls: NoVideoControls,
                fit: _fit,
                fill: Colors.black,
                subtitleViewConfiguration: SubtitleViewConfiguration(
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.35,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    backgroundColor: Color(0x99000000),
                  ),
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.linear(scale),
                  padding: EdgeInsets.fromLTRB(24, 0, 24, _controlsVisible ? 92 : 24),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  onDoubleTapDown: (d) => _tapPos = d.localPosition,
                  onDoubleTap: () => _onDoubleTap(box.maxWidth),
                  onVerticalDragStart: (d) => _dragOnRight = d.localPosition.dx > box.maxWidth / 2,
                  onVerticalDragUpdate: (d) => _onVolumeDrag(d.delta.dy, box.maxHeight),
                ),
              ),
              Positioned.fill(
                child: PlayerControlsOverlay(
                  controller: _c,
                  visible: _controlsVisible,
                  fullscreen: _fullscreen,
                  onBack: () => unawaited(_exit()),
                  onToggleFullscreen: () => unawaited(_toggleFullscreen()),
                  onSubtitles: () => unawaited(_openSubtitles()),
                  onQuality: () => unawaited(_openQuality()),
                  onSpeed: () => unawaited(_openSpeed()),
                  onEpisodes: () => unawaited(_openEpisodes()),
                  onAudio: () => unawaited(_openAudio()),
                  onToggleFit: _toggleFit,
                  onInteraction: _showControls,
                ),
              ),
              Positioned.fill(
                child: PlayerStatusOverlay(controller: _c, onBack: () => unawaited(_exit())),
              ),
              ListenableBuilder(
                listenable: _c,
                builder: (context, _) {
                  final items = <Widget>[];
                  if (_c.showSkipIntro && _c.phase == PlayPhase.ready) {
                    items.add(PositionedDirectional(
                      end: 20,
                      bottom: _controlsVisible ? 104 : 28,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => unawaited(_c.skipIntro()),
                        icon: const Icon(Icons.fast_forward_rounded, size: 20),
                        label: Text(context.tr('skip_intro'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ));
                  }
                  if (_c.showNextUp && _c.phase == PlayPhase.ready) {
                    items.add(PositionedDirectional(
                      start: 20,
                      bottom: _controlsVisible ? 104 : 28,
                      child: NextUpCard(controller: _c),
                    ));
                  }
                  return Stack(fit: StackFit.expand, children: items);
                },
              ),
              if (_hud != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: PlayerHud(icon: _hud!.$1, text: _hud!.$2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// معلومات تحت المشغّل في الوضع العمودي: العنوان، القصة، قائمة الحلقات.
class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final ep = c.episode;
        final overview = ep?.overview(ar) ?? c.item.overview(ar);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Text(c.item.title(ar), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (ep != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${episodeTag(ep)}  ${ep.displayTitle(ar)}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            if (overview != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(overview, style: const TextStyle(color: AppColors.textDim, height: 1.6)),
              ),
            if (c.episodes.length > 1) ...[
              const SizedBox(height: 18),
              Text(context.tr('episodes'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final e in c.episodes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: e.id == ep?.id,
                  selectedColor: AppColors.primary,
                  leading: SizedBox(
                    width: 52,
                    child: Text(episodeTag(e), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                  title: Text(e.displayTitle(ar), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: e.runtimeMinutes == null
                      ? null
                      : Text(fmtRuntime(e.runtimeMinutes, ar), style: const TextStyle(fontSize: 12)),
                  trailing: e.id == ep?.id ? const Icon(Icons.play_arrow_rounded) : null,
                  onTap: () => c.loadEpisode(e),
                ),
            ],
          ],
        );
      },
    );
  }
}

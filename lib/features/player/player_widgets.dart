import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'playback_controller.dart';
import 'playback_logic.dart';

/// شريط التقدّم: الموضع الحالي + المخزَّن مؤقتاً + السحب. دائماً LTR حتى في الواجهة العربية.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.onSeek,
    this.onInteraction,
  });

  final ValueListenable<Duration> position;
  final ValueListenable<Duration> duration;
  final ValueListenable<Duration> buffer;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onInteraction;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.position, widget.duration, widget.buffer]),
        builder: (context, _) {
          final dur = widget.duration.value;
          final maxMs = dur.inMilliseconds.toDouble();
          final enabled = maxMs > 0;
          final max = enabled ? maxMs : 1.0;
          final posMs = _drag ?? widget.position.value.inMilliseconds.toDouble();
          final value = posMs.clamp(0.0, max).toDouble();
          final buf = widget.buffer.value.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
          const style = TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600);

          return Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(fmtClock(Duration(milliseconds: value.round())), style: style),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    secondaryActiveTrackColor: Colors.white38,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: max,
                    secondaryTrackValue: buf < value ? value : buf,
                    onChangeStart: (_) => widget.onInteraction?.call(),
                    onChanged: enabled
                        ? (v) {
                            setState(() => _drag = v);
                            widget.onInteraction?.call();
                          }
                        : null,
                    onChangeEnd: (v) {
                      setState(() => _drag = null);
                      widget.onSeek(Duration(milliseconds: v.round()));
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(fmtClock(dur), textAlign: TextAlign.end, style: style),
              ),
            ],
          );
        },
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 28,
    this.tooltip,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: size,
      color: color,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon),
    );
  }
}

/// طبقة أزرار التحكم (أعلى/وسط/أسفل).
class PlayerControlsOverlay extends StatelessWidget {
  const PlayerControlsOverlay({
    super.key,
    required this.controller,
    required this.visible,
    required this.fullscreen,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.onSubtitles,
    required this.onQuality,
    required this.onSpeed,
    required this.onEpisodes,
    required this.onAudio,
    required this.onToggleFit,
    required this.onInteraction,
  });

  final PlaybackController controller;
  final bool visible;
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onSubtitles;
  final VoidCallback onQuality;
  final VoidCallback onSpeed;
  final VoidCallback onEpisodes;
  final VoidCallback onAudio;
  final VoidCallback onToggleFit;
  final VoidCallback onInteraction;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final c = controller;
    final ar = context.isAr;
    final compact = !fullscreen;
    final ep = c.episode;
    final title = c.item.title(ar);
    final subtitle = ep == null ? null : '${episodeTag(ep)}  ${ep.displayTitle(ar)}';
    final canControl = c.phase == PlayPhase.ready || c.phase == PlayPhase.ended || c.phase == PlayPhase.opening;
    final qualityAvailable = c.qualityChoices.isNotEmpty;
    final hasEpisodes = c.episodes.length > 1;
    final audioAvailable = c.audioTracks.length > 1;
    final iconSize = compact ? 22.0 : 26.0;

    final top = Padding(
      padding: EdgeInsets.fromLTRB(4, compact ? 4 : 8, 8, 0),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack, size: iconSize + 2),
          if (!compact)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                ],
              ),
            )
          else
            const Spacer(),
          RoundIconButton(icon: Icons.aspect_ratio_rounded, onTap: onToggleFit, size: iconSize - 2, tooltip: context.tr('player_fit')),
        ],
      ),
    );

    final center = Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundIconButton(
            icon: Icons.replay_10_rounded,
            size: compact ? 34 : 42,
            onTap: canControl ? () { onInteraction(); c.seekBy(const Duration(seconds: -10)); } : null,
          ),
          SizedBox(width: compact ? 16 : 30),
          Material(
            color: Colors.black38,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: canControl ? () { onInteraction(); c.togglePlay(); } : null,
              child: Padding(
                padding: EdgeInsets.all(compact ? 10 : 14),
                child: c.isBusy
                    ? SizedBox(
                        width: compact ? 34 : 44,
                        height: compact ? 34 : 44,
                        child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : Icon(
                        c.phase == PlayPhase.ended
                            ? Icons.replay_rounded
                            : (c.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        size: compact ? 34 : 44,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
          SizedBox(width: compact ? 16 : 30),
          RoundIconButton(
            icon: Icons.forward_10_rounded,
            size: compact ? 34 : 42,
            onTap: canControl ? () { onInteraction(); c.seekBy(const Duration(seconds: 10)); } : null,
          ),
        ],
      ),
    );

    final bottom = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerSeekBar(
            position: c.position,
            duration: c.duration,
            buffer: c.buffer,
            onInteraction: onInteraction,
            onSeek: (d) => c.seekTo(d),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton(
                  onPressed: onSpeed,
                  style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(48, 40)),
                  child: Text('${c.rate == c.rate.roundToDouble() ? c.rate.toStringAsFixed(0) : c.rate}x', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                RoundIconButton(icon: Icons.subtitles_outlined, onTap: onSubtitles, size: iconSize, tooltip: context.tr('subtitles')),
                if (qualityAvailable)
                  RoundIconButton(icon: Icons.high_quality_outlined, onTap: onQuality, size: iconSize, tooltip: context.tr('video_quality')),
                if (audioAvailable)
                  RoundIconButton(icon: Icons.audiotrack_outlined, onTap: onAudio, size: iconSize, tooltip: context.tr('audio_track')),
                if (hasEpisodes)
                  RoundIconButton(icon: Icons.video_library_outlined, onTap: onEpisodes, size: iconSize, tooltip: context.tr('episodes')),
                if (c.nextEpisode != null)
                  RoundIconButton(
                    icon: Icons.skip_next_rounded,
                    onTap: () { onInteraction(); c.playNext(); },
                    size: iconSize + 2,
                    tooltip: context.tr('next_episode'),
                  ),
                RoundIconButton(
                  icon: fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  onTap: onToggleFullscreen,
                  size: iconSize + 2,
                  tooltip: context.tr(fullscreen ? 'exit_fullscreen' : 'fullscreen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final content = Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 110,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 150,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: top),
        Center(child: center),
        Positioned(bottom: 0, left: 0, right: 0, child: bottom),
      ],
    );

    return fullscreen ? SafeArea(child: content) : content;
  }
}

/// حالات: تحميل/إعادة اتصال/انتظار الشبكة/خطأ/انتهاء.
class PlayerStatusOverlay extends StatelessWidget {
  const PlayerStatusOverlay({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final PlaybackController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        switch (c.phase) {
          case PlayPhase.loadingSources:
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          case PlayPhase.reconnecting:
            return _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.trf('reconnecting', {'n': c.attempt.clamp(1, c.maxAttempts), 'max': c.maxAttempts}),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          case PlayPhase.waitingNetwork:
            return _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 34, color: AppColors.textDim),
                  const SizedBox(height: 10),
                  Text(context.tr('waiting_network'), textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 12),
                  _PanelButton(label: context.tr('retry'), onTap: c.retry),
                ],
              ),
            );
          case PlayPhase.error:
            return _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.danger),
                  const SizedBox(height: 10),
                  Text(context.tr(c.errorKey ?? 'err_playback'), textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _PanelButton(label: context.tr('retry'), onTap: c.retry, primary: true),
                      if (c.hasAlternativeSource) _PanelButton(label: context.tr('try_another_source'), onTap: c.tryAnotherSource),
                      _PanelButton(label: context.tr('back'), onTap: onBack),
                    ],
                  ),
                ],
              ),
            );
          case PlayPhase.ended:
            return _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 36, color: AppColors.success),
                  const SizedBox(height: 10),
                  Text(context.tr('ended_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    children: [
                      _PanelButton(label: context.tr('replay'), onTap: c.replay, primary: true),
                      _PanelButton(label: context.tr('back'), onTap: onBack),
                    ],
                  ),
                ],
              ),
            );
          case PlayPhase.opening:
          case PlayPhase.ready:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xE6101015),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return primary
        ? FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: onTap,
            child: Text(label),
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: AppColors.divider)),
            onPressed: onTap,
            child: Text(label),
          );
  }
}

/// بطاقة "الحلقة التالية".
class NextUpCard extends StatelessWidget {
  const NextUpCard({super.key, required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final next = c.nextEpisode;
    if (next == null) return const SizedBox.shrink();
    final ar = context.isAr;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE15151C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<Duration>(
            valueListenable: c.position,
            builder: (context, pos, _) {
              final remaining = (c.duration.value - pos).inSeconds.clamp(0, 99);
              return Text(
                context.trf('next_in', {'n': remaining}),
                style: const TextStyle(fontSize: 12, color: AppColors.textDim),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            '${episodeTag(next)}  ${next.displayTitle(ar)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: c.playNext,
                  child: Text(context.tr('play_now')),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                onPressed: c.dismissNextUp,
                child: Text(context.tr('cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// نص تغذية راجعة قصير (مثل +10 ث أو مستوى الصوت).
class PlayerHud extends StatelessWidget {
  const PlayerHud({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.white),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

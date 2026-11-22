import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/ui.dart';
import '../../providers/providers.dart';

/// إعدادات التطبيق: اللغة، جودة الفيديو، الترجمة الافتراضية، التشغيل التلقائي.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _qualityLabel(BuildContext context, String q) =>
      q == 'auto' ? context.tr('quality_auto') : '${q}p';

  String _subtitleLabel(BuildContext context, String s) {
    switch (s) {
      case 'ar':
        return context.tr('lang_arabic');
      case 'en':
        return context.tr('lang_english');
      default:
        return context.tr('subtitle_off');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Section(context.tr('settings_general')),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(context.tr('app_language')),
            subtitle: Text(locale.languageCode == 'ar' ? context.tr('lang_arabic') : context.tr('lang_english'),
                style: const TextStyle(color: AppColors.textDim)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
            onTap: () async {
              final v = await showChoiceSheet<String>(
                context,
                title: context.tr('app_language'),
                selected: locale.languageCode,
                options: [
                  ChoiceOption('ar', context.tr('lang_arabic')),
                  ChoiceOption('en', context.tr('lang_english')),
                ],
              );
              if (v != null) await ref.read(localeProvider.notifier).set(v);
            },
          ),
          const Divider(height: 24, color: AppColors.divider),
          _Section(context.tr('settings_playback')),
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: Text(context.tr('video_quality')),
            subtitle: Text(_qualityLabel(context, settings.quality), style: const TextStyle(color: AppColors.textDim)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
            onTap: () async {
              final v = await showChoiceSheet<String>(
                context,
                title: context.tr('video_quality'),
                selected: settings.quality,
                options: [
                  for (final q in const ['auto', '1080', '720', '480', '360'])
                    ChoiceOption(q, _qualityLabel(context, q),
                        subtitle: q == 'auto' ? context.tr('quality_auto_hint') : null),
                ],
              );
              if (v != null) await ctrl.update(quality: v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.subtitles_outlined),
            title: Text(context.tr('default_subtitle')),
            subtitle: Text(_subtitleLabel(context, settings.subtitle), style: const TextStyle(color: AppColors.textDim)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
            onTap: () async {
              final v = await showChoiceSheet<String>(
                context,
                title: context.tr('default_subtitle'),
                selected: settings.subtitle,
                options: [
                  for (final s in const ['off', 'ar', 'en']) ChoiceOption(s, _subtitleLabel(context, s)),
                ],
              );
              if (v != null) await ctrl.update(subtitle: v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.skip_next_rounded),
            title: Text(context.tr('autoplay_next')),
            subtitle: Text(context.tr('autoplay_next_hint'), style: const TextStyle(color: AppColors.textDim)),
            value: settings.autoplayNext,
            onChanged: (v) => ctrl.update(autoplayNext: v),
          ),
          const Divider(height: 24, color: AppColors.divider),
          _Section(context.tr('settings_data')),
          ListTile(
            leading: const Icon(Icons.manage_search_rounded),
            title: Text(context.tr('clear_search_history')),
            onTap: () async {
              final ok = await confirmDialog(
                context,
                title: context.tr('clear_search_history'),
                message: context.tr('clear_search_history_confirm'),
                danger: true,
              );
              if (!ok) return;
              await ref.read(searchHistoryProvider.notifier).clear();
              if (context.mounted) showAppSnack(context, context.tr('done'));
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/ui.dart';
import '../../data/models/json_helpers.dart';
import 'admin_repository.dart';

enum _Phase { idle, running, done, failed }

class _Job {
  _Job(this.slug, this.labelKey, this.icon);

  final String slug;
  final String labelKey;
  final IconData icon;
  _Phase phase = _Phase.idle;
  int count = 0;
  String? error;
}

/// استيراد بوسترات وتفاصيل من TMDB إلى صفوف الصفحة الرئيسية.
/// يعمل عبر دالة خادم (Edge Function) للمسؤول فقط؛ مفتاح TMDB لا يدخل التطبيق.
class AdminTmdbImportPage extends ConsumerStatefulWidget {
  const AdminTmdbImportPage({super.key});

  @override
  ConsumerState<AdminTmdbImportPage> createState() => _AdminTmdbImportPageState();
}

class _AdminTmdbImportPageState extends ConsumerState<AdminTmdbImportPage> {
  final _jobs = <_Job>[
    _Job('action-movies', 'tmdb_c_action', Icons.local_fire_department_outlined),
    _Job('horror-movies', 'tmdb_c_horror', Icons.nights_stay_outlined),
    _Job('scifi-movies', 'tmdb_c_scifi', Icons.rocket_launch_outlined),
    _Job('comedy-movies', 'tmdb_c_comedy', Icons.sentiment_very_satisfied_outlined),
    _Job('arabic-movies', 'tmdb_c_ar_movies', Icons.movie_outlined),
    _Job('foreign-movies', 'tmdb_c_for_movies', Icons.public_rounded),
    _Job('arabic-series', 'tmdb_c_ar_series', Icons.tv_rounded),
    _Job('foreign-series', 'tmdb_c_for_series', Icons.live_tv_rounded),
    _Job('anime', 'tmdb_c_anime', Icons.animation_rounded),
  ];
  bool _busy = false;

  String _message(Object e) {
    if (e is FunctionException) {
      final d = e.details;
      final code = d is Map ? d['error']?.toString() : null;
      if (code == 'tmdb_key_missing') return context.tr('admin_tmdb_key_missing');
      if (e.status == 401 || e.status == 403) return context.tr('err_forbidden');
      return '${context.tr('admin_tmdb_failed')} (${e.status}${code != null ? ': $code' : ''})';
    }
    return friendlyError(context, e);
  }

  /// يعيد true عند النجاح.
  Future<bool> _run(_Job job) async {
    setState(() {
      job.phase = _Phase.running;
      job.error = null;
    });
    try {
      final r = await ref.read(adminRepoProvider).importTmdb(job.slug);
      if (!mounted) return false;
      setState(() {
        job.count = (jInt(r['movies']) ?? 0) + (jInt(r['series']) ?? 0);
        job.phase = _Phase.done;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        job.phase = _Phase.failed;
        job.error = _message(e);
      });
      return false;
    }
  }

  Future<void> _runOne(_Job job) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _run(job);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _runAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    var allOk = true;
    for (final job in _jobs) {
      if (!mounted) return;
      final ok = await _run(job);
      if (!ok) {
        allOk = false;
        break; // لا فائدة من المتابعة إذا فشل (مفتاح مفقود أو لا صلاحية)
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (allOk) showAppSnack(context, context.tr('admin_tmdb_all_done'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('admin_tmdb'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('admin_tmdb_intro'),
                    style: const TextStyle(color: AppColors.textDim, height: 1.6, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _busy ? null : _runAll,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(context.tr('admin_tmdb_all')),
          ),
          const SizedBox(height: 14),
          for (final job in _jobs) _JobTile(job: job, busy: _busy, onRun: () => _runOne(job)),
          const SizedBox(height: 8),
          Text(
            context.tr('about_tmdb_body'),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: AppColors.textDim, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.busy, required this.onRun});

  final _Job job;
  final bool busy;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    String? subtitle;
    Color subtitleColor = AppColors.textDim;
    Widget trailing;
    switch (job.phase) {
      case _Phase.idle:
        trailing = IconButton(
          icon: const Icon(Icons.download_rounded),
          onPressed: busy ? null : onRun,
        );
      case _Phase.running:
        subtitle = context.tr('admin_tmdb_running');
        trailing = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary),
        );
      case _Phase.done:
        subtitle = context.trf('admin_tmdb_items', {'n': job.count});
        trailing = IconButton(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
          onPressed: busy ? null : onRun,
        );
      case _Phase.failed:
        subtitle = job.error;
        subtitleColor = AppColors.danger;
        trailing = IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.danger),
          onPressed: busy ? null : onRun,
        );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(job.icon, color: AppColors.primary),
        title: Text(context.tr(job.labelKey), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12.5)),
        trailing: trailing,
      ),
    );
  }
}

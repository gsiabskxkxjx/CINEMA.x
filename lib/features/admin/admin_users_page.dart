import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/json_helpers.dart';
import '../../providers/providers.dart';
import '../account/account_page.dart';
import 'admin_repository.dart';
import 'admin_widgets.dart';

class _UsersQuery {
  const _UsersQuery(this.text, this.limit);
  final String text;
  final int limit;

  @override
  bool operator ==(Object other) => other is _UsersQuery && other.text == text && other.limit == limit;

  @override
  int get hashCode => Object.hash(text, limit);
}

final _adminUsersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _UsersQuery>(
  (ref, q) => ref.watch(adminRepoProvider).users(query: q.text, limit: q.limit),
);

/// إدارة المستخدمين: بحث، ترقية/إلغاء مسؤول، حظر/إلغاء حظر.
/// تغيير role/is_blocked يُسمح به على الخادم للمسؤول فقط (مشغّل protect_profile_fields).
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  static const int _step = 40;
  final _search = TextEditingController();
  Timer? _debounce;
  String _text = '';
  int _limit = _step;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  _UsersQuery get _q => _UsersQuery(_text, _limit);

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _text = v.trim();
          _limit = _step;
        });
      }
    });
  }

  Future<void> _setRole(Map<String, dynamic> u, String role) async {
    final name = jStr(u['display_name']) ?? jStr(u['email']) ?? '';
    final ok = await confirmDialog(
      context,
      title: context.tr(role == 'admin' ? 'admin_make_admin' : 'admin_remove_admin'),
      message: context.trf(role == 'admin' ? 'admin_make_admin_confirm' : 'admin_remove_admin_confirm', {'name': name}),
      danger: role != 'admin',
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).setRole(u['id'].toString(), role),
      success: context.tr('saved'),
    );
    if (done) ref.invalidate(_adminUsersProvider);
  }

  Future<void> _setBlocked(Map<String, dynamic> u, bool blocked) async {
    final name = jStr(u['display_name']) ?? jStr(u['email']) ?? '';
    final ok = await confirmDialog(
      context,
      title: context.tr(blocked ? 'admin_block' : 'admin_unblock'),
      message: context.trf(blocked ? 'admin_block_confirm' : 'admin_unblock_confirm', {'name': name}),
      danger: blocked,
    );
    if (!ok || !mounted) return;
    final done = await runAdminAction(
      context,
      () => ref.read(adminRepoProvider).setBlocked(u['id'].toString(), blocked),
      success: context.tr('saved'),
    );
    if (done) ref.invalidate(_adminUsersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminUsersProvider(_q));
    final myId = ref.watch(authUserProvider).valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('admin_users'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AppTextField(
              controller: _search,
              label: context.tr('admin_search_users'),
              icon: Icons.search_rounded,
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: AdminAsyncList<Map<String, dynamic>>(
              async: async,
              onRetry: () => ref.invalidate(_adminUsersProvider),
              emptyIcon: Icons.people_outline_rounded,
              emptyTitle: context.tr('empty_results'),
              builder: (context, rows) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: rows.length + (rows.length >= _limit ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == rows.length) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() => _limit += _step),
                        child: Text(context.tr('load_more')),
                      ),
                    );
                  }
                  final u = rows[i];
                  final isMe = u['id'].toString() == myId;
                  final isAdmin = u['role'] == 'admin';
                  final blocked = u['is_blocked'] == true;
                  final created = jDate(u['created_at']);
                  final name = jStr(u['display_name']) ?? jStr(u['email']) ?? '';
                  return Container(
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: ProfileAvatar(url: jStr(u['avatar_url']), name: name, radius: 22),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(jStr(u['email']) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (isAdmin) MiniBadge(context.tr('role_admin'), filled: true, color: AppColors.primary),
                              if (blocked) MiniBadge(context.tr('status_blocked'), filled: true, color: AppColors.danger),
                              if (isMe) MiniBadge(context.tr('admin_you'), color: AppColors.gold),
                              if (created != null) Text(fmtTimeAgo(created, context.isAr), style: const TextStyle(color: AppColors.textDim, fontSize: 11.5)),
                            ],
                          ),
                        ],
                      ),
                      trailing: isMe
                          ? null
                          : PopupMenuButton<String>(
                              color: AppColors.cardHigh,
                              onSelected: (v) {
                                if (v == 'make_admin') _setRole(u, 'admin');
                                if (v == 'remove_admin') _setRole(u, 'user');
                                if (v == 'block') _setBlocked(u, true);
                                if (v == 'unblock') _setBlocked(u, false);
                              },
                              itemBuilder: (_) => [
                                if (!isAdmin) PopupMenuItem(value: 'make_admin', child: Text(context.tr('admin_make_admin'))),
                                if (isAdmin) PopupMenuItem(value: 'remove_admin', child: Text(context.tr('admin_remove_admin'))),
                                if (!blocked) PopupMenuItem(value: 'block', child: Text(context.tr('admin_block'), style: const TextStyle(color: AppColors.danger))),
                                if (blocked) PopupMenuItem(value: 'unblock', child: Text(context.tr('admin_unblock'))),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

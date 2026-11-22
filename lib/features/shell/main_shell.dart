import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/providers.dart';
import '../account/account_page.dart';
import '../discover/discover_page.dart';
import '../home/home_page.dart';
import '../library/library_page.dart';
import '../search/search_page.dart';

/// الهيكل الرئيسي: 5 تبويبات في الشريط السفلي.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  final List<bool> _visited = [true, false, false, false, false];

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasBackend) {
      // مزامنة إعدادات الحساب وتسجيل الجهاز بعد أول إطار
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final profile = await ref.read(profileProvider.future);
          if (!mounted) return;
          ref.read(settingsProvider.notifier).applyFromProfile(profile);
          await ref.read(userRepoProvider).registerDevice(
                ref.read(deviceIdProvider),
                'Android device',
                Platform.operatingSystem,
              );
        } catch (_) {
          // لا نعطّل التطبيق إن فشلت المزامنة
        }
      });
    }
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _visited[i] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const DiscoverPage(),
      const SearchPage(),
      const LibraryPage(),
      const AccountPage(),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: Column(
          children: [
            const NetworkBanner(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    _visited[i] ? pages[i] : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomBar(index: _index, onSelect: _select),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, context.tr('nav_home')),
      (Icons.explore_outlined, Icons.explore_rounded, context.tr('nav_discover')),
      (Icons.search_rounded, Icons.search_rounded, context.tr('nav_search')),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, context.tr('nav_my_list')),
      (Icons.person_outline_rounded, Icons.person_rounded, context.tr('nav_account')),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: i == index ? items[i].$2 : items[i].$1,
                    label: items[i].$3,
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textDim;
    return PressableScale(
      scale: 0.9,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

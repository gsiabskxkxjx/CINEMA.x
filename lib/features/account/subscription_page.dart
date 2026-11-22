import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

/// عرض الباقات والاشتراك الحالي. بنية تحتية فقط: لا يوجد مزوّد دفع متصل، فلا يوجد زر شراء.
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  String _period(BuildContext context, String p) {
    switch (p) {
      case 'monthly':
        return context.tr('per_month');
      case 'yearly':
        return context.tr('per_year');
      default:
        return context.tr('free');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.isAr;
    final plans = ref.watch(plansProvider);
    final current = ref.watch(currentPlanProvider).valueOrNull;
    final settings = ref.watch(publicSettingsProvider).valueOrNull;
    final enabled = settings?['subscriptions_enabled'] == true || settings?['subscriptions_enabled'] == 'true';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('subscription'))),
      body: plans.when(
        loading: () => const ListSkeleton(count: 3),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(plansProvider)),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('current_plan'), style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(
                          current?.name(ar) ?? context.tr('plan_free'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.textDim),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr(enabled ? 'subscription_enabled_note' : 'subscription_disabled_note'),
                      style: const TextStyle(color: AppColors.textDim, height: 1.5, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(context.tr('available_plans'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final p in list) _PlanCard(plan: p, active: current?.id == p.id, periodLabel: _period(context, p.billingPeriod)),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.active, required this.periodLabel});

  final SubscriptionPlan plan;
  final bool active;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final free = plan.price <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? AppColors.primary : AppColors.divider, width: active ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name(ar), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              if (active) MiniBadge(context.tr('plan_active'), filled: true, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            free ? context.tr('free') : '${plan.price.toStringAsFixed(plan.price.truncateToDouble() == plan.price ? 0 : 2)} ${plan.currency} $periodLabel',
            style: const TextStyle(fontSize: 15, color: AppColors.gold, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.devices_rounded, size: 16, color: AppColors.textDim),
              const SizedBox(width: 6),
              Text(
                context.trf('max_devices', {'n': plan.maxDevices}),
                style: const TextStyle(color: AppColors.textDim, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/product_limits.dart';
import '../../../core/domain/subscription_plans.dart';
import '../../../core/models/company.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/app_toast.dart';
import '../admin_shell.dart';

/// The shop's plan: what it has, how much of it is used, the plans on offer
/// and who to contact to change plan.
///
/// The plan itself (`plan` on the company, which sets `max_products`) is set
/// by the platform; the shop can only read it.
class AdminSubscriptionScreen extends StatefulWidget {
  const AdminSubscriptionScreen({super.key});

  /// Opens an email app. Replaceable in tests.
  @visibleForTesting
  static Future<bool> Function(Uri uri) launcher = (uri) => launchUrl(uri);

  @override
  State<AdminSubscriptionScreen> createState() =>
      _AdminSubscriptionScreenState();
}

class _Usage {
  const _Usage(this.company, this.counts, this.categories);
  final Company? company;
  final ProductCounts counts;
  final int categories;
}

class _AdminSubscriptionScreenState extends State<AdminSubscriptionScreen> {
  late final Future<_Usage> _usage = _load();

  Future<_Usage> _load() async {
    final id = AuthSession.currentUser?.companyId ?? '';
    final company = await repo.company(id);
    final counts = await repo.productCounts(id);
    final categories = (await repo.categories(companyId: id).first).length;
    return _Usage(company, counts, categories);
  }

  static String _planName(AppLocalizations l10n, SubscriptionPlan p) =>
      switch (p) {
        SubscriptionPlan.basic => l10n.planBasic,
        SubscriptionPlan.golden => l10n.planGolden,
        SubscriptionPlan.diamond => l10n.planDiamond,
      };

  Future<void> _emailForUpgrade(SubscriptionPlan target, String shop) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final plan = _planName(l10n, target);
    final uri = Uri(
      scheme: 'mailto',
      path: PlanContact.email,
      query: _encodeQuery({
        'subject': l10n.planEmailSubject(plan, shop),
        'body': l10n.planEmailBody(PlanContact.name, shop, plan),
      }),
    );
    var opened = false;
    try {
      opened = await AdminSubscriptionScreen.launcher(uri);
    } catch (_) {}
    if (!opened && mounted) {
      messenger.showAppToast(
        SnackBar(content: Text(l10n.planEmailFailed(PlanContact.email))),
      );
    }
  }

  /// `mailto:` wants %20, not `+`, for spaces.
  static String _encodeQuery(Map<String, String> q) => q.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminShell(
      title: l10n.subscriptionPlanTitle,
      showBack: true,
      backRoute: AppRoutes.admin,
      child: FutureBuilder<_Usage>(
        future: _usage,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final usage = snap.data!;
          final company = usage.company;
          final current =
              company?.plan ??
              SubscriptionPlan.matchingMaxProducts(company?.maxProducts);
          final limits = ProductLimits(company?.maxProducts);
          final shop = company?.name ?? '';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                key: const Key('subscription-usage'),
                padding: const EdgeInsets.all(16),
                children: [
                  _CurrentPlanCard(
                    planName: current == null
                        ? l10n.planCustom
                        : _planName(l10n, current),
                    plan: current,
                    limits: limits,
                    counts: usage.counts,
                    categories: usage.categories,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.planChoose,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.planChooseHint,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 760;
                      final cards = [
                        for (final p in SubscriptionPlan.values)
                          _PlanCard(
                            plan: p,
                            name: _planName(l10n, p),
                            isCurrent: p == current,
                            isUpgrade:
                                current != null &&
                                p.maxProducts > current.maxProducts,
                            // Without a known plan every plan is an option.
                            isOption: current == null,
                            onUpgrade: () => _emailForUpgrade(p, shop),
                            fillHeight: wide,
                          ),
                      ];
                      if (!wide) {
                        return Column(
                          children: [
                            for (final card in cards) ...[
                              card,
                              const SizedBox(height: 14),
                            ],
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 14),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _ContactCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Colours and icon of each plan.
({Color color, IconData icon}) _look(SubscriptionPlan p) => switch (p) {
  SubscriptionPlan.basic => (
    color: const Color(0xFF3B82F6),
    icon: Icons.storefront_outlined,
  ),
  SubscriptionPlan.golden => (
    color: const Color(0xFFD97706),
    icon: Icons.workspace_premium,
  ),
  SubscriptionPlan.diamond => (
    color: const Color(0xFF7C3AED),
    icon: Icons.diamond_outlined,
  ),
};

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.planName,
    required this.plan,
    required this.limits,
    required this.counts,
    required this.categories,
  });

  final String planName;
  final SubscriptionPlan? plan;
  final ProductLimits limits;
  final ProductCounts counts;
  final int categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = plan == null ? Colors.blueGrey : _look(plan!).color;
    return Container(
      key: const Key('subscription-current'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  plan == null ? Icons.tune : _look(plan!).icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.planYourPlan,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      planName,
                      key: const Key('subscription-current-name'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!limits.hasLimit)
            Text(l10n.subscriptionNoLimit)
          else ...[
            _Meter(
              meterKey: 'subscription-published',
              label: l10n.subscriptionPublishedUsage,
              used: counts.published,
              of: limits.maxProducts!,
            ),
            const SizedBox(height: 12),
            _Meter(
              meterKey: 'subscription-total',
              label: l10n.subscriptionTotalUsage,
              used: counts.total,
              of: limits.totalCap!,
            ),
            if (plan != null) ...[
              const SizedBox(height: 12),
              _Meter(
                meterKey: 'subscription-categories',
                label: l10n.planCategoriesUsage,
                used: categories,
                of: plan!.maxCategories,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.meterKey,
    required this.label,
    required this.used,
    required this.of,
  });

  final String meterKey;
  final String label;
  final int used;
  final int of;

  @override
  Widget build(BuildContext context) {
    final full = used >= of;
    final color = full ? Colors.red.shade700 : null;
    return Column(
      key: Key(meterKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$used / $of',
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: of == 0 ? 0 : (used / of).clamp(0, 1).toDouble(),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.name,
    required this.isCurrent,
    required this.isUpgrade,
    required this.isOption,
    required this.onUpgrade,
    required this.fillHeight,
  });

  /// Side by side the cards share one height, so the button sits at the foot.
  final bool fillHeight;

  final SubscriptionPlan plan;
  final String name;
  final bool isCurrent;
  final bool isUpgrade;
  final bool isOption;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final look = _look(plan);
    final popular = plan == SubscriptionPlan.golden;
    final cap = ProductLimits(plan.maxProducts).totalCap!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: Key('plan-card-${plan.id}'),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrent
                  ? look.color
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              width: isCurrent ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: look.color.withValues(alpha: isCurrent ? 0.18 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: look.color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(look.icon, color: look.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: look.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Feature(
                icon: Icons.inventory_2_outlined,
                color: look.color,
                text: l10n.planPublishFeature(plan.maxProducts),
              ),
              _Feature(
                icon: Icons.layers_outlined,
                color: look.color,
                text: l10n.planCreateFeature(cap),
              ),
              _Feature(
                icon: Icons.category_outlined,
                color: look.color,
                text: l10n.planCategoriesFeature(plan.maxCategories),
              ),
              if (fillHeight) const Spacer(),
              const SizedBox(height: 14),
              if (isCurrent)
                _StatusPill(
                  key: Key('plan-current-${plan.id}'),
                  label: l10n.planCurrentBadge,
                  color: look.color,
                )
              else if (isUpgrade || isOption)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: Key('plan-upgrade-${plan.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: look.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onUpgrade,
                    child: Text(l10n.planUpgradeTo(name)),
                  ),
                )
              else
                _StatusPill(
                  label: l10n.planIncluded,
                  color: Colors.grey.shade600,
                ),
            ],
          ),
        ),
        if (popular)
          Positioned(
            top: -10,
            right: 16,
            child: Container(
              key: const Key('plan-popular'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: look.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.planMostPopular,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    ),
  );
}

/// Who to talk to about a plan change.
class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: const Key('plan-contact'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              'AP',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.planContactTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.planContactBody(PlanContact.name),
                  style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                ),
                const SizedBox(height: 10),
                const SelectableText(
                  '${PlanContact.name} · ${PlanContact.email}',
                  key: Key('plan-contact-email'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('plan-contact-send'),
                      icon: const Icon(Icons.mail_outline),
                      label: Text(
                        l10n.planContactEmailButton(PlanContact.name),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        var opened = false;
                        try {
                          opened = await AdminSubscriptionScreen.launcher(
                            Uri(scheme: 'mailto', path: PlanContact.email),
                          );
                        } catch (_) {}
                        if (!opened) {
                          messenger.showAppToast(
                            SnackBar(
                              content: Text(
                                l10n.planEmailFailed(PlanContact.email),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      key: const Key('plan-contact-copy'),
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(l10n.planCopyEmail),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(
                          const ClipboardData(text: PlanContact.email),
                        );
                        messenger.showAppToast(
                          SnackBar(content: Text(l10n.planEmailCopied)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

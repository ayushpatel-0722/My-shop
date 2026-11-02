import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/domain/employee_roles.dart';
import '../../../core/domain/packing_workflow.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../../auth/auth_cubit.dart';
import '../employee_access_scope.dart';
import '../packing/packing_actions.dart';
import '../packing/packing_checklist.dart';

/// Packing dashboard: a role-restricted view of the shop's real order
/// pipeline, grouped by [PackingStage].
///
/// Packers see the products to pack, never payment details, and can only take
/// the next step [PackingWorkflow.nextAction] allows.
class EmployeeOrderQueueScreen extends StatefulWidget {
  const EmployeeOrderQueueScreen({super.key});

  @override
  State<EmployeeOrderQueueScreen> createState() =>
      _EmployeeOrderQueueScreenState();
}

class _EmployeeOrderQueueScreenState extends State<EmployeeOrderQueueScreen> {
  PackingStage _stage = PackingStage.toPack;
  String _query = '';
  // Bumped by "Retry" so the StreamBuilder resubscribes.
  int _attempt = 0;
  Stream<List<Order>>? _stream;
  String _streamCompany = '';

  Stream<List<Order>> _ordersFor(String companyId) {
    if (_stream == null || _streamCompany != companyId) {
      _streamCompany = companyId;
      _stream = repo.orders(companyId: companyId);
    }
    return _stream!;
  }

  @override
  void initState() {
    super.initState();
    _followRequestedStage();
    requestedPackingStage.addListener(_followRequestedStage);
  }

  @override
  void dispose() {
    requestedPackingStage.removeListener(_followRequestedStage);
    super.dispose();
  }

  /// After an action (here or on the details screen) jump to the tab the
  /// order moved to, so the packer sees it land instead of an empty list.
  void _followRequestedStage() {
    final requested = requestedPackingStage.value;
    if (requested == null) return;
    requestedPackingStage.value = null;
    if (mounted) setState(() => _stage = requested);
  }

  void _retry() => setState(() {
    _attempt++;
    _stream = null;
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().currentUser;
    return LiveEmployeeAccess(
      user: user,
      builder: (context, access) => _scaffold(context, user, access),
    );
  }

  Widget _scaffold(BuildContext context, AppUser? user, EmployeeAccess access) {
    final l10n = AppLocalizations.of(context);
    final companyId = user?.companyId ?? '';
    final employeeId = user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        // The dashboard is the employee's home: never a back arrow to the
        // shopper app.
        automaticallyImplyLeading: false,
        title: Text(l10n.empDashboardTitle),
        actions: [
          IconButton(
            key: const Key('employee-logout'),
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: () async {
              await context.read<AuthCubit>().signOut();
              if (context.mounted) context.go(AppRoutes.role);
            },
          ),
        ],
      ),
      body: !access.hasFulfilmentAccess && companyId.isNotEmpty
          ? _Message(
              key: const Key('employee-no-access'),
              icon: Icons.lock_outline,
              text: l10n.empNoAccess,
            )
          : companyId.isEmpty
          ? _Message(
              icon: Icons.storefront_outlined,
              text: l10n.empNoShop,
              key: const Key('employee-no-shop'),
            )
          : StreamBuilder<List<Order>>(
              key: ValueKey(_attempt),
              stream: _ordersFor(companyId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _Message(
                    key: const Key('employee-error'),
                    icon: Icons.cloud_off_outlined,
                    text: l10n.empLoadError,
                    onRetry: _retry,
                  );
                }
                if (!snap.hasData) {
                  return const Center(
                    key: Key('employee-loading'),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final mine = snap.data!
                    .where(
                      (o) => PackingWorkflow.isEligible(o, employeeId, access),
                    )
                    .toList();
                final stages = PackingWorkflow.stagesFor(access);
                return _Body(
                  orders: mine,
                  employeeId: employeeId,
                  access: access,
                  stages: stages,
                  stage: stages.contains(_stage) ? _stage : stages.first,
                  query: _query,
                  onStage: (s) => setState(() => _stage = s),
                  onQuery: (q) => setState(() => _query = q),
                );
              },
            ),
    );
  }
}

class _Body extends StatelessWidget {
  final List<Order> orders;
  final String employeeId;
  final EmployeeAccess access;
  final List<PackingStage> stages;
  final PackingStage stage;
  final String query;
  final ValueChanged<PackingStage> onStage;
  final ValueChanged<String> onQuery;

  const _Body({
    required this.orders,
    required this.employeeId,
    required this.access,
    required this.stages,
    required this.stage,
    required this.query,
    required this.onStage,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = {
      for (final s in stages)
        s: orders.where((o) => PackingWorkflow.stageOf(o, access) == s).length,
    };
    final q = query.trim().toLowerCase();
    final shown = orders.where((o) {
      if (PackingWorkflow.stageOf(o, access) != stage) return false;
      if (q.isEmpty) return true;
      return o.reference.toLowerCase().contains(q) ||
          o.id.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q);
    }).toList()..sort((a, b) => _byDate(a, b));

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final columns = c.maxWidth >= 1100 ? 3 : (wide ? 2 : 1);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 24 : 12,
                    16,
                    wide ? 24 : 12,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(
                          counts: counts,
                          stages: stages,
                          total: orders.length,
                          stage: stage,
                          onStage: onStage,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('employee-search'),
                          onChanged: onQuery,
                          decoration: InputDecoration(
                            hintText: l10n.empSearchHint,
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (shown.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Message(
                      key: const Key('employee-empty'),
                      icon: Icons.inventory_2_outlined,
                      text: l10n.empNoOrdersInStage,
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 12,
                      0,
                      wide ? 24 : 12,
                      24,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 290,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _OrderCard(
                        order: shown[i],
                        employeeId: employeeId,
                        access: access,
                        onMoved: onStage,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Oldest first: the order that has waited longest gets packed first.
  static int _byDate(Order a, Order b) {
    final x = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final y = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return x.compareTo(y);
  }
}

String stageLabel(AppLocalizations l10n, PackingStage s) => switch (s) {
  PackingStage.toPack => l10n.empStageToPack,
  PackingStage.inProgress => l10n.empStageInProgress,
  PackingStage.handedOver => l10n.empStageHandedOver,
  PackingStage.toDispatch => l10n.empStageToDispatch,
  PackingStage.outForDelivery => l10n.empStageOutForDelivery,
  PackingStage.delivered => l10n.empStageDelivered,
};

class _SummaryRow extends StatelessWidget {
  final Map<PackingStage, int> counts;
  final List<PackingStage> stages;
  final int total;
  final PackingStage stage;
  final ValueChanged<PackingStage> onStage;

  const _SummaryRow({
    required this.counts,
    required this.stages,
    required this.total,
    required this.stage,
    required this.onStage,
  });

  static const _icons = {
    PackingStage.toPack: Icons.inbox_outlined,
    PackingStage.inProgress: Icons.inventory_2_outlined,
    PackingStage.handedOver: Icons.local_shipping_outlined,
    PackingStage.toDispatch: Icons.outbox_outlined,
    PackingStage.outForDelivery: Icons.local_shipping_outlined,
    PackingStage.delivered: Icons.task_alt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in stages)
          _StatCard(
            key: Key('employee-tab-${s.name}'),
            icon: _icons[s]!,
            label: stageLabel(l10n, s),
            value: counts[s] ?? 0,
            selected: s == stage,
            onTap: () => onStage(s),
          ),
        _StatCard(
          key: const Key('employee-total'),
          icon: Icons.list_alt_outlined,
          label: l10n.empTotalOrders,
          value: total,
          color: scheme.outline,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.selected = false,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return SizedBox(
      width: 168,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? accent : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$value',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;
  final String employeeId;
  final EmployeeAccess access;
  final ValueChanged<PackingStage> onMoved;
  const _OrderCard({
    required this.order,
    required this.employeeId,
    required this.access,
    required this.onMoved,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _busy = false;

  void _open() =>
      context.push(AppRoutes.packing.replaceFirst(':orderId', widget.order.id));

  Future<void> _run(PackingAction action) async {
    // Finishing packing needs the item checklist, which lives on the details
    // screen: the card sends the packer there instead of skipping the checks.
    if (action == PackingAction.markPacked) return _open();
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await performPackingAction(
        widget.order,
        action,
        widget.employeeId,
        widget.access,
      );
      if (!mounted) return;
      AppToast.success(context, packingActionDoneText(l10n, action));
      widget.onMoved(PackingWorkflow.stageAfter(action, widget.access));
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          l10n.empActionFailed,
          detail: packingErrorDetail(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final o = widget.order;
    final action = PackingWorkflow.nextAction(
      o,
      widget.employeeId,
      widget.access,
    );
    final stage = PackingWorkflow.stageOf(o, widget.access);
    final date = o.createdAt == null
        ? ''
        : DateFormat('d MMM, h:mm a').format(o.createdAt!.toLocal());
    final where = o.isSelfPickup
        ? (o.pickupShop?.name.isNotEmpty == true
              ? '${l10n.pickup} · ${o.pickupShop!.name}'
              : l10n.pickup)
        : l10n.delivery;

    return Card(
      key: Key('employee-order-${o.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      o.reference,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OrderStatusBadge(status: o.orderStatus),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      o.customerName.isEmpty ? '—' : o.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(date, style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              _ItemStrip(items: o.items, total: o.itemCount),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Meta(
                    o.isSelfPickup
                        ? Icons.storefront
                        : Icons.local_shipping_outlined,
                    where,
                  ),
                ],
              ),
              if (stage == PackingStage.inProgress && o.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                _CheckProgress(orderId: o.id, total: o.items.length),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton(
                      key: Key('employee-view-${o.id}'),
                      onPressed: _open,
                      child: Text(
                        l10n.empViewDetails,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: FilledButton(
                        key: Key('employee-action-${o.id}'),
                        onPressed: _busy ? null : () => _run(action),
                        child: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                action == PackingAction.markPacked
                                    ? l10n.empOpenToPack
                                    : packingActionLabel(l10n, action),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thumbnails of the first few products with their quantities, so a packer
/// can see what is in the order without opening it.
class _ItemStrip extends StatelessWidget {
  final List<OrderItem> items;
  final int total;
  const _ItemStrip({required this.items, required this.total});

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) => _strip(context, c.maxWidth));
  }

  Widget _strip(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Leave room for the "+N more" and "N items" labels; show as many
    // thumbnails (50px each) as then fit, at least one.
    final fit = ((width - 120) / 50).floor().clamp(1, _maxShown);
    final shown = items.take(fit).toList();
    final hidden = items.length - shown.length;
    return Row(
      key: const Key('employee-item-strip'),
      children: [
        for (final item in shown)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: item.image.isEmpty
                        ? ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: scheme.outline,
                            ),
                          )
                        : Image.network(
                            item.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 20,
                                color: scheme.outline,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${item.qty}',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Text(
            hidden > 0
                ? '${l10n.empMoreItems(hidden)} · ${l10n.empItemsCount(total)}'
                : l10n.empItemsCount(total),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// "2 of 5 items checked" with a bar, from the packer's saved ticks.
class _CheckProgress extends StatelessWidget {
  final String orderId;
  final int total;
  const _CheckProgress({required this.orderId, required this.total});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: PackingChecklist.revision,
      builder: (context, _, _) => FutureBuilder<Set<int>>(
        future: PackingChecklist.load(orderId),
        builder: (context, snap) {
          final done = (snap.data ?? const <int>{})
              .where((i) => i >= 0 && i < total)
              .length;
          return Column(
            key: Key('employee-progress-$orderId'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.empPackedProgress(done, total),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  const _Message({
    super.key,
    required this.icon,
    required this.text,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('employee-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).empRetry),
            ),
          ],
        ],
      ),
    ),
  );
}

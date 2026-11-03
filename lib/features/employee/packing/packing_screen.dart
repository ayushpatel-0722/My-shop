import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myshop/core/widgets/addon_lines.dart';
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
import 'packing_actions.dart';
import 'packing_checklist.dart';

/// Employee order details: laid out like the admin's order details (cards for
/// the order, the people involved and the items) plus what a packer or
/// dispatcher needs: a progress stepper, the item checklist and one clear
/// next-step button.
///
/// Items come from the order's own snapshot (name, image, variant), so a
/// product that was edited or deleted since checkout is still listed. Prices
/// and payment details are deliberately not shown. The delivery address and
/// phone appear only for employees who may dispatch.
class PackingScreen extends StatefulWidget {
  final String orderId;
  const PackingScreen({super.key, required this.orderId});

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  final Set<int> _checked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PackingChecklist.load(widget.orderId).then((saved) {
      if (mounted) setState(() => _checked.addAll(saved));
    });
  }

  void _toggle(int index) {
    setState(
      () => _checked.contains(index)
          ? _checked.remove(index)
          : _checked.add(index),
    );
    PackingChecklist.save(widget.orderId, _checked);
  }

  void _setAll(int total, bool value) {
    setState(() {
      _checked.clear();
      if (value) _checked.addAll(List.generate(total, (i) => i));
    });
    PackingChecklist.save(widget.orderId, _checked);
  }

  /// Back always means the employee dashboard, never the shopper app.
  void _goBack() => context.go(AppRoutes.employeeHome);

  Future<void> _run(
    Order order,
    PackingAction action,
    String employeeId,
    EmployeeAccess access,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (action == PackingAction.markDelivered) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(packingActionLabel(l10n, action)),
          content: Text(l10n.empConfirmDelivered),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.empCancel),
            ),
            FilledButton(
              key: const Key('packing-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.empConfirm),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await performPackingAction(order, action, employeeId, access);
      if (!mounted) return;
      if (action == PackingAction.markPacked) {
        await PackingChecklist.clear(order.id);
        if (!mounted) return;
      }
      AppToast.success(context, packingActionDoneText(l10n, action));
      // Tell the dashboard which tab the order moved to. Starting to pack
      // keeps the packer here (the checklist unlocks); every other step is
      // finished with this order, so go back to the list.
      requestedPackingStage.value = PackingWorkflow.stageAfter(action, access);
      if (action != PackingAction.startPacking) _goBack();
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
    final user = context.watch<AuthCubit>().currentUser;
    return LiveEmployeeAccess(
      user: user,
      builder: (context, access) => _page(context, user, access),
    );
  }

  Widget _page(BuildContext context, AppUser? user, EmployeeAccess access) {
    final l10n = AppLocalizations.of(context);
    final employeeId = user?.id ?? '';
    return StreamBuilder<Order?>(
      stream: repo.watchOrder(widget.orderId, companyId: user?.companyId ?? ''),
      builder: (context, snap) {
        final order = snap.data;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const Key('packing-back'),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.empBackToDashboard,
              onPressed: _goBack,
            ),
            title: Text(
              order?.reference ?? l10n.manifest(l10n.packing),
              key: const Key('packing-title'),
            ),
            actions: [
              if (order != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: OrderStatusBadge(status: order.orderStatus),
                  ),
                ),
            ],
          ),
          body: _body(context, snap, order, employeeId, access),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AsyncSnapshot<Order?> snap,
    Order? order,
    String employeeId,
    EmployeeAccess access,
  ) {
    final l10n = AppLocalizations.of(context);
    if (snap.hasError) {
      return Center(child: Text(l10n.empLoadError));
    }
    if (order == null) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(child: Text(l10n.orderNotFound));
    }
    if (!PackingWorkflow.isEligible(order, employeeId, access)) {
      return Center(
        key: const Key('packing-not-allowed'),
        child: Text(l10n.empNotAllowed),
      );
    }

    final action = PackingWorkflow.nextAction(order, employeeId, access);
    final stage = PackingWorkflow.stageOf(order, access);
    // Ticks can only be changed while packing is under way. Before that there
    // is nothing to tick; afterwards every line was packed by definition.
    final canCheck = stage == PackingStage.inProgress;
    final lockedOpen = stage == PackingStage.toPack;
    final total = order.items.length;
    final doneCount = canCheck
        ? _checked.where((i) => i >= 0 && i < total).length
        : (lockedOpen ? 0 : total);
    final allChecked = total == 0 || doneCount == total;
    final needsAllTicks = action == PackingAction.markPacked && !allChecked;

    final items = _ItemsCard(
      order: order,
      canCheck: canCheck,
      lockedOpen: lockedOpen,
      doneCount: doneCount,
      allChecked: allChecked,
      onToggle: _toggle,
      onSetAll: (v) => _setAll(total, v),
      isChecked: (i) => canCheck ? _checked.contains(i) : !lockedOpen,
    );
    final side = [
      _ProgressCard(order: order, hasAction: action != null),
      _InfoCard(order: order, showDelivery: access.canDispatch),
    ];

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 24 : 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: items),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    for (final w in side) ...[
                                      w,
                                      const SizedBox(height: 16),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              for (final w in side) ...[
                                w,
                                const SizedBox(height: 12),
                              ],
                              items,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        _ActionBar(
          action: action,
          stage: stage,
          busy: _busy,
          needsAllTicks: needsAllTicks,
          onPressed: action == null
              ? null
              : () => _run(order, action, employeeId, access),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// Same card look as the admin order screens.
class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Key? panelKey;

  const _Panel({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.panelKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: panelKey,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Where the order is on its way from "confirmed" to "delivered".
class _ProgressCard extends StatelessWidget {
  final Order order;
  final bool hasAction;
  const _ProgressCard({required this.order, required this.hasAction});

  /// 0 confirmed, 1 packing, 2 packed, 3 ready, 4 on the way, 5 delivered.
  static int _index(Order o) {
    switch (o.orderStatus) {
      case OrderStatus.confirmed:
        return 0;
      case OrderStatus.packing:
        return 1;
      case OrderStatus.ready:
        return 3;
      case OrderStatus.onTheWay:
        return 4;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return 5;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      orderStatusLabel(context, OrderStatus.confirmed),
      orderStatusLabel(context, OrderStatus.packing),
      l10n.empStagePacked,
      orderStatusLabel(context, OrderStatus.ready),
      orderStatusLabel(context, OrderStatus.onTheWay),
      l10n.empStageDelivered,
    ];
    final current = _index(order);
    return _Panel(
      panelKey: const Key('packing-progress-card'),
      icon: Icons.timeline,
      title: l10n.empOrderProgress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _Step(
                key: Key('packing-step-$i'),
                label: labels[i],
                first: i == 0,
                last: i == labels.length - 1,
                done: i < current || (i == current && current == 5),
                active: i == current && current != 5,
                yourTurn: i == current && hasAction,
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final bool first;
  final bool last;
  final bool done;
  final bool active;
  final bool yourTurn;

  const _Step({
    super.key,
    required this.label,
    required this.first,
    required this.last,
    required this.done,
    required this.active,
    required this.yourTurn,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reached = done || active;
    final color = reached ? scheme.primary : scheme.outlineVariant;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 2,
                color: first
                    ? Colors.transparent
                    : (reached ? scheme.primary : scheme.outlineVariant),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? scheme.primary : scheme.surface,
                border: Border.all(color: color, width: 2),
              ),
              child: done
                  ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                  : (active
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                              ),
                            ),
                          )
                        : null),
            ),
            Expanded(
              child: Container(
                height: 2,
                color: last
                    ? Colors.transparent
                    : (done ? scheme.primary : scheme.outlineVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: reached
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        if (yourTurn)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              key: const Key('packing-your-step'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppLocalizations.of(context).empYourStep,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Order information, like the admin's header + fulfilment cards.
class _InfoCard extends StatelessWidget {
  final Order order;
  final bool showDelivery;
  const _InfoCard({required this.order, required this.showDelivery});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final placed = order.createdAt == null
        ? '—'
        : fmt.format(order.createdAt!.toLocal());
    final updated = order.updatedAt == null
        ? null
        : fmt.format(order.updatedAt!.toLocal());
    final where = order.isSelfPickup
        ? (order.pickupShop?.name.isNotEmpty == true
              ? '${l10n.pickup} · ${order.pickupShop!.name}'
              : l10n.pickup)
        : l10n.delivery;
    // The saved address usually already ends with the pincode: add it only
    // when it is missing.
    final pin = order.pincode.trim();
    final address = [
      order.address.trim(),
      if (pin.isNotEmpty && !order.address.contains(pin)) pin,
    ].where((e) => e.isNotEmpty).join(' - ');

    return _Panel(
      panelKey: const Key('packing-info-card'),
      icon: Icons.receipt_long_outlined,
      title: l10n.empOrderInfo,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.tag,
            label: 'ID',
            value: order.id,
            copyable: true,
          ),
          _InfoRow(
            icon: Icons.person_outline,
            label: l10n.empCustomer,
            value: order.customerName.isEmpty ? '—' : order.customerName,
          ),
          _InfoRow(
            icon: Icons.event_outlined,
            label: l10n.empPlaced,
            value: placed,
          ),
          if (updated != null)
            _InfoRow(
              icon: Icons.update,
              label: l10n.empUpdated,
              value: updated,
            ),
          _InfoRow(
            icon: Icons.inventory_2_outlined,
            label: l10n.empTotalPieces,
            value: l10n.empItemsCount(order.itemCount),
          ),
          _InfoRow(
            icon: order.isSelfPickup
                ? Icons.storefront_outlined
                : Icons.local_shipping_outlined,
            label: l10n.delivery,
            value: where,
          ),
          if (showDelivery && !order.isSelfPickup && address.isNotEmpty)
            _InfoRow(
              key: const Key('packing-address'),
              icon: Icons.location_on_outlined,
              label: l10n.empDeliveryAddress,
              value: address,
              copyable: true,
            ),
          if (showDelivery && order.customerPhone.trim().isNotEmpty)
            _InfoRow(
              key: const Key('packing-phone'),
              icon: Icons.phone_outlined,
              label: l10n.empPhone,
              value: order.customerPhone,
              copyable: true,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  const _InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (copyable)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                AppToast.info(context, AppLocalizations.of(context).empCopied);
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

/// The items to pack, with the checklist.
class _ItemsCard extends StatelessWidget {
  final Order order;
  final bool canCheck;
  final bool lockedOpen;
  final int doneCount;
  final bool allChecked;
  final ValueChanged<int> onToggle;
  final ValueChanged<bool> onSetAll;
  final bool Function(int) isChecked;

  const _ItemsCard({
    required this.order,
    required this.canCheck,
    required this.lockedOpen,
    required this.doneCount,
    required this.allChecked,
    required this.onToggle,
    required this.onSetAll,
    required this.isChecked,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = order.items.length;
    return _Panel(
      panelKey: const Key('packing-items-card'),
      icon: Icons.checklist_rtl,
      title: l10n.empOrderItems,
      trailing: canCheck && total > 0
          ? TextButton(
              key: const Key('packing-select-all'),
              onPressed: () => onSetAll(!allChecked),
              child: Text(
                allChecked ? l10n.empClearAll : l10n.empSelectAll,
                maxLines: 1,
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : doneCount / total,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.empPackedProgress(doneCount, total),
              key: const Key('packing-progress'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
          ],
          if (lockedOpen && total > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.empStartToCheck,
                      key: const Key('packing-start-hint'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  l10n.empNoItems,
                  key: const Key('packing-no-items'),
                ),
              ),
            ),
          for (var i = 0; i < total; i++)
            _ItemRow(
              index: i,
              item: order.items[i],
              checked: isChecked(i),
              enabled: canCheck,
              onToggle: () => onToggle(i),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final int index;
  final OrderItem item;
  final bool checked;
  final bool enabled;
  final VoidCallback onToggle;

  const _ItemRow({
    required this.index,
    required this.item,
    required this.checked,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final variant = item.displayVariantLabel;
    return Container(
      key: Key('packing-item-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: checked
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: enabled ? (_) => onToggle() : null,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: item.image.isEmpty
                      ? _Placeholder(scheme: scheme)
                      : Image.network(
                          item.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _Placeholder(scheme: scheme),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isNotEmpty ? item.name : item.productId,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (variant.isNotEmpty)
                      Text(
                        variant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.variantSku.isNotEmpty &&
                        item.variantSku != variant)
                      Text(
                        l10n.empSku(item.variantSku),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    // Extras to pack or arrange with the item (assembly, ...).
                    AddOnLines(
                      addOns: item.addOns,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: Key('packing-qty-$index'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '×${item.qty}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      l10n.empQty,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ColorScheme scheme;
  const _Placeholder({required this.scheme});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: scheme.surfaceContainerHighest,
    child: Icon(Icons.inventory_2_outlined, color: scheme.outline),
  );
}

// ---------------------------------------------------------------------------
// Action bar
// ---------------------------------------------------------------------------

/// The fixed bar at the bottom: the single next step, or a note on why there
/// is none.
class _ActionBar extends StatelessWidget {
  final PackingAction? action;
  final PackingStage? stage;
  final bool busy;
  final bool needsAllTicks;
  final VoidCallback? onPressed;

  const _ActionBar({
    required this.action,
    required this.stage,
    required this.busy,
    required this.needsAllTicks,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final a = action;

    Widget content;
    if (a != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (needsAllTicks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.empCheckAllToFinish,
                key: const Key('packing-check-hint'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          FilledButton.icon(
            key: const Key('packing-action'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: busy || needsAllTicks ? null : onPressed,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(switch (a) {
                    PackingAction.startPacking => Icons.play_arrow,
                    PackingAction.markPacked => Icons.inventory,
                    PackingAction.startDelivery =>
                      Icons.local_shipping_outlined,
                    PackingAction.markDelivered => Icons.task_alt,
                  }),
            label: Text(packingActionLabel(l10n, a)),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

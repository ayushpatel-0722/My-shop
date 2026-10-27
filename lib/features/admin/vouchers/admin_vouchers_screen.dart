import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/domain/validators.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/models/voucher.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/modern_shimmer.dart';
import '../admin_shell.dart';

/// Voucher engine — create, edit, pause and audit per-store coupon codes.
///
/// Before this rewrite the screen listed **every** company's vouchers
/// (`repo.vouchers('')`), could not edit anything, hard-coded a 30-day expiry
/// and deleted codes without confirmation. It is now:
///  * scoped to the signed-in admin's company,
///  * searchable and filterable (all / active / paused / expired),
///  * a full create **and** edit form with real validation,
///  * showing live redemption counters so caps are actually observable.
class AdminVouchersScreen extends StatefulWidget {
  const AdminVouchersScreen({super.key});

  @override
  State<AdminVouchersScreen> createState() => _AdminVouchersScreenState();
}

/// Status filter shown as chips above the list.
enum VoucherFilter { all, active, paused, expired }

class _AdminVouchersScreenState extends State<AdminVouchersScreen> {
  final _searchCtrl = TextEditingController();
  VoucherFilter _filter = VoucherFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _companyId => AuthSession.currentUser?.companyId ?? '';

  List<Voucher> _applyFilters(List<Voucher> vouchers) {
    final now = DateTime.now();
    final query = Voucher.normalizeCode(_searchCtrl.text);

    return vouchers.where((v) {
      switch (_filter) {
        case VoucherFilter.active:
          if (!v.isLiveAt(now) || v.isExhausted) return false;
          break;
        case VoucherFilter.paused:
          if (v.isActive) return false;
          break;
        case VoucherFilter.expired:
          if (!v.isExpiredAt(now)) return false;
          break;
        case VoucherFilter.all:
          break;
      }
      if (query.isNotEmpty && !v.normalizedCode.contains(query)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = _companyId;

    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).vouchers,
      actions: [
        IconButton(
          key: const Key('voucher-create-button'),
          icon: const Icon(Icons.add),
          tooltip: AppLocalizations.of(context).createVoucher,
          onPressed: () => _openEditor(null),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('voucher-search-field'),
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).searchByCode,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final filter in VoucherFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabel(filter)),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Voucher>>(
              stream: repo.vouchers(companyId),
              builder: (context, snap) {
                final all = snap.data ?? const <Voucher>[];
                final list = _applyFilters(all);

                if (all.isEmpty) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: 4,
                      itemBuilder: (_, _) => const M3ListTileSkeleton(),
                    );
                  }
                  return _EmptyState(
                    message: AppLocalizations.of(context).noVouchersYet,
                    detail: AppLocalizations.of(
                      context,
                    ).createYourFirstCouponCodeToRunAPromotionForThisStore,
                    actionLabel: AppLocalizations.of(context).createVoucher2,
                    onAction: () => _openEditor(null),
                  );
                }
                if (list.isEmpty) {
                  return _EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    message: AppLocalizations.of(
                      context,
                    ).noVouchersMatchTheseFilters,
                    detail: AppLocalizations.of(
                      context,
                    ).tryClearingTheSearchBoxOrChoosingAll,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _SummaryRow(vouchers: all),
                    const SizedBox(height: 12),
                    for (final v in list) ...[
                      _VoucherTile(
                        key: Key('voucher-tile-${v.id}'),
                        voucher: v,
                        onEdit: () => _openEditor(v),
                        onDelete: () => _confirmDelete(v),
                        onToggle: (value) =>
                            repo.saveVoucher(v.copyWith(isActive: value)),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(VoucherFilter filter) {
    switch (filter) {
      case VoucherFilter.all:
        return AppLocalizations.of(context).all3;
      case VoucherFilter.active:
        return AppLocalizations.of(context).active;
      case VoucherFilter.paused:
        return AppLocalizations.of(context).paused;
      case VoucherFilter.expired:
        return AppLocalizations.of(context).expired;
    }
  }

  Future<void> _openEditor(Voucher? voucher) async {
    // Existing codes are needed to keep codes unique inside the store.
    final codes = (await repo.vouchers(_companyId).first)
        .where((v) => v.id != voucher?.id)
        .map((v) => v.normalizedCode)
        .toList();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VoucherEditorSheet(
        companyId: _companyId,
        existingCodes: codes,
        voucher: voucher,
      ),
    );
  }

  Future<void> _confirmDelete(Voucher voucher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteVoucher2),
        content: Text(
          AppLocalizations.of(
            context,
          ).willBeRemovedShoppersWhoSavedThisCodeWillNoLongerGetTheDiscount(
            voucher.normalizedCode,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repo.deleteVoucher(voucher.id, companyId: _companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).voucherDeleted(voucher.normalizedCode),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).couldNotDeleteVoucher('$e'),
          ),
        ),
      );
    }
  }
}

/// Counters above the list: how many codes are live, paused or expired.
class _SummaryRow extends StatelessWidget {
  final List<Voucher> vouchers;
  const _SummaryRow({required this.vouchers});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = vouchers
        .where((v) => v.isLiveAt(now) && !v.isExhausted)
        .length;
    final paused = vouchers.where((v) => !v.isActive).length;
    final expired = vouchers.where((v) => v.isExpiredAt(now)).length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: AppLocalizations.of(context).totalAmount,
            value: '${vouchers.length}',
            icon: Icons.local_offer_outlined,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: AppLocalizations.of(context).live2,
            value: '$active',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: AppLocalizations.of(context).paused,
            value: '$paused',
            icon: Icons.pause_circle_outline,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: AppLocalizations.of(context).expired,
            value: '$expired',
            icon: Icons.event_busy_outlined,
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    return ModernCard(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 14 : 10,
          vertical: isDesktop ? 14 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: isDesktop ? 22 : 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isDesktop ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isDesktop ? 13 : 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoucherTile extends StatelessWidget {
  final Voucher voucher;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _VoucherTile({
    super.key,
    required this.voucher,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final isDesktop = context.isDesktop;
    final expired = voucher.isExpiredAt(now);
    final exhausted = voucher.isExhausted;

    final statusColor = !voucher.isActive
        ? Colors.orange
        : expired
        ? Colors.redAccent
        : exhausted
        ? Colors.purple
        : Colors.green;
    final statusLabel = !voucher.isActive
        ? AppLocalizations.of(context).paused
        : expired
        ? AppLocalizations.of(context).expired
        : exhausted
        ? AppLocalizations.of(context).limitReached
        : AppLocalizations.of(context).active;

    final usage = voucher.maxUses > 0
        ? AppLocalizations.of(
            context,
          ).uses('${voucher.usageCount}', '${voucher.maxUses}')
        : AppLocalizations.of(context).usesUnlimited('${voucher.usageCount}');

    return ModernCard(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 12 : 10,
                    vertical: isDesktop ? 7 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    voucher.normalizedCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontSize: isDesktop ? 15 : 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 10 : 8,
                    vertical: isDesktop ? 4 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: isDesktop ? 22 : 20),
                  tooltip: AppLocalizations.of(context).editVoucher,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: isDesktop ? 22 : 20,
                    color: Colors.redAccent,
                  ),
                  tooltip: AppLocalizations.of(context).deleteVoucher,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${voucher.discountLabel} · ${voucher.typeLabel}',
              style: TextStyle(
                fontSize: isDesktop ? 16.5 : 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).minOrder4(
                voucher.minOrderAmt.toStringAsFixed(0),
                voucher.scopeLabel,
                voucher.appliesTo == VoucherScope.specificCategory
                    ? ' (${voucher.categoryIds.length})'
                    : '',
                voucher.appliesTo == VoucherScope.specificProduct
                    ? ' (${voucher.productIds.length})'
                    : '',
              ),
              style: TextStyle(
                fontSize: isDesktop ? 13.5 : 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppLocalizations.of(context).perShopperExpires(
                usage,
                '${voucher.perUserLimit}',
                voucher.firstTimeOnly
                    ? AppLocalizations.of(context).firstOrderOnly2
                    : '',
                _fmt(context, voucher.expiryDate),
              ),
              style: TextStyle(
                fontSize: isDesktop ? 13 : 12,
                color: Colors.grey,
              ),
            ),
            if (voucher.maxUses > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: voucher.maxUses == 0
                      ? 0
                      : (voucher.usageCount / voucher.maxUses)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                  minHeight: 6,
                  color: exhausted ? Colors.purple : theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    voucher.isActive
                        ? AppLocalizations.of(context).acceptingRedemptions
                        : AppLocalizations.of(context).paused,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Switch(value: voucher.isActive, onChanged: onToggle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(BuildContext context, DateTime? date) => date == null
      ? 'never'
      : DateFormat(AppLocalizations.of(context).ddMmmYyyy).format(date);
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const _EmptyState({
    required this.message,
    required this.detail,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.local_offer_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create / edit sheet
// ---------------------------------------------------------------------------

class _VoucherEditorSheet extends StatefulWidget {
  final String companyId;
  final List<String> existingCodes;
  final Voucher? voucher;

  const _VoucherEditorSheet({
    required this.companyId,
    required this.existingCodes,
    this.voucher,
  });

  @override
  State<_VoucherEditorSheet> createState() => _VoucherEditorSheetState();
}

class _VoucherEditorSheetState extends State<_VoucherEditorSheet> {
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _perUserCtrl = TextEditingController();
  final _maxUsesCtrl = TextEditingController();

  String _type = VoucherType.percentage;
  String _appliesTo = VoucherScope.allCategories;
  DateTime? _expiryDate;
  bool _firstTimeOnly = false;
  bool _isActive = true;
  final Set<String> _productIds = <String>{};
  final Set<String> _categoryIds = <String>{};

  Map<String, String> _errors = const <String, String>{};
  bool _saving = false;

  bool get _isEdit => widget.voucher != null;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    if (v != null) {
      _codeCtrl.text = v.normalizedCode;
      _valueCtrl.text = v.discountType == VoucherType.freeShipping
          ? ''
          : v.discountValue.toString();
      _minCtrl.text = v.minOrderAmt > 0 ? v.minOrderAmt.toString() : '';
      _perUserCtrl.text = v.perUserLimit.toString();
      _maxUsesCtrl.text = v.maxUses.toString();
      _type = v.discountType;
      _appliesTo = v.appliesTo;
      _expiryDate = v.expiryDate;
      _firstTimeOnly = v.firstTimeOnly;
      _isActive = v.isActive;
      _productIds.addAll(v.productIds);
      _categoryIds.addAll(v.categoryIds);
    } else {
      _perUserCtrl.text = '1';
      _maxUsesCtrl.text = '100';
      _expiryDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _minCtrl.dispose();
    _perUserCtrl.dispose();
    _maxUsesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: AppLocalizations.of(context).voucherExpiry,
    );
    if (picked == null) return;
    setState(() {
      // Valid for the whole of the chosen day.
      _expiryDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    });
  }

  Future<void> _save() async {
    final result = const VoucherValidator().validate(
      code: _codeCtrl.text,
      discountType: _type,
      discountValue: double.tryParse(_valueCtrl.text.trim()) ?? 0,
      minOrderAmt: double.tryParse(_minCtrl.text.trim()) ?? 0,
      perUserLimit: int.tryParse(_perUserCtrl.text.trim()) ?? 0,
      maxUses: int.tryParse(_maxUsesCtrl.text.trim()) ?? 0,
      appliesTo: _appliesTo,
      productIds: _productIds.toList(),
      categoryIds: _categoryIds.toList(),
      existingCodes: widget.existingCodes,
      expiryDate: _expiryDate,
    );

    if (!result.isValid) {
      setState(() => _errors = result.errors);
      return;
    }

    setState(() {
      _errors = const <String, String>{};
      _saving = true;
    });

    final base =
        widget.voucher ??
        Voucher(id: '', companyId: widget.companyId, code: '');
    final voucher = base.copyWith(
      code: Voucher.normalizeCode(_codeCtrl.text),
      companyId: widget.companyId,
      discountType: _type,
      discountValue: _type == VoucherType.freeShipping
          ? 0
          : (double.tryParse(_valueCtrl.text.trim()) ?? 0),
      minOrderAmt: double.tryParse(_minCtrl.text.trim()) ?? 0,
      perUserLimit: int.tryParse(_perUserCtrl.text.trim()) ?? 1,
      maxUses: int.tryParse(_maxUsesCtrl.text.trim()) ?? 0,
      appliesTo: _appliesTo,
      productIds: _appliesTo == VoucherScope.specificProduct
          ? _productIds.toList()
          : const <String>[],
      categoryIds: _appliesTo == VoucherScope.specificCategory
          ? _categoryIds.toList()
          : const <String>[],
      expiryDate: _expiryDate,
      firstTimeOnly: _firstTimeOnly,
      isActive: _isActive,
    );

    try {
      await repo.saveVoucher(voucher);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? AppLocalizations.of(
                    context,
                  ).voucherUpdated(voucher.normalizedCode)
                : AppLocalizations.of(
                    context,
                  ).voucherCreated(voucher.normalizedCode),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotSaveVoucher('$e')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit
                  ? AppLocalizations.of(context).editVoucher2
                  : AppLocalizations.of(context).createVoucher2,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('voucher-code-field'),
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).code,
                hintText: AppLocalizations.of(context).welcome20,
                errorText: _errors['code'],
                helperText: AppLocalizations.of(context).lettersAndNumbersOnly,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).discountType,
              ),
              items: [
                for (final type in VoucherType.values)
                  DropdownMenuItem<String>(
                    value: type,
                    child: Text(VoucherType.label(type)),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            if (_type != VoucherType.freeShipping) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('voucher-value-field'),
                controller: _valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _type == VoucherType.percentage
                      ? AppLocalizations.of(context).discount3
                      : AppLocalizations.of(context).discountAmount,
                  errorText: _errors['discountValue'],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('voucher-min-field'),
              controller: _minCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).minimumOrderAmount,
                errorText: _errors['minOrderAmt'],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('voucher-per-user-field'),
                    controller: _perUserCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).perShopperLimit,
                      errorText: _errors['perUserLimit'],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('voucher-max-uses-field'),
                    controller: _maxUsesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).totalRedemptions,
                      errorText: _errors['maxUses'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _appliesTo,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).appliesTo,
              ),
              items: [
                for (final scope in VoucherScope.values)
                  DropdownMenuItem<String>(
                    value: scope,
                    child: Text(VoucherScope.label(scope)),
                  ),
              ],
              onChanged: (v) => setState(() => _appliesTo = v ?? _appliesTo),
            ),
            if (_appliesTo == VoucherScope.specificCategory)
              _CategoryPicker(
                key: const Key('voucher-category-picker'),
                companyId: widget.companyId,
                selected: _categoryIds,
                error: _errors['categoryIds'],
                onChanged: (ids) => setState(() {
                  _categoryIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
            if (_appliesTo == VoucherScope.specificProduct)
              _ProductPicker(
                key: const Key('voucher-product-picker'),
                companyId: widget.companyId,
                selected: _productIds,
                error: _errors['productIds'],
                onChanged: (ids) => setState(() {
                  _productIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(AppLocalizations.of(context).expiryDate),
              subtitle: Text(
                _expiryDate == null
                    ? AppLocalizations.of(context).noExpiry
                    : DateFormat(
                        AppLocalizations.of(context).ddMmmYyyy,
                      ).format(_expiryDate!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_expiryDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: AppLocalizations.of(context).noExpiry,
                      onPressed: () => setState(() => _expiryDate = null),
                    ),
                  TextButton(
                    onPressed: _pickExpiry,
                    child: Text(AppLocalizations.of(context).pick),
                  ),
                ],
              ),
            ),
            if (_errors['expiryDate'] != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  _errors['expiryDate']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).firstOrderOnly),
              subtitle: Text(
                AppLocalizations.of(context).onlyShoppersWithoutAPreviousOrder,
              ),
              value: _firstTimeOnly,
              onChanged: (v) => setState(() => _firstTimeOnly = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).active),
              subtitle: Text(
                AppLocalizations.of(context).pauseInsteadOfDeletingACampaign,
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('voucher-save-button'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEdit
                          ? AppLocalizations.of(context).saveChanges2
                          : AppLocalizations.of(context).createVoucher,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select chip list of the store's categories.
class _CategoryPicker extends StatefulWidget {
  final String companyId;
  final Set<String> selected;
  final String? error;
  final ValueChanged<Set<String>> onChanged;

  const _CategoryPicker({
    super.key,
    required this.companyId,
    required this.selected,
    required this.onChanged,
    this.error,
  });

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  late final Set<String> _selected = <String>{...widget.selected};

  void _toggle(String id, bool value) {
    setState(() {
      if (value) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).categories,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<Category>>(
            stream: repo.categories(companyId: widget.companyId),
            builder: (context, snap) {
              final list = snap.data ?? const <Category>[];
              if (list.isEmpty) {
                return Text(
                  AppLocalizations.of(context).noCategoriesFoundForThisStore,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                );
              }
              return Wrap(
                spacing: 6,
                children: [
                  for (final c in list)
                    FilterChip(
                      label: Text(c.name),
                      selected: _selected.contains(c.id),
                      onSelected: (value) => _toggle(c.id, value),
                    ),
                ],
              );
            },
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                widget.error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-select chip list of the store's products.
class _ProductPicker extends StatefulWidget {
  final String companyId;
  final Set<String> selected;
  final String? error;
  final ValueChanged<Set<String>> onChanged;

  const _ProductPicker({
    super.key,
    required this.companyId,
    required this.selected,
    required this.onChanged,
    this.error,
  });

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  late final Set<String> _selected = <String>{...widget.selected};

  void _toggle(String id, bool value) {
    setState(() {
      if (value) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).products,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<Product>>(
            stream: repo.products(companyId: widget.companyId),
            builder: (context, snap) {
              final list = snap.data ?? const <Product>[];
              if (list.isEmpty) {
                return Text(
                  AppLocalizations.of(context).noProductsFoundForThisStore,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                );
              }
              return Wrap(
                spacing: 6,
                children: [
                  for (final p in list)
                    FilterChip(
                      label: Text(p.name),
                      selected: _selected.contains(p.id),
                      onSelected: (value) => _toggle(p.id, value),
                    ),
                ],
              );
            },
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                widget.error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

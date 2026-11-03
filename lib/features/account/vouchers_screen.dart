import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myshop/core/widgets/app_toast.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/voucher.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/replay_stream_builder.dart';
import '../../core/widgets/voucher_target_line.dart';

/// Every voucher a shopper can use right now, across shops — opened from the
/// Vouchers card in Settings. Each shows its shop and what it applies to.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  late final Stream<List<Voucher>> _vouchers = repo.vouchers('');

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.account);
    }
  }

  void _copy(Voucher v) {
    Clipboard.setData(ClipboardData(text: v.code));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showAppToast(
        SnackBar(
          content: Text(l10n.voucherCopiedToClipboard(v.code)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(l10n.vouchers),
      ),
      body: ReplayStreamBuilder<List<Voucher>>(
        stream: _vouchers,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
              key: Key('vouchers-loading'),
              child: CircularProgressIndicator(),
            );
          }
          final now = DateTime.now();
          final list = (snap.data ?? const <Voucher>[])
              .where((v) => v.isLiveAt(now) && !v.isExhausted)
              .toList();
          if (list.isEmpty) {
            return Center(
              key: const Key('vouchers-empty'),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.vouchersEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }
          return ListView.separated(
            key: const Key('vouchers-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _tile(context, list[i]),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Voucher v) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final expiry = v.expiryDate;
    final conditions = <String>[
      if (v.minOrderAmt > 0) l10n.minOrder3(v.minOrderAmt.toStringAsFixed(0)),
      if (v.firstTimeOnly) l10n.firstOrderOnly,
      if (v.minOrderAmt <= 0 && !v.firstTimeOnly) l10n.onAllOrders,
      if (expiry != null)
        l10n.voucherValidTill(DateFormat('dd MMM yyyy').format(expiry)),
    ];
    return Card(
      key: Key('voucher-tile-${v.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: Color(0xFFFF5247),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.discountLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  VoucherTargetLine(
                    voucher: v,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v.code,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFFF5247),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conditions.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              key: Key('voucher-copy-${v.id}'),
              onPressed: () => _copy(v),
              child: Text(l10n.copy),
            ),
          ],
        ),
      ),
    );
  }
}

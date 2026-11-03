import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/app_localizations.dart';
import '../../app/routes/app_router.dart';
import '../../core/models/order.dart';
import '../../core/models/voucher.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/auth_guard.dart';
import '../checkout/cart/wishlist_cubit.dart';

/// The three cards at the top of Settings: Orders, Vouchers, Saved.
///
/// Each shows a live count and opens the matching screen:
///  * Orders   – how many orders the signed-in shopper has placed → Orders tab;
///  * Vouchers – how many vouchers can be used right now → Vouchers list;
///  * Saved    – how many products are liked → Liked products.
/// A count is "—" until it is known, or when it needs a login the shopper has
/// not done.
class AccountStatCards extends StatefulWidget {
  const AccountStatCards({super.key, required this.userId});

  /// The signed-in shopper, or null for a guest.
  final String? userId;

  @override
  State<AccountStatCards> createState() => _AccountStatCardsState();
}

class _AccountStatCardsState extends State<AccountStatCards> {
  // Opened once (per account), not on every rebuild of Settings.
  late final Stream<List<Voucher>> _vouchers = repo.vouchers('');
  String? _ordersFor;
  Stream<List<Order>>? _orders;

  Stream<List<Order>>? _ordersStream() {
    final id = widget.userId;
    if (id == null || id.isEmpty) {
      _ordersFor = null;
      _orders = null;
      return null;
    }
    if (_ordersFor != id) {
      _ordersFor = id;
      _orders = repo.orders(userId: id);
    }
    return _orders;
  }

  Widget _card(
    BuildContext context, {
    required Key key,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F2F5)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.03),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                key: Key('${key.toString()}-value'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2229),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersStream = _ordersStream();

    String liked = '—';
    try {
      final state = context.watch<WishlistCubit>().state;
      if (widget.userId != null && state.loaded) liked = '${state.count}';
    } catch (_) {}

    return Row(
      children: [
        // Orders: the shopper's own orders.
        StreamBuilder<List<Order>>(
          stream: ordersStream,
          builder: (context, snap) {
            final count = snap.hasData ? '${snap.data!.length}' : '—';
            return _card(
              context,
              key: const Key('stat-orders'),
              label: l10n.orders,
              value: ordersStream == null ? '—' : count,
              onTap: () => AuthGuard.runWithAuth(
                context,
                message: 'Please log in to view your orders.',
                onAuthenticated: () => context.go(AppRoutes.orders),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        // Vouchers: every voucher that can be used right now.
        StreamBuilder<List<Voucher>>(
          stream: _vouchers,
          builder: (context, snap) {
            final now = DateTime.now();
            final count = snap.hasData
                ? '${snap.data!.where((v) => v.isLiveAt(now) && !v.isExhausted).length}'
                : '—';
            return _card(
              context,
              key: const Key('stat-vouchers'),
              label: l10n.vouchers,
              value: count,
              onTap: () => context.push(AppRoutes.vouchers),
            );
          },
        ),
        const SizedBox(width: 10),
        // Saved: liked products.
        _card(
          context,
          key: const Key('stat-saved'),
          label: 'Saved',
          value: liked,
          onTap: () => AuthGuard.runWithAuth(
            context,
            message: l10n.favLoginRequired,
            onAuthenticated: () => context.push(AppRoutes.favorites),
          ),
        ),
      ],
    );
  }
}

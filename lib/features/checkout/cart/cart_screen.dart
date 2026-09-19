import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/company.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import 'cart_cubit.dart';

/// Cart grouped by company (Section 3 / multi-company cart support).
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cart)),
      body: BlocBuilder<CartCubit, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64),
                  const SizedBox(height: 12),
                  const Text('Your cart is empty'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(l10n.home),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final entry in state.byCompany.entries) ...[
                      _companyHeader(entry.key),
                      for (final item in entry.value)
                        _cartTile(context, item, entry.key),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              _checkoutBar(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _companyHeader(String companyId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: StreamBuilder<List<Company>>(
        stream: repo.companies(),
        builder: (context, snapshot) {
          final companies = snapshot.data ?? [];
          final comp = companies.where((c) => c.id == companyId).firstOrNull;
          final name = (comp != null && comp.name.isNotEmpty)
              ? comp.name
              : (companyId.isEmpty ? 'Store' : 'Store');
          return Row(
            children: [
              const Icon(Icons.storefront, size: 18),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cartTile(BuildContext context, CartItem item, String companyId) {
    final cubit = context.read<CartCubit>();
    // Do not let a shopper increase a line past the available stock.
    final maxQty = item.product.isUnlimitedStock ? 99 : item.product.stockQty;
    final canAdd = item.qty < (maxQty < 1 ? 1 : maxQty);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.image)),
        title: Text(item.product.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCurrency(item.lineTotal, symbol: '₹'),
            ),
            if (!item.product.isInStock)
              const Text(
                'Out of stock',
                style: TextStyle(fontSize: 11, color: Colors.redAccent),
              )
            else if (item.product.isLowStock())
              Text(
                'Only ${item.product.stockQty} left',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => cubit.decrement(companyId, item.product.id),
            ),
            Text(
              '${item.qty}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: canAdd ? 'Add one' : 'No more stock',
              onPressed: canAdd
                  ? () => cubit.increment(companyId, item.product.id)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => cubit.remove(companyId, item.product.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkoutBar(BuildContext context, CartState state) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        color: Colors.white,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.totalAmount,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    formatCurrency(state.totalAmount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => context.go(AppRoutes.checkout),
              child: Text(l10n.checkout),
            ),
          ],
        ),
      ),
    );
  }
}

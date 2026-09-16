import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../checkout/cart/cart_cubit.dart';

/// Product Detail Page (Section 17.3): gallery, variants, voucher hint and a
/// persistent add-to-cart / buy-now bar.
class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Product? _product;
  Company? _company;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await repo.product(widget.productId);
    Company? c;
    if (p != null) {
      final companies = await repo.companies().first;
      c = companies.where((e) => e.id == p.companyId).firstOrNull;
    }
    if (mounted) {
      setState(() {
        _product = p;
        _company = c;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _product!;
    final symbol = _company?.currencySymbol ?? '₹';
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _gallery(p),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${p.unit} ${p.unitType}',
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(formatCurrency(p.price, symbol: symbol),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          if (p.isDiscounted) ...[
                            const SizedBox(width: 8),
                            Text(formatCurrency(p.amount, symbol: symbol),
                                style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey)),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                  '${p.discountPercent.toStringAsFixed(0)}% OFF'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(p.details),
                      if (p.subDetails.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(p.subDetails,
                            style: const TextStyle(color: Colors.grey)),
                      ],
                      if (p.variants.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('Variants',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: p.variants
                              .map((v) => ChoiceChip(
                                    label: Text('${v.color} · ${v.sku}'),
                                    selected: false,
                                    onSelected: (_) {},
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text('Stock: ${p.stockQty} ${p.unitType}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _bottomBar(p, symbol),
        ],
      ),
    );
  }

  Widget _gallery(Product p) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 260,
      color: scheme.primaryContainer.withOpacity(0.3),
      child: Center(
        child: Icon(Icons.image_outlined, size: 72, color: scheme.primary),
      ),
    );
  }

  Widget _bottomBar(Product p, String symbol) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _qtyPicker(),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  for (var i = 0; i < _qty; i++) {
                    context.read<CartCubit>().add(p, company: _company);
                  }
                },
                child: Text(l10n.addToCart),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  context.read<CartCubit>().add(p, company: _company);
                  context.go(AppRoutes.cart);
                },
                child: Text(l10n.buyNow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyPicker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => setState(() {
                    if (_qty > 1) _qty--;
                  })),
          Text('$_qty', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _qty++)),
        ],
      ),
    );
  }
}

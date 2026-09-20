import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/product.dart';
import '../../../core/services/service_locator.dart';
import '../../marketplace/widgets/product_card.dart';

/// Keyword product search (server-side indexing via Algolia/Typesense is a
/// recommended enhancement — Section 21).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: _query.isEmpty
          ? const Center(child: Text('Type to search'))
          : StreamBuilder<List<Product>>(
              stream: repo.products(search: _query),
              builder: (context, snap) {
                final list = snap.data ?? const <Product>[];
                if (list.isEmpty) {
                  return const Center(child: Text('No results'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) => ProductCard(
                    product: list[i],
                    onTap: () =>
                        context.push(AppRoutes.productPath(list[i].id)),
                  ),
                );
              },
            ),
    );
  }
}

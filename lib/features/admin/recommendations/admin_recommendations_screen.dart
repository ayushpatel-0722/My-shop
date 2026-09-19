import '../../../app/routes/app_router.dart';
import 'package:flutter/material.dart';

import '../../../core/models/recommendation.dart';
import '../../../core/services/service_locator.dart';
import '../admin_shell.dart';

/// Recommended products manager — pin a product, else auto best-seller
/// fallback (Section 13.3).
class AdminRecommendationsScreen extends StatelessWidget {
  const AdminRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'Recommendations',
      actions: [
        IconButton(
          icon: const Icon(Icons.push_pin),
          onPressed: () => _showPinSheet(context),
        ),
      ],
      child: StreamBuilder<List<Recommendation>>(
        stream: repo.recommendationRecords(),
        builder: (context, snap) {
          final list = snap.data ?? const <Recommendation>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.auto_awesome),
                  title: Text('Fallback strategy'),
                  subtitle: Text(
                    'Top Sellers · Trending · Curated · Cross-sell',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No pinned recommendations — using best-sellers',
                    ),
                  ),
                ),
              for (final r in list)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.push_pin),
                    title: Text(r.pinnedProductId ?? '(no pinned product)'),
                    subtitle: Text(r.strategy),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showPinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PinProductSheet(),
    );
  }
}

class _PinProductSheet extends StatefulWidget {
  const _PinProductSheet();

  @override
  State<_PinProductSheet> createState() => _PinProductSheetState();
}

class _PinProductSheetState extends State<_PinProductSheet> {
  final _productIdCtrl = TextEditingController();
  String _strategy = 'curated';

  @override
  void dispose() {
    _productIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pin a product',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _productIdCtrl,
            decoration: const InputDecoration(labelText: 'Product ID'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _strategy,
            decoration: const InputDecoration(labelText: 'Strategy'),
            items: const [
              DropdownMenuItem(value: 'curated', child: Text('Curated')),
              DropdownMenuItem(
                value: 'top_sellers',
                child: Text('Top sellers'),
              ),
              DropdownMenuItem(value: 'trending', child: Text('Trending')),
              DropdownMenuItem(value: 'cross_sell', child: Text('Cross-sell')),
            ],
            onChanged: (v) => setState(() => _strategy = v ?? 'curated'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              repo.saveRecommendation(
                Recommendation(
                  id: '',
                  pinnedProductId: _productIdCtrl.text.trim(),
                  strategy: _strategy,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

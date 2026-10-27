import 'package:flutter/material.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

import '../../../app/routes/app_router.dart';
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
      title: AppLocalizations.of(context).recommendations,
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(AppLocalizations.of(context).fallbackStrategy),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    ).topSellersTrendingCuratedCrossSell,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).noPinnedRecommendationsUsingBestSellers,
                    ),
                  ),
                ),
              for (final r in list)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.push_pin),
                    title: Text(
                      r.pinnedProductId ??
                          AppLocalizations.of(context).noPinnedProduct,
                    ),
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
          Text(
            AppLocalizations.of(context).pinAProduct,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _productIdCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).productId,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _strategy,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).strategy,
            ),
            items: [
              DropdownMenuItem(
                value: 'curated',
                child: Text(AppLocalizations.of(context).curated),
              ),
              DropdownMenuItem(
                value: 'top_sellers',
                child: Text(AppLocalizations.of(context).topSellers),
              ),
              DropdownMenuItem(
                value: 'trending',
                child: Text(AppLocalizations.of(context).trending),
              ),
              DropdownMenuItem(
                value: 'cross_sell',
                child: Text(AppLocalizations.of(context).crossSell),
              ),
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
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }
}

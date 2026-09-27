import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/services/service_locator.dart';

/// Packing manifest (Section 17.2): barcode/SKU validation and a big
/// "Packing Done" button that sets employeePackingDone only.
class PackingScreen extends StatefulWidget {
  final String orderId;
  const PackingScreen({super.key, required this.orderId});

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  final Set<String> _scanned = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).manifest('${l10n.packing}'))),
      body: StreamBuilder<Order?>(
        // Single-order stream: no need to pull the whole company (or the
        // whole platform) just to render one manifest.
        stream: repo.watchOrder(widget.orderId),
        builder: (context, snap) {
          final order = snap.data;
          if (order == null) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(child: Text(AppLocalizations.of(context).orderNotFound));
          }
          return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    order.reference,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in order.items)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                _scanned.contains(item.productId)
                                    ? Icons.check_circle
                                    : Icons.qr_code_scanner,
                                color: _scanned.contains(item.productId)
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              title: Text(
                                item.name.isNotEmpty ? item.name : item.productId,
                              ),
                              subtitle: Text(AppLocalizations.of(context).qtySkuScan('${item.qty}')),
                              trailing: TextButton(
                                onPressed: () async {
                                  final result = await context.push<String>(
                                    AppRoutes.qrScanner,
                                  );
                                  if (result != null && mounted) {
                                    setState(() => _scanned.add(result));
                                  }
                                },
                                child: Text(AppLocalizations.of(context).scan),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: order.employeePackingDone
                        ? null
                        : () async {
                            await repo.setEmployeePackingDone(order.id, true);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context).packingDoneNotifiedAdmin),
                              ),
                            );
                            context.go(AppRoutes.employeeHome);
                          },
                    icon: Icon(
                      order.employeePackingDone ? Icons.check : Icons.inventory,
                    ),
                    label: Text(
                      order.employeePackingDone
                          ? AppLocalizations.of(context).sentToAdmin
                          : AppLocalizations.of(context).packingDone,
                    ),
                  ),
                ],
              ),
          );
        },
      ),
    );
  }
}

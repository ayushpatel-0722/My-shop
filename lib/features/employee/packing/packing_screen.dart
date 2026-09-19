import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
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
  Order? _order;
  final Set<String> _scanned = {};

  @override
  void initState() {
    super.initState();
    repo.orders().listen((list) {
      final o = list.where((e) => e.id == widget.orderId).firstOrNull;
      if (mounted) setState(() => _order = o);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = _order;
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.packing} Manifest')),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '#${order.id.substring(0, 6).toUpperCase()}',
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
                              title: Text(item.name),
                              subtitle: Text('Qty: ${item.qty} · SKU scan'),
                              trailing: TextButton(
                                onPressed: () async {
                                  final result = await context.push<String>(
                                    AppRoutes.qrScanner,
                                  );
                                  if (result != null && mounted) {
                                    setState(() => _scanned.add(result));
                                  }
                                },
                                child: const Text('Scan'),
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
                              const SnackBar(
                                content: Text('Packing done — notified Admin'),
                              ),
                            );
                            context.go(AppRoutes.employeeHome);
                          },
                    icon: Icon(
                      order.employeePackingDone ? Icons.check : Icons.inventory,
                    ),
                    label: Text(
                      order.employeePackingDone
                          ? 'Sent to Admin'
                          : 'Packing Done',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

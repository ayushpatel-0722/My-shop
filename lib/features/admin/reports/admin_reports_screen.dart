import '../../../app/routes/app_router.dart';
import 'package:flutter/material.dart';

import '../../../core/models/order.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../admin_shell.dart';
import 'package:myshop/app/l10n/app_localizations.dart';

/// Reports centre — generate & download Excel (.xlsx), Word (.docx) and PDF
/// reports (Section 17.1 / Section 2.2).
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reports used to sum every company on the platform.
    final companyId = AuthSession.currentUser?.companyId ?? '';
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: AppLocalizations.of(context).reports,
      child: StreamBuilder<List<Order>>(
        stream: repo.orders(companyId: companyId),
        builder: (context, snap) {
          final orders = snap.data ?? const <Order>[];
          final revenue = orders.fold(0.0, (s, o) => s + o.totalAmount);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).summary,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).orders2('${orders.length}'),
                      ),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).revenue(revenue.toStringAsFixed(2)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.grid_on),
                      title: Text(
                        AppLocalizations.of(context).monthlyOrderReport,
                      ),
                      subtitle: Text(AppLocalizations.of(context).excelXlsx),
                      trailing: const Icon(Icons.download),
                      onTap: () => _exportExcel(
                        context,
                        orders,
                        AppLocalizations.of(context).monthly,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.grid_on),
                      title: Text(
                        AppLocalizations.of(context).yearlyOrderReport,
                      ),
                      subtitle: Text(AppLocalizations.of(context).excelXlsx),
                      trailing: const Icon(Icons.download),
                      onTap: () => _exportExcel(
                        context,
                        orders,
                        AppLocalizations.of(context).yearly,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.article),
                      title: Text(
                        AppLocalizations.of(context).exportCatalogSheet,
                      ),
                      subtitle: Text(AppLocalizations.of(context).wordDocx),
                      trailing: const Icon(Icons.download),
                      onTap: () => _exportWord(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf),
                      title: Text(
                        AppLocalizations.of(context).latestInvoicePdf,
                      ),
                      subtitle: Text(AppLocalizations.of(context).pdf),
                      trailing: const Icon(Icons.download),
                      onTap: () => _exportPdf(context, orders),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportExcel(
    BuildContext context,
    List<Order> orders,
    String period,
  ) async {
    final bytes = reports.buildOrderReportExcel(
      orders,
      AppLocalizations.of(context).orderReport(period),
    );
    final stamp = DateTime.now().toIso8601String().split('T').first;
    await reports.saveExcel(bytes, 'orders_${period.toLowerCase()}_$stamp');
  }

  Future<void> _exportWord(BuildContext context) async {
    final companyId = AuthSession.currentUser?.companyId ?? '';
    final products = await repo.products(companyId: companyId).first;
    final bytes = await reports.buildCatalogDoc(products);
    await reports.saveWord(bytes, 'catalog_sheet');
  }

  Future<void> _exportPdf(BuildContext context, List<Order> orders) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).noOrdersToInvoiceYet),
        ),
      );
      return;
    }
    final bytes = await reports.buildInvoicePdf(orders.first);
    await reports.savePdf(bytes, 'invoice_${orders.first.id}');
  }
}

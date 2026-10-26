import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/models/order.dart';
import '../../../core/models/report_date_range.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/order_status_badge.dart';
import '../admin_shell.dart';

/// Reports centre — date filtering (7 presets + custom range), real-time KPI
/// calculations, and one-click downloads in Excel (.xlsx), CSV (.csv), and PDF (.pdf).
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  ReportDateRange _dateRange = ReportDateRange.fromPreset(
    ReportDatePreset.last30Days,
  );
  bool _isExporting = false;
  String? _exportingType;

  String get _companyId => AuthSession.currentUser?.companyId ?? '';
  String get _companyName => AuthSession.currentUser?.companyName ?? '';

  Future<void> _handlePresetSelection(ReportDatePreset preset) async {
    if (preset == ReportDatePreset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        initialDateRange: DateTimeRange(
          start: _dateRange.startDate,
          end: _dateRange.endDate,
        ),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF1E8F66),
                onPrimary: Colors.white,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );

      if (picked != null) {
        setState(() {
          _dateRange = ReportDateRange.custom(picked.start, picked.end);
        });
      }
    } else {
      setState(() {
        _dateRange = ReportDateRange.fromPreset(preset);
      });
    }
  }

  Future<void> _exportReport(String type, List<Order> orders) async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
      _exportingType = type;
    });

    try {
      final rangeSlug = _dateRange.fileDateSlug;
      final companyName = _companyName.isNotEmpty
          ? _companyName
          : 'Store Admin';
      final rangeLabel = _dateRange.formattedRange;

      if (type == 'excel') {
        final bytes = reports.buildOrderReportExcel(
          orders,
          'Orders Report',
          companyName: companyName,
          dateRangeLabel: rangeLabel,
        );
        final fileName = 'orders_report_$rangeSlug';
        final result = await reports.saveExcel(bytes, fileName);
        _handleExportResult(result, 'Excel report (.xlsx)');
      } else if (type == 'csv') {
        final bytes = reports.buildOrderReportCsv(
          orders,
          title: 'Orders Report',
          companyName: companyName,
          dateRangeLabel: rangeLabel,
        );
        final fileName = 'orders_report_$rangeSlug';
        final result = await reports.saveCsv(bytes, fileName);
        _handleExportResult(result, 'CSV report (.csv)');
      } else if (type == 'pdf') {
        final bytes = await reports.buildOrdersReportPdf(
          orders: orders,
          companyName: companyName,
          dateRangeLabel: rangeLabel,
        );
        final fileName = 'orders_report_$rangeSlug';
        final result = await reports.savePdf(bytes, fileName);
        _handleExportResult(result, 'PDF report (.pdf)');
      } else if (type == 'word') {
        final products = await repo.products(companyId: _companyId).first;
        final bytes = await reports.buildCatalogDoc(products);
        final stamp = DateTime.now().toIso8601String().split('T').first;
        final fileName = 'catalog_sheet_$stamp';
        final result = await reports.saveWord(bytes, fileName);
        _handleExportResult(result, 'Product catalog (.docx)');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportingType = null;
        });
      }
    }
  }

  void _handleExportResult(dynamic result, String label) {
    if (!mounted) return;
    if (result.canceled == true) {
      // User canceled the file picker - no error snackbar needed
      return;
    }
    if (result.success == true) {
      final savedPath = result.path != null && result.path!.isNotEmpty
          ? ' Saved to: ${result.path}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('$label saved successfully!$savedPath')),
            ],
          ),
          backgroundColor: const Color(0xFF1E8F66),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save $label: ${result.error ?? "Unknown error"}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: l10n.reports,
      child: StreamBuilder<List<Order>>(
        stream: repo.orders(companyId: _companyId),
        builder: (context, snap) {
          final allOrders = snap.data ?? const <Order>[];

          // Filter orders by active date range
          final filteredOrders = allOrders
              .where((o) => _dateRange.contains(o.createdAt))
              .toList();

          // Metrics calculation
          final totalOrderValue = filteredOrders.fold<double>(
            0.0,
            (sum, o) => sum + o.totalAmount,
          );
          final paymentsReceived = filteredOrders
              .where((o) => o.paymentStatus == PaymentStatus.done)
              .fold<double>(
                0.0,
                (sum, o) => sum + (o.amountPaid ?? o.totalAmount),
              );
          final paidOrdersCount = filteredOrders
              .where((o) => o.paymentStatus == PaymentStatus.done)
              .length;
          final completedOrdersCount = filteredOrders
              .where((o) => o.orderStatus == OrderStatus.completed)
              .length;
          final cancelledOrdersCount = filteredOrders
              .where((o) => o.orderStatus == OrderStatus.cancelled)
              .length;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Header & Subtitle
              Text(
                'Business & Sales Reports',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Filter orders by date, review verified revenue, and download reports.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Date Range Filter Chips (7 Presets + Custom)
              _buildPresetFilterChips(theme),
              const SizedBox(height: 14),

              // Active Date Range Banner
              _buildActiveRangeBanner(theme, filteredOrders.length),
              const SizedBox(height: 16),

              // 4 Key Metric Summary Cards
              _buildSummaryCards(
                theme: theme,
                totalOrders: filteredOrders.length,
                totalOrderValue: totalOrderValue,
                paymentsReceived: paymentsReceived,
                paidCount: paidOrdersCount,
                completedCount: completedOrdersCount,
                cancelledCount: cancelledOrdersCount,
              ),
              const SizedBox(height: 20),

              // Download & Export Section
              _buildExportOptionsSection(
                theme: theme,
                filteredOrders: filteredOrders,
              ),
              const SizedBox(height: 24),

              // Filtered Orders Breakdown List
              _buildOrdersBreakdownHeader(theme, filteredOrders.length),
              const SizedBox(height: 8),

              if (filteredOrders.isEmpty)
                _buildEmptyOrdersState(theme)
              else
                ...filteredOrders.map(
                  (order) => _buildOrderItemCard(theme, order),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportDatePreset.values.map((preset) {
          final isSelected = _dateRange.preset == preset;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(preset.label),
              selected: isSelected,
              selectedColor: const Color(0xFF1E8F66),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              avatar: preset == ReportDatePreset.custom
                  ? Icon(
                      Icons.date_range,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
              onSelected: (_) => _handlePresetSelection(preset),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveRangeBanner(ThemeData theme, int orderCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E8F66).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF1E8F66).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E8F66).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: Color(0xFF1E8F66),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Filter: ${_dateRange.label}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF1E8F66),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _dateRange.formattedRange,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E8F66),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$orderCount ${orderCount == 1 ? "Order" : "Orders"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards({
    required ThemeData theme,
    required int totalOrders,
    required double totalOrderValue,
    required double paymentsReceived,
    required int paidCount,
    required int completedCount,
    required int cancelledCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final card1 = _buildMetricCard(
          theme: theme,
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF2563EB),
          bgColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
          label: 'Total Orders',
          value: '$totalOrders',
          subtitle: 'Orders placed in period',
        );

        final card2 = _buildMetricCard(
          theme: theme,
          icon: Icons.shopping_bag_outlined,
          iconColor: const Color(0xFF7C3AED),
          bgColor: const Color(0xFF7C3AED).withValues(alpha: 0.08),
          label: 'Total Order Value',
          value: formatCurrency(totalOrderValue),
          subtitle: 'Gross sales value',
        );

        final card3 = _buildMetricCard(
          theme: theme,
          icon: Icons.verified_rounded,
          iconColor: const Color(0xFF1E8F66),
          bgColor: const Color(0xFF1E8F66).withValues(alpha: 0.08),
          label: 'Actual Revenue',
          value: formatCurrency(paymentsReceived),
          subtitle: '$paidCount paid transactions',
        );

        final card4 = _buildMetricCard(
          theme: theme,
          icon: Icons.pie_chart_outline_rounded,
          iconColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFD97706).withValues(alpha: 0.08),
          label: 'Completed / Cancelled',
          value: '$completedCount / $cancelledCount',
          subtitle: '$completedCount completed, $cancelledCount cancelled',
        );

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 12),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 12),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 12),
              Expanded(child: card2),
              const SizedBox(width: 12),
              Expanded(child: card3),
              const SizedBox(width: 12),
              Expanded(child: card4),
            ],
          );
        }
      },
    );
  }

  Widget _buildMetricCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    final isDesktop = context.isDesktop;
    return ModernCard(
      padding: EdgeInsets.all(isDesktop ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 8 : 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: isDesktop ? 22 : 20, color: iconColor),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: isDesktop ? 13.5 : 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isDesktop ? 22 : 17,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: isDesktop ? 12.5 : 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptionsSection({
    required ThemeData theme,
    required List<Order> filteredOrders,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Download Reports',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isExporting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Export filtered data for ${_dateRange.formattedRange}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            final btnExcel = _buildExportCard(
              theme: theme,
              icon: Icons.table_chart_rounded,
              iconColor: const Color(0xFF1E8F66),
              badge: '.XLSX',
              title: 'Orders Report (Excel)',
              subtitle: 'KPIs & formatted line items',
              type: 'excel',
              orders: filteredOrders,
            );

            final btnCsv = _buildExportCard(
              theme: theme,
              icon: Icons.grid_on_rounded,
              iconColor: const Color(0xFF2563EB),
              badge: '.CSV',
              title: 'Orders Report (CSV)',
              subtitle: 'Universal raw data table',
              type: 'csv',
              orders: filteredOrders,
            );

            final btnPdf = _buildExportCard(
              theme: theme,
              icon: Icons.picture_as_pdf_rounded,
              iconColor: const Color(0xFFDC2626),
              badge: '.PDF',
              title: 'Summary Report (PDF)',
              subtitle: 'Branded printable report',
              type: 'pdf',
              orders: filteredOrders,
            );

            final btnWord = _buildExportCard(
              theme: theme,
              icon: Icons.article_rounded,
              iconColor: const Color(0xFF7C3AED),
              badge: '.DOCX',
              title: 'Product Catalog (Word)',
              subtitle: 'Full store catalogue sheet',
              type: 'word',
              orders: filteredOrders,
            );

            if (isMobile) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: btnExcel),
                      const SizedBox(width: 10),
                      Expanded(child: btnCsv),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: btnPdf),
                      const SizedBox(width: 10),
                      Expanded(child: btnWord),
                    ],
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: btnExcel),
                  const SizedBox(width: 10),
                  Expanded(child: btnCsv),
                  const SizedBox(width: 10),
                  Expanded(child: btnPdf),
                  const SizedBox(width: 10),
                  Expanded(child: btnWord),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildExportCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String badge,
    required String title,
    required String subtitle,
    required String type,
    required List<Order> orders,
  }) {
    final isCurrentExporting = _isExporting && _exportingType == type;

    return ModernCard(
      padding: const EdgeInsets.all(12),
      onTap: _isExporting ? null : () => _exportReport(type, orders),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: isCurrentExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersBreakdownHeader(ThemeData theme, int orderCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Orders in Period ($orderCount)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyOrdersState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No orders placed in this period',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try selecting another date preset or custom range from the top filter.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(ThemeData theme, Order order) {
    final dateStr = order.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt!)
        : '—';
    final customer = order.customerName.isNotEmpty
        ? order.customerName
        : (order.customerPhone.isNotEmpty
              ? order.customerPhone
              : 'Store Customer');

    final isPaid = order.paymentStatus == PaymentStatus.done;

    return ModernCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.id.length > 10 ? order.id.substring(0, 10) : order.id}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              OrderStatusBadge(status: order.orderStatus),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                customer,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formatCurrency(order.totalAmount),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPaid ? const Color(0xFF1E8F66) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPaid
                      ? const Color(0xFF1E8F66).withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPaid
                        ? const Color(0xFF1E8F66)
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

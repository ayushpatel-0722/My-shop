import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/order.dart';
import '../models/product.dart';

/// Result status of a file save/export operation.
class SaveResult {
  final bool success;
  final String? path;
  final bool canceled;
  final String? error;

  const SaveResult({
    required this.success,
    this.path,
    this.canceled = false,
    this.error,
  });

  const SaveResult.success([this.path])
    : success = true,
      canceled = false,
      error = null;

  const SaveResult.canceled()
    : success = false,
      canceled = true,
      path = null,
      error = null;

  const SaveResult.failure(this.error)
    : success = false,
      canceled = false,
      path = null;

  @override
  String toString() =>
      'SaveResult(success: $success, path: $path, canceled: $canceled, error: $error)';
}

/// Generates downloadable reports (Section 17.1 / Section 2.2):
///   - Excel  (.xlsx) order reports with summary and breakdown
///   - CSV    (.csv)  portable order data export
///   - PDF    (.pdf)  invoice / aggregate orders & revenue reports
///   - Word   (.docx) catalog sheets
class ReportService {
  // --------------------------------------------------------------- Excel ---
  Uint8List buildOrderReportExcel(
    List<Order> orders,
    String title, {
    String companyName = '',
    String dateRangeLabel = '',
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Orders'];

    // Delete default Sheet1 artifact if created
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final totalOrderValue = orders.fold<double>(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );
    final paymentsReceived = orders
        .where((o) => o.paymentStatus == PaymentStatus.done)
        .fold<double>(0.0, (sum, o) => sum + (o.amountPaid ?? o.totalAmount));
    final completedCount = orders
        .where((o) => o.orderStatus == OrderStatus.completed)
        .length;
    final cancelledCount = orders
        .where((o) => o.orderStatus == OrderStatus.cancelled)
        .length;

    // Report Header
    sheet.appendRow([
      TextCellValue(companyName.isNotEmpty ? '$companyName - $title' : title),
    ]);
    if (dateRangeLabel.isNotEmpty) {
      sheet.appendRow([TextCellValue('Period: $dateRangeLabel')]);
    }
    sheet.appendRow([
      TextCellValue(
        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // KPI Summary Section
    sheet.appendRow([TextCellValue('--- SUMMARY METRICS ---')]);
    sheet.appendRow([
      TextCellValue('Total Orders Placed'),
      IntCellValue(orders.length),
    ]);
    sheet.appendRow([
      TextCellValue('Total Order Value (Gross Sales)'),
      DoubleCellValue(totalOrderValue),
    ]);
    sheet.appendRow([
      TextCellValue('Actual Revenue (Payments Received)'),
      DoubleCellValue(paymentsReceived),
    ]);
    sheet.appendRow([
      TextCellValue('Completed Orders'),
      IntCellValue(completedCount),
    ]);
    sheet.appendRow([
      TextCellValue('Cancelled Orders'),
      IntCellValue(cancelledCount),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Orders Table Header
    sheet.appendRow([
      TextCellValue('Order ID'),
      TextCellValue('Date & Time'),
      TextCellValue('Customer Name'),
      TextCellValue('Customer Phone'),
      TextCellValue('Items Count'),
      TextCellValue('Items Summary'),
      TextCellValue('Subtotal (INR)'),
      TextCellValue('Discount (INR)'),
      TextCellValue('Delivery Fee (INR)'),
      TextCellValue('Total Amount (INR)'),
      TextCellValue('Order Status'),
      TextCellValue('Payment Status'),
      TextCellValue('Payment Method'),
    ]);

    // Orders Data Rows
    for (final o in orders) {
      final itemsSummary = o.items
          .map((i) => '${i.name} (x${i.qty})')
          .join('; ');
      sheet.appendRow([
        TextCellValue(o.id),
        TextCellValue(
          o.createdAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(o.createdAt!)
              : '',
        ),
        TextCellValue(o.customerName),
        TextCellValue(o.customerPhone),
        IntCellValue(o.items.length),
        TextCellValue(itemsSummary),
        DoubleCellValue(o.subtotal),
        DoubleCellValue(o.discountAmount),
        DoubleCellValue(o.deliveryCharge),
        DoubleCellValue(o.totalAmount),
        TextCellValue(o.orderStatus),
        TextCellValue(o.paymentStatus),
        TextCellValue(o.paymentMethod),
      ]);
    }

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? const []);
  }

  // ----------------------------------------------------------------- CSV ---
  Uint8List buildOrderReportCsv(
    List<Order> orders, {
    String title = 'Orders Report',
    String companyName = '',
    String dateRangeLabel = '',
  }) {
    final buffer = StringBuffer();

    // Table Header
    buffer.writeln(
      'Order ID,Date & Time,Customer Name,Customer Phone,Items Count,Items Summary,Subtotal (INR),Discount (INR),Delivery Fee (INR),Total (INR),Order Status,Payment Status,Payment Method',
    );

    // Rows
    for (final o in orders) {
      final itemsSummary = o.items
          .map((i) => '${i.name} (x${i.qty})')
          .join('; ');
      final dateStr = o.createdAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(o.createdAt!)
          : '';

      final row = [
        _escapeCsv(o.id),
        _escapeCsv(dateStr),
        _escapeCsv(o.customerName),
        _escapeCsv(o.customerPhone),
        o.items.length.toString(),
        _escapeCsv(itemsSummary),
        o.subtotal.toStringAsFixed(2),
        o.discountAmount.toStringAsFixed(2),
        o.deliveryCharge.toStringAsFixed(2),
        o.totalAmount.toStringAsFixed(2),
        _escapeCsv(o.orderStatus),
        _escapeCsv(o.paymentStatus),
        _escapeCsv(o.paymentMethod),
      ];
      buffer.writeln(row.join(','));
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ----------------------------------------------------------------- Word ---
  Future<Uint8List> buildCatalogDoc(List<Product> products) async {
    final buffer = StringBuffer()
      ..writeln('Catalog Sheet')
      ..writeln(
        'Generated: ${DateTime.now().toIso8601String().split('T').first}',
      )
      ..writeln();

    for (final p in products) {
      buffer
        ..writeln('${p.name}  —  ₹${p.price}  (${p.unit} ${p.unitType})')
        ..writeln(p.details.isEmpty ? 'No description' : p.details)
        ..writeln();
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  // ------------------------------------------------------------------ PDF ---
  /// Builds a comprehensive Orders & Revenue Report in PDF format.
  Future<Uint8List> buildOrdersReportPdf({
    required List<Order> orders,
    required String companyName,
    required String dateRangeLabel,
  }) async {
    final doc = pw.Document();

    final totalOrderValue = orders.fold<double>(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );
    final paymentsReceived = orders
        .where((o) => o.paymentStatus == PaymentStatus.done)
        .fold<double>(0.0, (sum, o) => sum + (o.amountPaid ?? o.totalAmount));
    final completedCount = orders
        .where((o) => o.orderStatus == OrderStatus.completed)
        .length;
    final cancelledCount = orders
        .where((o) => o.orderStatus == OrderStatus.cancelled)
        .length;

    final generatedStr = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(DateTime.now());

    final sanitizedRange = dateRangeLabel
        .replaceAll('–', '-')
        .replaceAll('—', '-');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName.isNotEmpty ? companyName : 'Store Admin',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Orders & Revenue Report',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Period: $sanitizedRange',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Generated: $generatedStr',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Confidential - Internal Use Only',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          // KPI Summary Cards
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildPdfKpi('Total Orders', '${orders.length}'),
                _buildPdfKpi(
                  'Gross Sales',
                  'INR ${totalOrderValue.toStringAsFixed(2)}',
                ),
                _buildPdfKpi(
                  'Payments Received',
                  'INR ${paymentsReceived.toStringAsFixed(2)}',
                  textColor: PdfColors.green800,
                ),
                _buildPdfKpi(
                  'Completed / Cancelled',
                  '$completedCount / $cancelledCount',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Orders Data Table
          pw.Text(
            'Order Breakdown (${orders.length} orders)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),

          if (orders.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'No orders found for the selected date range.',
                style: const pw.TextStyle(color: PdfColors.grey600),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: [
                'Order ID',
                'Date',
                'Customer',
                'Status',
                'Payment',
                'Amount',
              ],
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.indigo700,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              data: orders.map((o) {
                final dateStr = o.createdAt != null
                    ? DateFormat('dd MMM yyyy').format(o.createdAt!)
                    : '-';
                return [
                  o.id.length > 8 ? o.id.substring(0, 8) : o.id,
                  dateStr,
                  o.customerName.isNotEmpty ? o.customerName : '-',
                  o.orderStatus.toUpperCase(),
                  o.paymentStatus.toUpperCase(),
                  'INR ${o.totalAmount.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _buildPdfKpi(
    String label,
    String value, {
    PdfColor textColor = PdfColors.grey900,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Save ---
  /// Universal cross-platform file saving.
  /// Uses [FileSaver.instance.saveFile] on Web, and [FileSaver.instance.saveAs]
  /// on Mobile/Desktop (with graceful fallback to [saveFile]).
  Future<SaveResult> saveFileCrossPlatform({
    required Uint8List bytes,
    required String fileName,
    required String fileExtension,
    required MimeType mimeType,
  }) async {
    try {
      if (kIsWeb) {
        final path = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          fileExtension: fileExtension,
          mimeType: mimeType,
        );
        return SaveResult.success(path.isNotEmpty ? path : fileName);
      } else {
        try {
          final path = await FileSaver.instance.saveAs(
            name: fileName,
            bytes: bytes,
            fileExtension: fileExtension,
            mimeType: mimeType,
          );
          if (path == null || path.isEmpty) {
            return const SaveResult.canceled();
          }
          return SaveResult.success(path);
        } catch (_) {
          final path = await FileSaver.instance.saveFile(
            name: fileName,
            bytes: bytes,
            fileExtension: fileExtension,
            mimeType: mimeType,
          );
          return SaveResult.success(path.isNotEmpty ? path : fileName);
        }
      }
    } catch (e) {
      return SaveResult.failure(e.toString());
    }
  }

  Future<SaveResult> saveExcel(Uint8List bytes, String fileName) =>
      saveFileCrossPlatform(
        bytes: bytes,
        fileName: fileName,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

  Future<SaveResult> saveCsv(Uint8List bytes, String fileName) =>
      saveFileCrossPlatform(
        bytes: bytes,
        fileName: fileName,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

  Future<SaveResult> savePdf(Uint8List bytes, String fileName) =>
      saveFileCrossPlatform(
        bytes: bytes,
        fileName: fileName,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );

  Future<SaveResult> saveWord(Uint8List bytes, String fileName) =>
      saveFileCrossPlatform(
        bytes: bytes,
        fileName: fileName,
        fileExtension: 'docx',
        mimeType: MimeType.microsoftWord,
      );
}

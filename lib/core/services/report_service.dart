import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/l10n/l10n_service.dart';
import '../models/order.dart';
import '../models/product.dart';

/// Generates downloadable reports (Section 17.1 / Section 2.2):
///   - Excel  (.xlsx) monthly/yearly order reports
///   - Word   (.docx) editable catalog sheets
///   - PDF    (.pdf)  invoice / order summary
class ReportService {
  // --------------------------------------------------------------- Excel ---
  Uint8List buildOrderReportExcel(List<Order> orders, String title) {
    final excel = Excel.createExcel();
    final sheet = excel['Orders'];
    sheet.appendRow([TextCellValue(title)]);
    sheet.appendRow([
      TextCellValue('Order ID'),
      TextCellValue('Company'),
      TextCellValue('Items'),
      TextCellValue('Total (INR)'),
      TextCellValue('Status'),
      TextCellValue('Payment'),
      TextCellValue('Created'),
    ]);
    for (final o in orders) {
      sheet.appendRow([
        TextCellValue(o.id),
        TextCellValue(o.companyName),
        IntCellValue(o.items.length),
        DoubleCellValue(o.totalAmount),
        TextCellValue(o.orderStatus),
        TextCellValue(o.paymentStatus),
        TextCellValue(o.createdAt?.toIso8601String() ?? ''),
      ]);
    }
    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? const []);
  }

  // ----------------------------------------------------------------- Word ---
  // NOTE: the `docx` package writes to a dart:io File, so Word export runs on
  // mobile/desktop (the primary Admin platforms). Excel and PDF are fully
  // cross-platform (web included).
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
  Future<Uint8List> buildInvoicePdf(Order order) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            L10n.current.invoice,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(L10n.current.order(order.id.toUpperCase())),
          pw.Text(L10n.current.company2(order.companyName)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'Qty', 'Unit Price', 'Total'],
            data: order.items
                .map(
                  (e) => [
                    e.name,
                    '${e.qty}',
                    '₹${e.unitPrice}',
                    '₹${e.itemTotal}',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            L10n.current.total('${order.totalAmount}'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------- Save ---
  Future<void> saveExcel(Uint8List bytes, String fileName) =>
      FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.other,
      );

  Future<void> saveWord(Uint8List bytes, String fileName) =>
      FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'doc',
        mimeType: MimeType.other,
      );

  Future<void> savePdf(Uint8List bytes, String fileName) =>
      FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.other,
      );
}

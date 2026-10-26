import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/services/service_locator.dart';

/// Camera QR/barcode scanner (Section 15.2 + Section 17.2).
///
/// Pops with the scanned string, or routes a recognised `ecommerce://…` or web
/// deep link directly.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (value == null || value.isEmpty) return;
    _handled = true;

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final route = deepLinks.toRoute(uri);
      if (route != null) {
        context.push(route);
        return;
      }
    }

    if (value.startsWith('ecommerce://')) {
      // Route the deep link in-app.
      context.push('/${value.substring('ecommerce://'.length)}');
      return;
    }
    // Otherwise return the raw value to the caller.
    context.pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).scanQrBarcode)),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

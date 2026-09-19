import '../../../app/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../admin_shell.dart';

/// QR generation centre (Section 15.1): Product / Category / Company QR codes
/// with style options and export.
class AdminQrScreen extends StatefulWidget {
  const AdminQrScreen({super.key});

  @override
  State<AdminQrScreen> createState() => _AdminQrScreenState();
}

class _AdminQrScreenState extends State<AdminQrScreen> {
  String _type = 'product';
  String _data = 'ecommerce://product/p_tomato';
  int _style = 0; // 0=black/white, 1=colored, 2=logo-embedded

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'QR Codes',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'product', label: Text('Product')),
              ButtonSegment(value: 'category', label: Text('Category')),
              ButtonSegment(value: 'company', label: Text('Company')),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              final t = s.first;
              setState(() {
                _type = t;
                _data = switch (t) {
                  'product' => productDeepLink('p_tomato'),
                  'category' => categoryDeepLink('cat_veg'),
                  _ => companyDeepLink('greenleaf-organics'),
                };
              });
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: _data,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: _style == 1 ? QrEyeShape.circle : QrEyeShape.square,
                  color: _style == 1 ? Colors.green.shade700 : Colors.black,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape:
                      _style == 1 ? QrDataModuleShape.circle : QrDataModuleShape.square,
                  color: _style == 1 ? Colors.green.shade700 : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(_data,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _styleButton(0, 'B&W', Icons.contrast),
              _styleButton(1, 'Colored', Icons.palette),
              _styleButton(2, 'Logo', Icons.image),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download),
                  label: const Text('PNG'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print),
            label: const Text('Send to printer'),
          ),
        ],
      ),
    );
  }

  Widget _styleButton(int value, String label, IconData icon) {
    final active = _style == value;
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: () => setState(() => _style = value),
          icon: Icon(icon),
          style: active
              ? IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white)
              : null,
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

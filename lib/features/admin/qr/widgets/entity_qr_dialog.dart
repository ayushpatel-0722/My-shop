import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/qr_deep_link_service.dart';

/// Shows a dialog or modal bottom sheet with a QR code and shareable URL
/// for a Shop, Category, or Product.
Future<void> showEntityQrDialog({
  required BuildContext context,
  required QrEntityType type,
  required String title,
  required String shopId,
  String shopName = '',
  String? categoryId,
  String? productId,
  String? subtitle,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => EntityQrShareDialog(
      type: type,
      title: title,
      shopId: shopId,
      shopName: shopName,
      categoryId: categoryId,
      productId: productId,
      subtitle: subtitle,
    ),
  );
}

class EntityQrShareDialog extends StatefulWidget {
  final QrEntityType type;
  final String title;
  final String shopId;
  final String shopName;
  final String? categoryId;
  final String? productId;
  final String? subtitle;

  const EntityQrShareDialog({
    super.key,
    required this.type,
    required this.title,
    required this.shopId,
    this.shopName = '',
    this.categoryId,
    this.productId,
    this.subtitle,
  });

  @override
  State<EntityQrShareDialog> createState() => _EntityQrShareDialogState();
}

class _EntityQrShareDialogState extends State<EntityQrShareDialog> {
  final GlobalKey _qrRepaintKey = GlobalKey();
  int _qrStyle = 0; // 0 = B&W, 1 = Brand Themed, 2 = Modern Dots
  bool _useCustomScheme = false; // false = https://, true = ecommerce://
  bool _isExporting = false;
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _computeUrl();
  }

  void _computeUrl() {
    if (widget.shopId.trim().isEmpty) {
      _currentUrl = '';
      return;
    }

    if (_useCustomScheme) {
      switch (widget.type) {
        case QrEntityType.shop:
          _currentUrl = QrDeepLinkService.buildShopSchemeUrl(widget.shopId);
          break;
        case QrEntityType.category:
          _currentUrl = QrDeepLinkService.buildCategorySchemeUrl(
            widget.shopId,
            widget.categoryId ?? '',
          );
          break;
        case QrEntityType.product:
          _currentUrl = QrDeepLinkService.buildProductSchemeUrl(
            widget.shopId,
            widget.productId ?? '',
          );
          break;
      }
    } else {
      _currentUrl = QrDeepLinkService.buildUrl(
        type: widget.type,
        shopId: widget.shopId,
        categoryId: widget.categoryId,
        productId: widget.productId,
      );
    }
  }

  Color get _themeColor {
    switch (widget.type) {
      case QrEntityType.shop:
        return const Color(0xFF2563EB); // Royal Blue
      case QrEntityType.category:
        return const Color(0xFFD97706); // Amber / Orange
      case QrEntityType.product:
        return const Color(0xFF0D9488); // Teal
    }
  }

  String get _typeBadgeLabel {
    switch (widget.type) {
      case QrEntityType.shop:
        return 'STORE LINK';
      case QrEntityType.category:
        return 'CATEGORY LINK';
      case QrEntityType.product:
        return 'PRODUCT LINK';
    }
  }

  Future<void> _handleExport() async {
    if (_currentUrl.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final fileName = '${widget.type.name}_${widget.title}_qr';
      final path = await QrDeepLinkService.exportQrImage(
        boundaryKey: _qrRepaintKey,
        fileName: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_done, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    path != null
                        ? 'QR Code downloaded successfully!'
                        : 'QR Code image saved.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrlValid = _currentUrl.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Type Badge & Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _themeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _typeBadgeLabel,
                      style: TextStyle(
                        color: _themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title and Shop context
              Text(
                widget.title.isNotEmpty ? widget.title : 'Store Entity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2229),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.shopName.isNotEmpty || widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle ?? 'Shop: ${widget.shopName}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 14),

              // QR Code Card (Inside RepaintBoundary for high-res export)
              Center(
                child: RepaintBoundary(
                  key: _qrRepaintKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isUrlValid
                        ? QrImageView(
                            data: _currentUrl,
                            version: QrVersions.auto,
                            size: 210,
                            backgroundColor: Colors.white,
                            eyeStyle: QrEyeStyle(
                              eyeShape: _qrStyle == 2
                                  ? QrEyeShape.circle
                                  : QrEyeShape.square,
                              color: _qrStyle == 1 ? _themeColor : Colors.black,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: _qrStyle == 2
                                  ? QrDataModuleShape.circle
                                  : QrDataModuleShape.square,
                              color: _qrStyle == 1 ? _themeColor : Colors.black,
                            ),
                          )
                        : SizedBox(
                            width: 210,
                            height: 210,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.link_off,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cannot generate QR code.\nShop ID is required.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Style Switcher Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _styleChip(0, 'B&W (Printable)'),
                  const SizedBox(width: 8),
                  _styleChip(1, 'Branded'),
                  const SizedBox(width: 8),
                  _styleChip(2, 'Rounded'),
                ],
              ),
              const SizedBox(height: 14),

              // URL Display Box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _useCustomScheme
                                ? 'App Custom Scheme Link:'
                                : 'Public Web & App Deep Link:',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            isUrlValid ? _currentUrl : 'Invalid URL parameters',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isUrlValid
                                  ? const Color(0xFF0F172A)
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy URL',
                      onPressed: isUrlValid
                          ? () => QrDeepLinkService.copyToClipboard(
                              context,
                              _currentUrl,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Protocol Toggle (Public HTTPS vs App Scheme)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Use custom app scheme (ecommerce://)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _useCustomScheme,
                    activeThumbColor: _themeColor,
                    onChanged: (val) {
                      setState(() {
                        _useCustomScheme = val;
                        _computeUrl();
                      });
                    },
                  ),
                ],
              ),
              const Divider(height: 20),

              // Actions Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  // Test / Open Link
                  OutlinedButton.icon(
                    onPressed: isUrlValid
                        ? () => QrDeepLinkService.openUrl(_currentUrl)
                        : null,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Test Link'),
                  ),

                  // Download PNG
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _themeColor),
                    onPressed: isUrlValid && !_isExporting
                        ? _handleExport
                        : null,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download, size: 16),
                    label: const Text('Download PNG'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styleChip(int styleIndex, String label) {
    final active = _qrStyle == styleIndex;
    return InkWell(
      onTap: () => setState(() => _qrStyle = styleIndex),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _themeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

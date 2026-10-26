import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/routes/app_router.dart';
import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/qr_deep_link_service.dart';
import '../../../core/services/service_locator.dart';
import '../admin_shell.dart';
import '../home_config/widgets/shop_selector_bar.dart';

/// QR Generation & Shareable URL Centre for Shops, Categories, and Products.
class AdminQrScreen extends StatefulWidget {
  const AdminQrScreen({super.key});

  @override
  State<AdminQrScreen> createState() => _AdminQrScreenState();
}

class _AdminQrScreenState extends State<AdminQrScreen> {
  final GlobalKey _qrRepaintKey = GlobalKey();

  String _shopId = '';
  String _shopName = '';
  Company? _selectedShop;

  QrEntityType _entityType = QrEntityType.shop;
  String? _selectedCategoryId;
  String? _selectedProductId;

  int _style = 0; // 0 = B&W, 1 = Colored, 2 = Rounded
  bool _useCustomScheme = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final user = AuthSession.currentUser;
    _shopId = user?.companyId.isNotEmpty == true
        ? user!.companyId
        : 'masala-mart';
    _shopName = user?.companyName.isNotEmpty == true
        ? user!.companyName
        : 'Masala Mart';
    _selectedShop = Company(id: _shopId, name: _shopName, slug: _shopId);
  }

  void _onShopChanged(Company company) {
    setState(() {
      _selectedShop = company;
      _shopId = company.id;
      _shopName = company.name;
      _selectedCategoryId = null;
      _selectedProductId = null;
    });
  }

  String get _currentUrl {
    if (_shopId.trim().isEmpty) return '';

    if (_useCustomScheme) {
      switch (_entityType) {
        case QrEntityType.shop:
          return QrDeepLinkService.buildShopSchemeUrl(_shopId);
        case QrEntityType.category:
          if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
            return '';
          }
          return QrDeepLinkService.buildCategorySchemeUrl(
            _shopId,
            _selectedCategoryId!,
          );
        case QrEntityType.product:
          if (_selectedProductId == null || _selectedProductId!.isEmpty) {
            return '';
          }
          return QrDeepLinkService.buildProductSchemeUrl(
            _shopId,
            _selectedProductId!,
          );
      }
    } else {
      switch (_entityType) {
        case QrEntityType.shop:
          return QrDeepLinkService.buildShopUrl(_shopId);
        case QrEntityType.category:
          if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
            return '';
          }
          return QrDeepLinkService.buildCategoryUrl(
            _shopId,
            _selectedCategoryId!,
          );
        case QrEntityType.product:
          if (_selectedProductId == null || _selectedProductId!.isEmpty) {
            return '';
          }
          return QrDeepLinkService.buildProductUrl(
            _shopId,
            _selectedProductId!,
          );
      }
    }
  }

  Color get _themeColor {
    switch (_entityType) {
      case QrEntityType.shop:
        return const Color(0xFF2563EB); // Blue
      case QrEntityType.category:
        return const Color(0xFFD97706); // Orange / Amber
      case QrEntityType.product:
        return const Color(0xFF0D9488); // Teal
    }
  }

  Future<void> _handleDownloadPng() async {
    final url = _currentUrl;
    if (url.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final fileName = '${_entityType.name}_${_shopId}_qr';
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
                        ? 'QR Code saved successfully!'
                        : 'QR Code downloaded.',
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

    return AdminShell(
      showBack: true,
      backRoute: AppRoutes.admin,
      title: 'QR Code & Deep Link Manager',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Shop Selector (Multi-tenant support)
          ShopSelectorBar(
            selectedShop: _selectedShop,
            onShopChanged: _onShopChanged,
          ),
          const SizedBox(height: 16),

          // 2. Entity Type Selector Segmented Button
          SegmentedButton<QrEntityType>(
            segments: const [
              ButtonSegment(
                value: QrEntityType.shop,
                icon: Icon(Icons.storefront_rounded, size: 18),
                label: Text('Shop / Store'),
              ),
              ButtonSegment(
                value: QrEntityType.category,
                icon: Icon(Icons.category_rounded, size: 18),
                label: Text('Category'),
              ),
              ButtonSegment(
                value: QrEntityType.product,
                icon: Icon(Icons.inventory_2_rounded, size: 18),
                label: Text('Product'),
              ),
            ],
            selected: {_entityType},
            onSelectionChanged: (set) {
              setState(() {
                _entityType = set.first;
              });
            },
          ),
          const SizedBox(height: 18),

          // 3. Entity Specific Dropdown (for Category or Product)
          if (_entityType == QrEntityType.category)
            _buildCategorySelector()
          else if (_entityType == QrEntityType.product)
            _buildProductSelector()
          else
            _buildShopBanner(),

          const SizedBox(height: 20),

          // 4. QR Code Card Container with RepaintBoundary
          Center(
            child: RepaintBoundary(
              key: _qrRepaintKey,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isUrlValid
                    ? QrImageView(
                        data: _currentUrl,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: _style == 2
                              ? QrEyeShape.circle
                              : QrEyeShape.square,
                          color: _style == 1 ? _themeColor : Colors.black,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: _style == 2
                              ? QrDataModuleShape.circle
                              : QrDataModuleShape.square,
                          color: _style == 1 ? _themeColor : Colors.black,
                        ),
                      )
                    : Container(
                        width: 220,
                        height: 220,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _entityType == QrEntityType.category
                                  ? 'Please select a category above'
                                  : (_entityType == QrEntityType.product
                                        ? 'Please select a product above'
                                        : 'Invalid shop configuration'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. QR Code Style Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _styleButton(0, 'B&W (Printable)', Icons.contrast),
              const SizedBox(width: 12),
              _styleButton(1, 'Branded Color', Icons.palette),
              const SizedBox(width: 12),
              _styleButton(2, 'Rounded Modules', Icons.rounded_corner),
            ],
          ),
          const SizedBox(height: 20),

          // 6. Deep Link URL Display & Copy Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        isUrlValid
                            ? _currentUrl
                            : 'Select an entity to generate link',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isUrlValid
                              ? const Color(0xFF0F172A)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy Link',
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

          // 7. Scheme Switcher
          SwitchListTile(
            dense: true,
            title: const Text(
              'Use native app scheme (ecommerce://)',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            subtitle: const Text(
              'Default uses public HTTPS links compatible with web & App Links',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            value: _useCustomScheme,
            activeThumbColor: _themeColor,
            onChanged: (val) => setState(() => _useCustomScheme = val),
          ),
          const SizedBox(height: 20),

          // 8. Action Buttons: Download PNG, Test Link, Copy
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUrlValid
                      ? () => QrDeepLinkService.copyToClipboard(
                          context,
                          _currentUrl,
                        )
                      : null,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isUrlValid && !_isExporting
                      ? _handleDownloadPng
                      : null,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Download PNG'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isUrlValid
                ? () => QrDeepLinkService.openUrl(_currentUrl)
                : null,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Test Generated Link in Browser / App'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildShopBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront, color: Color(0xFF2563EB), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                Text(
                  'Shop ID: $_shopId',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return StreamBuilder<List<Category>>(
      stream: repo.categories(),
      builder: (context, snap) {
        final categories = (snap.data ?? const <Category>[])
            .where((c) => c.companyId.isEmpty || c.companyId == _shopId)
            .toList();

        if (categories.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'No categories found for this shop. Please add categories first.',
              style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
            ),
          );
        }

        if (_selectedCategoryId == null && categories.isNotEmpty) {
          _selectedCategoryId = categories.first.id;
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          decoration: InputDecoration(
            labelText: 'Select Category',
            prefixIcon: const Icon(Icons.category_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: categories.map((cat) {
            return DropdownMenuItem<String>(
              value: cat.id,
              child: Text(cat.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedCategoryId = val;
            });
          },
        );
      },
    );
  }

  Widget _buildProductSelector() {
    return StreamBuilder<List<Product>>(
      stream: repo.products(companyId: _shopId),
      builder: (context, snap) {
        final products = snap.data ?? const <Product>[];

        if (products.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'No products found for this shop. Please add products first.',
              style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
            ),
          );
        }

        if (_selectedProductId == null && products.isNotEmpty) {
          _selectedProductId = products.first.id;
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedProductId,
          decoration: InputDecoration(
            labelText: 'Select Product',
            prefixIcon: const Icon(Icons.inventory_2_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          isExpanded: true,
          items: products.map((prod) {
            return DropdownMenuItem<String>(
              value: prod.id,
              child: Text(
                '${prod.name} (${prod.id})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedProductId = val;
            });
          },
        );
      },
    );
  }

  Widget _styleButton(int value, String label, IconData icon) {
    final active = _style == value;
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: () => setState(() => _style = value),
          icon: Icon(icon, size: 20),
          style: active
              ? IconButton.styleFrom(
                  backgroundColor: _themeColor,
                  foregroundColor: Colors.white,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? _themeColor : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/modern_button.dart';
import '../../../core/widgets/modern_card.dart';

/// Full-screen form for creating a new Product (Section 6.6 & 17.1).
///
/// Features:
/// - Responsive layout (mobile & desktop friendly)
/// - Multi-image gallery with URL preview & error fallbacks
/// - Dynamic variant matrix (SKU, Size, Color, Stock, Price Overrides)
/// - Price & Discount calculation preview
/// - Bounded layout constraints preventing viewport layout crashes
class AdminAddProductScreen extends StatefulWidget {
  const AdminAddProductScreen({super.key});

  @override
  State<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _subDetailsCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: '1');
  final _unitTypeCtrl = TextEditingController(text: 'pieces');
  final _stockCtrl = TextEditingController(text: '10');
  final _imageUrlCtrl = TextEditingController();

  // Form State
  String _companyId = '';
  String _companyName = '';
  String? _selectedCategoryId;
  String _measurementType = 'quantity_based'; // 'quantity_based' | 'weight_based'
  bool _isRecommended = false;
  bool _isSaving = false;

  final List<String> _images = [];
  final List<ProductVariant> _variants = [];

  static const List<String> _commonUnitTypes = [
    'pieces',
    'kg',
    'grams',
    'liters',
    'ml',
    'pack',
    'bottle',
    'box',
  ];

  @override
  void initState() {
    super.initState();
    final adminCompanyId = AuthSession.currentUser?.companyId ?? '';
    final adminCompanyName = AuthSession.currentUser?.companyName ?? '';
    _companyId = adminCompanyId;
    _companyName = adminCompanyName;

    if (_companyName.isEmpty && _companyId.isNotEmpty) {
      _loadCompanyName(_companyId);
    }
  }

  Future<void> _loadCompanyName(String cid) async {
    try {
      final comp = await repo.company(cid);
      if (comp != null && comp.name.isNotEmpty && mounted) {
        setState(() => _companyName = comp.name);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailsCtrl.dispose();
    _subDetailsCtrl.dispose();
    _priceCtrl.dispose();
    _discountPriceCtrl.dispose();
    _unitCtrl.dispose();
    _unitTypeCtrl.dispose();
    _stockCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  void _addImageUrl() {
    final raw = _imageUrlCtrl.text.trim();
    if (raw.isEmpty) return;

    final urls = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && (e.startsWith('http://') || e.startsWith('https://')))
        .toList();

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid HTTP or HTTPS image URL')),
      );
      return;
    }

    setState(() {
      _images.addAll(urls);
      _imageUrlCtrl.clear();
    });
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  void _showAddVariantDialog() {
    final sizeCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final skuCtrl = TextEditingController(
      text: 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final stockCtrl = TextEditingController(text: '10');
    final priceOverrideCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product Variant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU *', hintText: 'e.g. SKU-RED-L'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sizeCtrl,
                decoration: const InputDecoration(labelText: 'Size', hintText: 'e.g. S, M, L, XL, 500ml'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorCtrl,
                decoration: const InputDecoration(labelText: 'Color', hintText: 'e.g. Navy, Crimson'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceOverrideCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Price Override (Optional)',
                  hintText: 'Leave empty or 0 to use base price',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final sku = skuCtrl.text.trim();
              if (sku.isEmpty) return;

              final variant = ProductVariant(
                sku: sku,
                size: sizeCtrl.text.trim(),
                color: colorCtrl.text.trim(),
                stockQty: int.tryParse(stockCtrl.text) ?? 0,
                priceOverride: double.tryParse(priceOverrideCtrl.text) ?? 0.0,
              );

              setState(() => _variants.add(variant));
              Navigator.pop(ctx);
            },
            child: const Text('Add Variant'),
          ),
        ],
      ),
    );
  }

  void _removeVariant(int index) {
    setState(() => _variants.removeAt(index));
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Category for the product')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final basePrice = double.tryParse(_priceCtrl.text) ?? 0.0;
      final discountPrice = double.tryParse(_discountPriceCtrl.text) ?? 0.0;
      final unitValue = double.tryParse(_unitCtrl.text) ?? 1.0;
      final stockValue = int.tryParse(_stockCtrl.text) ?? 0;

      // Include pending typed image URL if valid
      final pendingUrl = _imageUrlCtrl.text.trim();
      final allImages = List<String>.from(_images);
      if (pendingUrl.isNotEmpty && (pendingUrl.startsWith('http://') || pendingUrl.startsWith('https://'))) {
        allImages.add(pendingUrl);
      }

      final product = Product(
        id: '',
        companyId: _companyId,
        categoryId: _selectedCategoryId!,
        name: _nameCtrl.text.trim(),
        details: _detailsCtrl.text.trim(),
        subDetails: _subDetailsCtrl.text.trim(),
        type: _measurementType,
        unit: unitValue,
        unitType: _unitTypeCtrl.text.trim(),
        amount: basePrice,
        discountAmt: discountPrice,
        stockQty: stockValue,
        isRecommended: _isRecommended,
        images: allImages,
        variants: _variants,
      );

      await repo.saveProduct(product);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product "${product.name}" created successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.adminProducts);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save product: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate discount preview percentage
    final baseAmount = double.tryParse(_priceCtrl.text) ?? 0;
    final discAmount = double.tryParse(_discountPriceCtrl.text) ?? 0;
    final hasDiscount = baseAmount > 0 && discAmount > 0 && discAmount < baseAmount;
    final discountPercent = hasDiscount ? (((baseAmount - discAmount) / baseAmount) * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.adminProducts);
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Header Title & Company Scope Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Specification',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create new catalog items with multi-image gallery, dynamic variant matrix, and inventory controls.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Read-only Company Scope Pill (Auto-assigned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              _companyName.isNotEmpty
                                  ? _companyName
                                  : (_companyId.isNotEmpty
                                      ? 'Company Scope'
                                      : 'Global Scope'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Card 1: Basic Information
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Basic Information',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Product Title *',
                            hintText: 'e.g. Organic Hass Avocado (Pack of 4)',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Product title is required' : null,
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<Category>>(
                          stream: repo.categories(companyId: _companyId),
                          builder: (context, snapshot) {
                            final categories = snapshot.data ?? const <Category>[];
                            return DropdownButtonFormField<String>(
                              initialValue: categories.any((c) => c.id == _selectedCategoryId)
                                  ? _selectedCategoryId
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: categories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    '${c.iconUrl.isNotEmpty ? c.iconUrl : "📁"} ${c.name} (${c.type})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCategoryId = val),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Please select a category' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _detailsCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Full Description',
                            hintText: 'Detailed product summary, origin, benefits...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _subDetailsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Additional Specs / Sub-details',
                            hintText: 'Ingredients, storage instructions, material specifications...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Card 2: Pricing & Measurement
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isNarrow = cardConstraints.maxWidth < 480;

                        final priceField = TextFormField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₹) *',
                            hintText: '99.00',
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter price';
                            if (double.tryParse(v) == null) return 'Valid number';
                            return null;
                          },
                        );

                        final discountPriceField = TextFormField(
                          controller: _discountPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Discounted Price (₹)',
                            hintText: 'Leave empty if none',
                            prefixIcon: const Icon(Icons.local_offer_outlined),
                            suffix: hasDiscount
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '-$discountPercent%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );

                        final unitValField = TextFormField(
                          controller: _unitCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Unit Value *',
                            hintText: 'e.g. 1 or 500',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        );

                        final unitTypeField = TextFormField(
                          controller: _unitTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unit Type *',
                            hintText: 'e.g. kg, pieces',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.monetization_on_outlined, color: theme.colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pricing & Measurement',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (isNarrow) ...[
                              priceField,
                              const SizedBox(height: 14),
                              discountPriceField,
                            ] else
                              Row(
                                children: [
                                  Expanded(child: priceField),
                                  const SizedBox(width: 16),
                                  Expanded(child: discountPriceField),
                                ],
                              ),
                            const SizedBox(height: 20),
                            Text(
                              'Base Measurement Type',
                              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                showSelectedIcon: !isNarrow,
                                segments: [
                                  ButtonSegment<String>(
                                    value: 'quantity_based',
                                    label: Text(isNarrow ? 'Quantity' : 'Quantity Based'),
                                    icon: const Icon(Icons.tag, size: 18),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'weight_based',
                                    label: Text(isNarrow ? 'Weight' : 'Weight Based'),
                                    icon: const Icon(Icons.scale, size: 18),
                                  ),
                                ],
                                selected: {_measurementType},
                                onSelectionChanged: (set) => setState(() => _measurementType = set.first),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (isNarrow) ...[
                              unitValField,
                              const SizedBox(height: 14),
                              unitTypeField,
                            ] else
                              Row(
                                children: [
                                  Expanded(child: unitValField),
                                  const SizedBox(width: 16),
                                  Expanded(child: unitTypeField),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _commonUnitTypes.map((u) {
                                return ActionChip(
                                  label: Text(u, style: const TextStyle(fontSize: 11)),
                                  onPressed: () => setState(() => _unitTypeCtrl.text = u),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Stock Quantity *',
                                hintText: 'Available inventory units',
                                prefixIcon: Icon(Icons.warehouse_outlined),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Enter inventory count' : null,
                            ),
                            const SizedBox(height: 12),
                            Material(
                              color: Colors.transparent,
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Featured Recommendation'),
                                subtitle: Text(
                                  'Flag this product to appear in the recommendations engine carousel.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  ),
                                ),
                                value: _isRecommended,
                                onChanged: (val) => setState(() => _isRecommended = val),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Card 3: Multi-image Gallery
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.photo_library_outlined, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Product Gallery',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${_images.length} added',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _imageUrlCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Image URL',
                                  hintText: 'https://images.unsplash.com/...',
                                  prefixIcon: Icon(Icons.link),
                                ),
                                onFieldSubmitted: (_) => _addImageUrl(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: _addImageUrl,
                              icon: const Icon(Icons.add_photo_alternate, size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        if (_images.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _images.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                final url = _images[idx];
                                return SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Image.network(
                                            url,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => Container(
                                              width: 100,
                                              height: 100,
                                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                              child: const Icon(Icons.broken_image, color: Colors.grey, size: 28),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: InkWell(
                                          onTap: () => _removeImage(idx),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      if (idx == 0)
                                        Positioned(
                                          bottom: 4,
                                          left: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Main',
                                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Card 4: Variant Matrix
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Variant Matrix',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _showAddVariantDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Variant'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Define SKU, size, color, stock, and price overrides for product variations.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_variants.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'No variants added (single item SKU). Tap "Add Variant" to configure sizes or colors.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: [
                              for (int idx = 0; idx < _variants.length; idx++) ...[
                                if (idx > 0) const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.surfaceContainerDark : AppTheme.surfaceContainerLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.qr_code, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _variants[idx].sku,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Size: ${_variants[idx].size.isEmpty ? "Standard" : _variants[idx].size} • Color: ${_variants[idx].color.isEmpty ? "None" : _variants[idx].color} • Stock: ${_variants[idx].stockQty}${_variants[idx].priceOverride > 0 ? " • ₹${_variants[idx].priceOverride}" : ""}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        onPressed: () => _removeVariant(idx),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Action
                  ModernButton(
                    text: 'Create Product',
                    icon: const Icon(Icons.check, size: 20),
                    isLoading: _isSaving,
                    height: 52,
                    width: double.infinity,
                    onPressed: _isSaving ? null : _handleSave,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

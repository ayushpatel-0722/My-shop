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

/// Full-screen form for creating and editing a Product with Dynamic Variant Generation.
///
/// Features:
/// - Step 1: Basic Information (Title, Dynamic Category Dropdown, Rich Bullet Description)
/// - Step 2: Media Upload (URL gallery, Hero/Main image badge, reordering, deletion)
/// - Step 3: Pricing & Base Inventory (MRP, Selling Price with live % OFF pill, Base SKU, Stock Count / Unlimited / Finished)
/// - Step 4: Dynamic Variants Architecture (Custom Option Types, Cartesian Product Matrix Generator)
/// - Step 5: Specifications & Policies (Key-Value custom specs list, Return & Delivery policy)
class AdminAddProductScreen extends StatefulWidget {
  final Product? product;
  final String? productId;

  const AdminAddProductScreen({super.key, this.product, this.productId});

  @override
  State<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step 1: Basic Info Controllers
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _subDetailsCtrl = TextEditingController();

  // Step 2: Media Controllers
  final _imageUrlCtrl = TextEditingController();
  final List<String> _images = [];

  // Step 3: Pricing & Base Inventory Controllers
  final _priceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  final _baseSkuCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: '1');
  final _unitTypeCtrl = TextEditingController(text: 'pieces');
  final _stockCtrl = TextEditingController(text: '10');

  // Stock inventory mode: 'specific' | 'unlimited' | 'out_of_stock'
  String _stockMode = 'specific';

  // Step 4: Dynamic Options & Variants State
  final List<ProductOption> _options = [];
  final List<ProductVariant> _variants = [];

  // Step 5: Specifications & Policies Controllers
  final List<MapEntry<TextEditingController, TextEditingController>>
  _specControllers = [];
  final _policyCtrl = TextEditingController();

  // Form State
  String _companyId = '';
  String _companyName = '';
  String? _selectedCategoryId;
  String _measurementType =
      'quantity_based'; // 'quantity_based' | 'weight_based'
  bool _isRecommended = false;
  bool _isSaving = false;
  bool _isLoadingProduct = false;
  String? _loadedProductId;

  bool get isEditMode => widget.product != null || widget.productId != null;

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

    if (widget.product != null) {
      _initFromProduct(widget.product!);
    } else if (widget.productId != null && widget.productId!.isNotEmpty) {
      _loadProductById(widget.productId!);
    } else {
      _baseSkuCtrl.text =
          'PROD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }

    if (_companyName.isEmpty && _companyId.isNotEmpty) {
      _loadCompanyName(_companyId);
    }
  }

  void _initFromProduct(Product p) {
    _loadedProductId = p.id;
    _nameCtrl.text = p.name;
    _detailsCtrl.text = p.details;
    _subDetailsCtrl.text = p.subDetails;
    _baseSkuCtrl.text = p.sku.isNotEmpty
        ? p.sku
        : 'PROD-${p.id.isNotEmpty ? p.id : DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _priceCtrl.text = p.amount > 0
        ? (p.amount == p.amount.roundToDouble()
              ? p.amount.toInt().toString()
              : p.amount.toString())
        : '';
    _discountPriceCtrl.text = p.discountAmt > 0
        ? (p.discountAmt == p.discountAmt.roundToDouble()
              ? p.discountAmt.toInt().toString()
              : p.discountAmt.toString())
        : '';
    _unitCtrl.text = p.unit == p.unit.roundToDouble()
        ? p.unit.toInt().toString()
        : p.unit.toString();
    _unitTypeCtrl.text = p.unitType.isNotEmpty ? p.unitType : 'pieces';
    _stockCtrl.text = p.stockQty.toString();

    if (p.isUnlimitedStock) {
      _stockMode = 'unlimited';
    } else if (p.stockQty <= 0) {
      _stockMode = 'out_of_stock';
    } else {
      _stockMode = 'specific';
    }

    _measurementType = p.type.isNotEmpty ? p.type : 'quantity_based';
    _isRecommended = p.isRecommended;
    _selectedCategoryId = p.categoryId.isNotEmpty ? p.categoryId : null;
    _policyCtrl.text = p.policy;
    if (p.companyId.isNotEmpty) {
      _companyId = p.companyId;
    }

    _images.clear();
    _images.addAll(p.images);

    _options.clear();
    _options.addAll(p.options);

    _variants.clear();
    _variants.addAll(p.variants);

    for (final entry in _specControllers) {
      entry.key.dispose();
      entry.value.dispose();
    }
    _specControllers.clear();
    for (final spec in p.specifications) {
      _specControllers.add(
        MapEntry(
          TextEditingController(text: spec.key),
          TextEditingController(text: spec.value),
        ),
      );
    }
  }

  Future<void> _loadProductById(String id) async {
    setState(() => _isLoadingProduct = true);
    try {
      final p = await repo.product(id);
      if (p != null && mounted) {
        setState(() {
          _initFromProduct(p);
        });
        if (_companyName.isEmpty && _companyId.isNotEmpty) {
          _loadCompanyName(_companyId);
        }
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _isLoadingProduct = false);
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
    _imageUrlCtrl.dispose();
    _priceCtrl.dispose();
    _discountPriceCtrl.dispose();
    _baseSkuCtrl.dispose();
    _unitCtrl.dispose();
    _unitTypeCtrl.dispose();
    _stockCtrl.dispose();
    _policyCtrl.dispose();
    for (final entry in _specControllers) {
      entry.key.dispose();
      entry.value.dispose();
    }
    super.dispose();
  }

  // --- Step 1 Helper: Insert Bullet ---
  void _insertBulletPoint() {
    final currentText = _detailsCtrl.text;
    final selection = _detailsCtrl.selection;
    const bullet = '\n• ';

    if (selection.start >= 0 && selection.end >= 0) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        bullet,
      );
      _detailsCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + bullet.length,
        ),
      );
    } else {
      _detailsCtrl.text = currentText.isEmpty ? '• ' : '$currentText$bullet';
    }
  }

  // --- Step 2 Helpers: Media Gallery ---
  void _addImageUrl() {
    final raw = _imageUrlCtrl.text.trim();
    if (raw.isEmpty) return;

    final urls = raw
        .split(',')
        .map((e) => e.trim())
        .where(
          (e) =>
              e.isNotEmpty &&
              (e.startsWith('http://') || e.startsWith('https://')),
        )
        .toList();

    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid HTTP or HTTPS image URL'),
        ),
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

  void _setHeroImage(int index) {
    if (index == 0 || index >= _images.length) return;
    setState(() {
      final item = _images.removeAt(index);
      _images.insert(0, item);
    });
  }

  // --- Step 4 Helpers: Dynamic Options & Cartesian Matrix Generator ---
  void _showAddOptionDialog() {
    final nameCtrl = TextEditingController();
    final valuesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product Option'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Define a variation type and its choices (e.g. Size, Color, Weight, Storage, Box Type).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Option Name *',
                  hintText: 'e.g. Size, Weight, Color, Storage',
                  prefixIcon: Icon(Icons.tune),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valuesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Option Values (comma separated) *',
                  hintText: 'e.g. S, M, L, XL or 250g, 500g, 1kg',
                  prefixIcon: Icon(Icons.list),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Quick Templates:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text(
                      'Clothing: Size (S, M, L, XL)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      nameCtrl.text = 'Size';
                      valuesCtrl.text = 'S, M, L, XL';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Color (Pink, Blue, Black)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      nameCtrl.text = 'Color';
                      valuesCtrl.text = 'Pink, Blue, Black';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Grocery: Weight (1kg, 5kg, 10kg, 50kg)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      nameCtrl.text = 'Weight';
                      valuesCtrl.text = '1kg, 5kg, 10kg, 50kg';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Food: Weight (250g, 500g, 1kg)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      nameCtrl.text = 'Weight';
                      valuesCtrl.text = '250g, 500g, 1kg';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Liquids (250ml, 500ml, 1L, 2L)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      nameCtrl.text = 'Volume';
                      valuesCtrl.text = '250ml, 500ml, 1L, 2L';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Multipack (Pack of 1, Pack of 2, Pack of 5)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      nameCtrl.text = 'Pack';
                      valuesCtrl.text = 'Pack of 1, Pack of 2, Pack of 5';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Electronics: RAM (8GB, 16GB)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () {
                      nameCtrl.text = 'RAM';
                      valuesCtrl.text = '8GB, 16GB';
                    },
                  ),
                ],
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
              final optName = nameCtrl.text.trim();
              final rawValues = valuesCtrl.text.trim();
              if (optName.isEmpty || rawValues.isEmpty) return;

              final parsedValues = rawValues
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();

              if (parsedValues.isEmpty) return;

              setState(() {
                final existingIdx = _options.indexWhere(
                  (o) => o.name.toLowerCase() == optName.toLowerCase(),
                );
                if (existingIdx >= 0) {
                  _options[existingIdx] = ProductOption(
                    name: optName,
                    values: parsedValues,
                  );
                } else {
                  _options.add(
                    ProductOption(name: optName, values: parsedValues),
                  );
                }
              });

              Navigator.pop(ctx);
            },
            child: const Text('Save Option'),
          ),
        ],
      ),
    );
  }

  void _removeOption(int index) {
    setState(() => _options.removeAt(index));
  }

  /// Converts a quantity and unit string into a standard canonical dimension.
  /// Standard canonical dimensions:
  /// - Weight: grams (g)
  /// - Volume: milliliters (ml)
  /// - Quantity/Count: count (pcs)
  double? _toCanonicalUnit(double qty, String unit, String measurementType) {
    final u = unit.trim().toLowerCase();
    if (qty <= 0) return null;

    // Weight conversions (canonical: grams)
    if (u == 'g' || u == 'gm' || u == 'gms' || u == 'gram' || u == 'grams') {
      return qty * 1.0;
    }
    if (u == 'kg' ||
        u == 'kgs' ||
        u == 'kilo' ||
        u == 'kilos' ||
        u == 'kilogram' ||
        u == 'kilograms') {
      return qty * 1000.0;
    }
    if (u == 'mg' || u == 'milligram' || u == 'milligrams') {
      return qty * 0.001;
    }
    if (u == 'quintal' || u == 'qtl') {
      return qty * 100000.0;
    }
    if (u == 'ton' || u == 'tonne' || u == 'metric ton') {
      return qty * 1000000.0;
    }
    if (u == 'lb' || u == 'lbs' || u == 'pound' || u == 'pounds') {
      return qty * 453.592;
    }
    if (u == 'oz' || u == 'ounce' || u == 'ounces') {
      return qty * 28.3495;
    }

    // Volume conversions (canonical: ml)
    if (u == 'ml' ||
        u == 'milliliter' ||
        u == 'milliliters' ||
        u == 'millilitre' ||
        u == 'millilitres') {
      return qty * 1.0;
    }
    if (u == 'l' ||
        u == 'ltr' ||
        u == 'ltrs' ||
        u == 'liter' ||
        u == 'liters' ||
        u == 'litre' ||
        u == 'litres') {
      return qty * 1000.0;
    }
    if (u == 'cl') {
      return qty * 10.0;
    }
    if (u == 'gal' || u == 'gallon' || u == 'gallons') {
      return qty * 3785.41;
    }

    // Quantity / Count conversions (canonical: pieces)
    if (u == 'pcs' ||
        u == 'pc' ||
        u == 'piece' ||
        u == 'pieces' ||
        u == 'unit' ||
        u == 'units' ||
        u == 'item' ||
        u == 'items' ||
        u == 'nos' ||
        u == 'no' ||
        u == 'count' ||
        u == 'pack' ||
        u == 'packs' ||
        u == 'packet' ||
        u == 'packets' ||
        u == 'pkt' ||
        u == 'pkts' ||
        u == 'box' ||
        u == 'boxes' ||
        u == 'bottle' ||
        u == 'bottles' ||
        u == 'can' ||
        u == 'cans' ||
        u == 'jar' ||
        u == 'jars' ||
        u == 'pouch' ||
        u == 'pouches' ||
        u == 'strip' ||
        u == 'strips' ||
        u == 'bag' ||
        u == 'bags' ||
        u == 'tin' ||
        u == 'tins' ||
        u == 'roll' ||
        u == 'rolls' ||
        u == 'set' ||
        u == 'sets') {
      return qty * 1.0;
    }
    if (u == 'pair' || u == 'pairs') {
      return qty * 2.0;
    }
    if (u == 'dozen' || u == 'doz') {
      return qty * 12.0;
    }
    if (u == 'half dozen' || u == 'half-dozen') {
      return qty * 6.0;
    }

    // Fallback based on measurement type
    if (measurementType == 'weight_based') {
      return qty * 1000.0; // Default to kg
    }
    return qty;
  }

  /// Parses an option value string (e.g., "5kg", "500g", "Pack of 5", "2 pcs", "10", "1.5L")
  /// and returns a MapEntry of (quantity, unit).
  MapEntry<double, String>? _parseQuantityAndUnit(
    String rawValue,
    String optionName,
    String defaultUnit,
  ) {
    final val = rawValue.trim().toLowerCase();
    if (val.isEmpty) return null;

    // 1. Check for phrases like "half dozen" or "dozen"
    if (val == 'half dozen' || val == 'half-dozen') {
      return const MapEntry(6.0, 'pcs');
    }
    if (val == 'dozen' || val == '1 dozen') {
      return const MapEntry(12.0, 'pcs');
    }
    if (val == 'pair' || val == '1 pair') {
      return const MapEntry(2.0, 'pcs');
    }

    // 2. Check for "pack of N" / "box of N" / "set of N"
    final packOfMatch = RegExp(
      r'(?:pack|box|set|bundle|case)\s*(?:of)?\s*(\d+(?:\.\d+)?)',
    ).firstMatch(val);
    if (packOfMatch != null) {
      final q = double.tryParse(packOfMatch.group(1) ?? '');
      if (q != null && q > 0) return MapEntry(q, 'pcs');
    }

    // 3. Check for "N x" or "Nx" (e.g. "2x", "5x")
    final multiplierMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*x$').firstMatch(val);
    if (multiplierMatch != null) {
      final q = double.tryParse(multiplierMatch.group(1) ?? '');
      if (q != null && q > 0) return MapEntry(q, 'pcs');
    }

    // 4. Check for fraction patterns like "1/2 kg", "1/4 kg", "1/2 liter", "1/2 l"
    final fractionMatch = RegExp(
      r'(\d+)\s*/\s*(\d+)\s*([a-zA-Z]+)?',
    ).firstMatch(val);
    if (fractionMatch != null) {
      final num = double.tryParse(fractionMatch.group(1) ?? '') ?? 1.0;
      final den = double.tryParse(fractionMatch.group(2) ?? '') ?? 1.0;
      final unitStr = (fractionMatch.group(3) ?? defaultUnit).trim();
      if (den > 0) {
        return MapEntry(num / den, unitStr.isNotEmpty ? unitStr : defaultUnit);
      }
    }

    // 5. Check for standard number + unit pattern (e.g., "5kg", "500 g", "1.5 Liters", "250ml", "10 pcs")
    final numUnitMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*([a-zA-Z]+)',
    ).firstMatch(val);
    if (numUnitMatch != null) {
      final q = double.tryParse(numUnitMatch.group(1) ?? '');
      final u = (numUnitMatch.group(2) ?? '').trim();
      if (q != null && q > 0) {
        return MapEntry(q, u.isNotEmpty ? u : defaultUnit);
      }
    }

    // 6. Check for standalone number (e.g. "5", "10", "50")
    final standaloneNum = double.tryParse(val);
    if (standaloneNum != null && standaloneNum > 0) {
      return MapEntry(standaloneNum, defaultUnit);
    }

    return null;
  }

  /// Calculates the proportional price override for a variant combo based on base price, base unit, unit type, and measurement type.
  double _calculateAutoPriceOverride(
    Map<String, String> combo,
    double basePrice,
    double baseUnitQty,
    String baseUnitType,
    String measurementType,
  ) {
    if (basePrice <= 0) return 0.0;
    final effectiveBaseQty = baseUnitQty > 0 ? baseUnitQty : 1.0;
    final normalizedBaseUnit = baseUnitType.trim().toLowerCase();

    final baseCanonical = _toCanonicalUnit(
      effectiveBaseQty,
      normalizedBaseUnit,
      measurementType,
    );

    double totalMultiplier = 1.0;
    bool foundDimension = false;

    for (final entry in combo.entries) {
      final optName = entry.key.trim().toLowerCase();
      final parsed = _parseQuantityAndUnit(
        entry.value,
        optName,
        normalizedBaseUnit,
      );
      if (parsed != null) {
        final parsedQty = parsed.key;
        final parsedUnit = parsed.value;

        final variantCanonical = _toCanonicalUnit(
          parsedQty,
          parsedUnit,
          measurementType,
        );

        if (baseCanonical != null &&
            variantCanonical != null &&
            baseCanonical > 0) {
          totalMultiplier *= (variantCanonical / baseCanonical);
          foundDimension = true;
        } else if (parsedQty > 0) {
          totalMultiplier *= (parsedQty / effectiveBaseQty);
          foundDimension = true;
        }
      }
    }

    if (!foundDimension) {
      return basePrice;
    }

    final computedPrice = basePrice * totalMultiplier;
    return double.parse(computedPrice.toStringAsFixed(2));
  }

  /// Computes the Cartesian Product matrix of all options with intelligent auto-pricing.
  void _generateVariantMatrix() {
    if (_options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one Option first to generate combinations.',
          ),
        ),
      );
      return;
    }

    // Generate Cartesian product of list of lists
    List<Map<String, String>> combinations = [{}];

    for (final opt in _options) {
      if (opt.values.isEmpty) continue;
      final List<Map<String, String>> newCombos = [];
      for (final existing in combinations) {
        for (final val in opt.values) {
          final updated = Map<String, String>.from(existing);
          updated[opt.name] = val;
          newCombos.add(updated);
        }
      }
      combinations = newCombos;
    }

    final baseSku = _baseSkuCtrl.text.trim().isNotEmpty
        ? _baseSkuCtrl.text.trim()
        : 'SKU';
    final baseStock = _stockMode == 'out_of_stock'
        ? 0
        : (int.tryParse(_stockCtrl.text) ?? 10);
    final isUnlimited = _stockMode == 'unlimited';

    final baseSellingPrice = double.tryParse(_discountPriceCtrl.text) ?? 0.0;
    final baseMrp = double.tryParse(_priceCtrl.text) ?? 0.0;
    final effectiveBasePrice = baseSellingPrice > 0
        ? baseSellingPrice
        : baseMrp;
    final baseUnitQty = double.tryParse(_unitCtrl.text) ?? 1.0;
    final baseUnitType = _unitTypeCtrl.text.trim().isNotEmpty
        ? _unitTypeCtrl.text.trim()
        : 'pieces';

    final List<ProductVariant> newVariants = combinations.map((combo) {
      final comboTitle = combo.values.join(' / ');
      final skuSuffix = combo.values
          .map((v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''))
          .join('-');
      final sku = '$baseSku-$skuSuffix';

      final autoPrice = _calculateAutoPriceOverride(
        combo,
        effectiveBasePrice,
        baseUnitQty,
        baseUnitType,
        _measurementType,
      );

      // Check if we have an existing variant with matching attributes to preserve custom overrides
      final existingIndex = _variants.indexWhere((v) {
        if (v.attributes.length != combo.length) return false;
        for (final entry in combo.entries) {
          if (v.attributes[entry.key] != entry.value) return false;
        }
        return true;
      });

      final existing = existingIndex >= 0 ? _variants[existingIndex] : null;

      final finalPrice = (existing != null && existing.priceOverride > 0)
          ? existing.priceOverride
          : autoPrice;

      return ProductVariant(
        sku: (existing != null && existing.sku.isNotEmpty) ? existing.sku : sku,
        title: comboTitle,
        attributes: combo,
        stockQty: (existing != null && existing.stockQty > 0)
            ? existing.stockQty
            : baseStock,
        isUnlimitedStock:
            (existing != null && existing.isUnlimitedStock) || isUnlimited,
        priceOverride: finalPrice,
        size:
            combo['Size'] ??
            combo['Weight'] ??
            combo['Quantity'] ??
            combo['Pack'] ??
            combo['Volume'] ??
            '',
        color: combo['Color'] ?? '',
      );
    }).toList();

    setState(() {
      _variants.clear();
      _variants.addAll(newVariants);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generated ${_variants.length} variant combinations with auto-calculated prices!',
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _showAddManualVariantDialog() {
    final skuCtrl = TextEditingController(
      text:
          'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final sizeCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final priceOverrideCtrl = TextEditingController();
    bool variantUnlimited = _stockMode == 'unlimited';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Product Variant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: skuCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SKU *',
                    hintText: 'e.g. SKU-RED-L',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Size',
                    hintText: 'e.g. S, M, L, XL, 500g',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    hintText: 'e.g. Navy, Crimson',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Unlimited Inventory',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: variantUnlimited,
                  onChanged: (val) =>
                      setDialogState(() => variantUnlimited = val),
                ),
                if (!variantUnlimited) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock Quantity',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: priceOverrideCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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

                final sizeVal = sizeCtrl.text.trim();
                final colorVal = colorCtrl.text.trim();
                final attrs = <String, String>{};
                if (sizeVal.isNotEmpty) attrs['Size'] = sizeVal;
                if (colorVal.isNotEmpty) attrs['Color'] = colorVal;

                final variant = ProductVariant(
                  sku: sku,
                  attributes: attrs,
                  size: sizeVal,
                  color: colorVal,
                  isUnlimitedStock: variantUnlimited,
                  stockQty: variantUnlimited
                      ? 0
                      : (int.tryParse(stockCtrl.text) ?? 0),
                  priceOverride: double.tryParse(priceOverrideCtrl.text) ?? 0.0,
                );

                setState(() => _variants.add(variant));
                Navigator.pop(ctx);
              },
              child: const Text('Add Variant'),
            ),
          ],
        ),
      ),
    );
  }

  void _editVariant(int index) {
    final v = _variants[index];
    final skuCtrl = TextEditingController(text: v.sku);
    final stockCtrl = TextEditingController(text: v.stockQty.toString());
    final priceCtrl = TextEditingController(
      text: v.priceOverride > 0
          ? (v.priceOverride == v.priceOverride.roundToDouble()
                ? v.priceOverride.toInt().toString()
                : v.priceOverride.toString())
          : '',
    );
    bool variantUnlimited = v.isUnlimitedStock;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Variant (${v.title.isNotEmpty ? v.title : v.sku})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: skuCtrl,
                  decoration: const InputDecoration(labelText: 'SKU'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Unlimited Inventory',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: variantUnlimited,
                  onChanged: (val) =>
                      setDialogState(() => variantUnlimited = val),
                ),
                if (!variantUnlimited) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock Quantity',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price Override (₹)',
                    hintText: 'Leave empty for base price',
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
                setState(() {
                  _variants[index] = ProductVariant(
                    sku: skuCtrl.text.trim().isNotEmpty
                        ? skuCtrl.text.trim()
                        : v.sku,
                    title: v.title,
                    attributes: v.attributes,
                    isUnlimitedStock: variantUnlimited,
                    stockQty: variantUnlimited
                        ? 0
                        : (int.tryParse(stockCtrl.text) ?? v.stockQty),
                    priceOverride: double.tryParse(priceCtrl.text) ?? 0.0,
                    size: v.size,
                    color: v.color,
                  );
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeVariant(int index) {
    setState(() => _variants.removeAt(index));
  }

  // --- Step 5 Helpers: Dynamic Specifications ---
  void _addSpecRow() {
    setState(() {
      _specControllers.add(
        MapEntry(TextEditingController(), TextEditingController()),
      );
    });
  }

  void _removeSpecRow(int index) {
    setState(() {
      final item = _specControllers.removeAt(index);
      item.key.dispose();
      item.value.dispose();
    });
  }

  // --- Form Submission ---
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check all required fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final basePrice = double.tryParse(_priceCtrl.text) ?? 0.0;
      final discountPrice = double.tryParse(_discountPriceCtrl.text) ?? 0.0;
      final unitValue = double.tryParse(_unitCtrl.text) ?? 1.0;

      final isUnlimited = _stockMode == 'unlimited';
      final stockValue = _stockMode == 'out_of_stock'
          ? 0
          : (isUnlimited ? 0 : (int.tryParse(_stockCtrl.text) ?? 0));

      // Include pending typed image URL if valid
      final pendingUrl = _imageUrlCtrl.text.trim();
      final allImages = List<String>.from(_images);
      if (pendingUrl.isNotEmpty &&
          (pendingUrl.startsWith('http://') ||
              pendingUrl.startsWith('https://')) &&
          !allImages.contains(pendingUrl)) {
        allImages.add(pendingUrl);
      }

      // Collect specs
      final List<ProductSpec> specs = [];
      for (final entry in _specControllers) {
        final k = entry.key.text.trim();
        final v = entry.value.text.trim();
        if (k.isNotEmpty && v.isNotEmpty) {
          specs.add(ProductSpec(key: k, value: v));
        }
      }

      final resolvedId =
          _loadedProductId ?? widget.product?.id ?? widget.productId ?? '';

      final product = Product(
        id: resolvedId,
        companyId: _companyId,
        categoryId: _selectedCategoryId ?? '',
        name: _nameCtrl.text.trim(),
        details: _detailsCtrl.text.trim(),
        subDetails: _subDetailsCtrl.text.trim(),
        type: _measurementType,
        unit: unitValue,
        unitType: _unitTypeCtrl.text.trim(),
        amount: basePrice,
        discountAmt: discountPrice,
        sku: _baseSkuCtrl.text.trim(),
        stockQty: stockValue,
        isUnlimitedStock: isUnlimited,
        isRecommended: _isRecommended,
        images: allImages,
        options: _options,
        variants: _variants,
        specifications: specs,
        policy: _policyCtrl.text.trim(),
      );

      await repo.saveProduct(product);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Product "${product.name}" updated successfully!'
                : 'Product "${product.name}" created successfully!',
          ),
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
    if (_isLoadingProduct) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate discount preview percentage
    final baseAmount = double.tryParse(_priceCtrl.text) ?? 0;
    final discAmount = double.tryParse(_discountPriceCtrl.text) ?? 0;
    final hasDiscount =
        baseAmount > 0 && discAmount > 0 && discAmount < baseAmount;
    final discountPercent = hasDiscount
        ? (((baseAmount - discAmount) / baseAmount) * 100).round()
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Product' : 'Add New Product'),
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
          constraints: const BoxConstraints(maxWidth: 800),
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEditMode
                                  ? 'Update catalog item details, pricing, images, variants, and specifications.'
                                  : 'Create new catalog items with dynamic variants, custom options, gallery, and inventory controls.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.store,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
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

                  // ==========================================
                  // Step 1: Basic Information
                  // ==========================================
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Basic Information',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Product Title *',
                            hintText:
                                'e.g. Organic Hass Avocado / Chanderi Silk Saree / 15-in-1 Sweets Box',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Product title is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<Category>>(
                          stream: repo.categories(companyId: _companyId),
                          builder: (context, snapshot) {
                            final categories =
                                snapshot.data ?? const <Category>[];
                            return DropdownButtonFormField<String>(
                              initialValue:
                                  categories.any(
                                    (c) => c.id == _selectedCategoryId,
                                  )
                                  ? _selectedCategoryId
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                hintText:
                                    'Select category (Clothing, Food, Electronics, etc.)',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: categories.map((c) {
                                final prefix = (c.hasIcon && !c.hasImageIcon)
                                    ? '${c.iconUrl} '
                                    : '📁 ';
                                return DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    '$prefix${c.name} (${c.type})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategoryId = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Product Description',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _insertBulletPoint,
                              icon: const Icon(
                                Icons.format_list_bulleted,
                                size: 16,
                              ),
                              label: const Text(
                                'Insert Bullet',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _detailsCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Detailed product summary, features, ingredients, origin...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _subDetailsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Highlights / Sub-details',
                            hintText:
                                'Key selling points (e.g. 100% Handcrafted • Dispatch in 24h • Organic)',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // Step 2: Media Upload & Gallery
                  // ==========================================
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Product Gallery',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${_images.length} added',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add multiple image URLs. The first image will automatically act as the Hero / Main product image.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
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
                              icon: const Icon(
                                Icons.add_photo_alternate,
                                size: 18,
                              ),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        if (_images.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _images.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                final url = _images[idx];
                                final isHero = idx == 0;
                                return SizedBox(
                                  width: 105,
                                  height: 110,
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 105,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isHero
                                                  ? theme.colorScheme.primary
                                                  : (isDark
                                                        ? AppTheme.borderDark
                                                        : AppTheme.borderLight),
                                              width: isHero ? 2 : 1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Image.network(
                                            url,
                                            width: 105,
                                            height: 110,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) =>
                                                Container(
                                                  width: 105,
                                                  height: 110,
                                                  color: isDark
                                                      ? Colors.grey.shade800
                                                      : Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                    size: 28,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                      // Remove button
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
                                            child: const Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Hero badge or Set as Hero button
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: isHero
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Hero / Main',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : InkWell(
                                                onTap: () => _setHeroImage(idx),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Make Hero',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                    ),
                                                  ),
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

                  // ==========================================
                  // Step 3: Pricing & Base Inventory
                  // ==========================================
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isNarrow = cardConstraints.maxWidth < 480;

                        final mrpField = TextFormField(
                          controller: _priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'MRP / Original Price (₹) *',
                            hintText: 'e.g. 999.00',
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter price';
                            }
                            if (double.tryParse(v) == null) {
                              return 'Valid number';
                            }
                            return null;
                          },
                        );

                        final sellingPriceField = TextFormField(
                          controller: _discountPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Selling / Discounted Price (₹)',
                            hintText: 'e.g. 799.00',
                            prefixIcon: const Icon(Icons.local_offer_outlined),
                            suffix: hasDiscount
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$discountPercent% OFF',
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

                        final skuField = TextFormField(
                          controller: _baseSkuCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Base SKU / Product Code *',
                            hintText: 'e.g. PROD-HONEY-01',
                            prefixIcon: Icon(Icons.qr_code_2),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        );

                        final stockField = TextFormField(
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock Quantity *',
                            hintText: 'Available inventory units',
                            prefixIcon: Icon(Icons.warehouse_outlined),
                          ),
                          validator: (v) {
                            if (_stockMode == 'specific') {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter inventory count';
                              }
                              if (int.tryParse(v) == null) {
                                return 'Valid integer';
                              }
                            }
                            return null;
                          },
                        );

                        final unitValField = TextFormField(
                          controller: _unitCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Unit Value *',
                            hintText: 'e.g. 1 or 500',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        );

                        final unitTypeField = TextFormField(
                          controller: _unitTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unit Type *',
                            hintText: 'e.g. kg, pieces, box',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.monetization_on_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pricing & Measurement',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (isNarrow) ...[
                              mrpField,
                              const SizedBox(height: 14),
                              sellingPriceField,
                            ] else
                              Row(
                                children: [
                                  Expanded(child: mrpField),
                                  const SizedBox(width: 16),
                                  Expanded(child: sellingPriceField),
                                ],
                              ),
                            const SizedBox(height: 16),
                            skuField,
                            const SizedBox(height: 20),

                            // Stock Availability Selection (Specific Count / Unlimited / Finished)
                            Text(
                              'Stock Availability & Inventory Mode',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                showSelectedIcon: !isNarrow,
                                segments: [
                                  ButtonSegment<String>(
                                    value: 'specific',
                                    label: Text(
                                      isNarrow ? 'Count' : 'Specific Count',
                                    ),
                                    icon: const Icon(
                                      Icons.format_list_numbered,
                                      size: 18,
                                    ),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'unlimited',
                                    label: Text(
                                      isNarrow
                                          ? 'Unlimited'
                                          : 'Unlimited Stock',
                                    ),
                                    icon: const Icon(
                                      Icons.all_inclusive,
                                      size: 18,
                                    ),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'out_of_stock',
                                    label: Text(
                                      isNarrow
                                          ? 'Out of Stock'
                                          : 'Finished / Out of Stock',
                                    ),
                                    icon: const Icon(Icons.block, size: 18),
                                  ),
                                ],
                                selected: {_stockMode},
                                onSelectionChanged: (set) => setState(() {
                                  _stockMode = set.first;
                                  if (_stockMode == 'out_of_stock') {
                                    _stockCtrl.text = '0';
                                  } else if (_stockMode == 'specific' &&
                                      (_stockCtrl.text.isEmpty ||
                                          _stockCtrl.text == '0')) {
                                    _stockCtrl.text = '10';
                                  }
                                }),
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (_stockMode == 'specific') ...[
                              stockField,
                            ] else if (_stockMode == 'unlimited') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.all_inclusive,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Unlimited Inventory: Product will always appear in stock for customers (ideal for digital goods or made-to-order items).',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Out of Stock / Finished: Product will show as sold out on the storefront until restocked.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),
                            Text(
                              'Base Measurement Type',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                showSelectedIcon: !isNarrow,
                                segments: [
                                  ButtonSegment<String>(
                                    value: 'quantity_based',
                                    label: Text(
                                      isNarrow ? 'Quantity' : 'Quantity Based',
                                    ),
                                    icon: const Icon(Icons.tag, size: 18),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'weight_based',
                                    label: Text(
                                      isNarrow ? 'Weight' : 'Weight Based',
                                    ),
                                    icon: const Icon(Icons.scale, size: 18),
                                  ),
                                ],
                                selected: {_measurementType},
                                onSelectionChanged: (set) => setState(
                                  () => _measurementType = set.first,
                                ),
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
                                  label: Text(
                                    u,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () =>
                                      setState(() => _unitTypeCtrl.text = u),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Material(
                              color: Colors.transparent,
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Featured Recommendation'),
                                subtitle: Text(
                                  'Flag this product to appear in the recommendations engine carousel.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.textSecondaryDark
                                        : AppTheme.textSecondaryLight,
                                  ),
                                ),
                                value: _isRecommended,
                                onChanged: (val) =>
                                    setState(() => _isRecommended = val),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // Step 4: Dynamic Variants Architecture (Core Feature)
                  // ==========================================
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
                                Icon(
                                  Icons.tune,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Variant Matrix',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _showAddOptionDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Option'),
                                ),
                                FilledButton.icon(
                                  onPressed: _generateVariantMatrix,
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    size: 16,
                                  ),
                                  label: const Text('Generate Matrix'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: _showAddManualVariantDialog,
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Variant'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure customizable option types (e.g. Size, Color, Weight, Storage) and automatically generate Cartesian combinations with distinct SKU, stock, and price overrides.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Option Types List
                        if (_options.isNotEmpty) ...[
                          Text(
                            'Configured Option Sets:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_options.length, (idx) {
                              final opt = _options[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${opt.name}: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      opt.values.join(', '),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _removeOption(idx),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Variant Combinations Table / Rows
                        if (_variants.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.borderDark
                                    : AppTheme.borderLight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'No variants configured (single standard SKU). Tap "Add Option" to define dimensions, then "Generate Matrix".',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_variants.length} Variant Combinations:',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (
                                int idx = 0;
                                idx < _variants.length;
                                idx++
                              ) ...[
                                if (idx > 0) const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.surfaceContainerDark
                                        : AppTheme.surfaceContainerLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? AppTheme.borderDark
                                          : AppTheme.borderLight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.qr_code, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    _variants[idx]
                                                            .title
                                                            .isNotEmpty
                                                        ? _variants[idx].title
                                                        : _variants[idx].sku,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    _variants[idx].sku,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontFamily: 'monospace',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Stock: ${_variants[idx].isUnlimitedStock ? "Unlimited" : _variants[idx].stockQty} • ${_variants[idx].priceOverride > 0 ? "Price: ₹${_variants[idx].priceOverride % 1 == 0 ? _variants[idx].priceOverride.toInt() : _variants[idx].priceOverride}" : "Base Price"}${_variants[idx].attributes.isNotEmpty ? " • ${_variants[idx].attributes.entries.map((e) => "${e.key}: ${e.value}").join(", ")}" : ""}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppTheme.textSecondaryDark
                                                    : AppTheme
                                                          .textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        tooltip: 'Edit Stock & Price Override',
                                        onPressed: () => _editVariant(idx),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        tooltip: 'Remove',
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

                  const SizedBox(height: 20),

                  // ==========================================
                  // Step 5: Specifications & Policies
                  // ==========================================
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Specifications & Policies',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addSpecRow,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Add Spec',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add dynamic key-value specifications (e.g. Fabric, Shelf Life, Processor, Storage, Origin) and return/delivery policies.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Specifications List
                        if (_specControllers.isNotEmpty) ...[
                          for (int i = 0; i < _specControllers.length; i++) ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _specControllers[i].key,
                                    decoration: const InputDecoration(
                                      labelText: 'Spec Key',
                                      hintText: 'e.g. Fabric / Shelf Life',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _specControllers[i].value,
                                    decoration: const InputDecoration(
                                      labelText: 'Spec Value',
                                      hintText: 'e.g. Pure Silk / 30 Days',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _removeSpecRow(i),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 8),
                        ],

                        // Return & Delivery Policy
                        TextFormField(
                          controller: _policyCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Delivery & Return Policy',
                            hintText:
                                'e.g. Free shipping on orders above ₹499. Easy 7-day hassle-free replacement for defective products.',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ==========================================
                  // Save / Publish Action
                  // ==========================================
                  ModernButton(
                    text: isEditMode ? 'Update Product' : 'Create Product',
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

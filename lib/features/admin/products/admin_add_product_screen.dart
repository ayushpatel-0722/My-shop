import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/core/services/admin_company_name.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/product.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/qr_deep_link_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/app_product_image.dart';
import '../../../core/widgets/full_screen_image_viewer.dart';
import '../../../core/widgets/modern_button.dart';
import '../../../core/widgets/modern_card.dart';
import '../qr/widgets/entity_qr_dialog.dart';
import 'widgets/structured_content_editors.dart';

/// Full-screen form for creating and editing a Product with Dynamic Variant Generation.
///
/// Features:
/// - Step 1: Basic Information (Title, Rich Bullet Description)
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

  // Structured content (Flipkart style): N highlight rows + N detail sections.
  List<HighlightItem> _highlights = <HighlightItem>[];
  List<DetailSection> _allDetails = <DetailSection>[];
  bool _contentShowErrors = false;

  // Step 2: Media Controllers
  final _imageUrlCtrl = TextEditingController();
  final List<String> _images = [];

  // Step 3: Pricing & Base Inventory Controllers
  final _priceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  final _baseSkuCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
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
  String _measurementType =
      'quantity_based'; // 'quantity_based' | 'weight_based'
  bool _isRecommended = false;
  bool _isSaving = false;
  bool _isLoadingProduct = false;
  String? _loadedProductId;

  bool get isEditMode => widget.product != null || widget.productId != null;

  static const List<String> _weightUnitTypes = ['kg', 'g', 'mg', 'lb'];
  static const List<String> _quantityUnitTypes = [
    'pieces',
    'box',
    'pack',
    'bottle',
    'unit',
  ];

  List<String> get _currentUnitTypes => _measurementType == 'weight_based'
      ? _weightUnitTypes
      : _quantityUnitTypes;

  /// Check whether all prerequisite primary product data is entered to enable variant configuration.
  bool get _isVariantSectionEnabled {
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final hasPrice = price > 0;
    final unit = double.tryParse(_unitCtrl.text.trim()) ?? 0;
    final hasUnit = unit > 0;
    final hasSku = _baseSkuCtrl.text.trim().isNotEmpty;

    return hasName && hasPrice && hasUnit && hasSku;
  }

  /// List of missing required fields before variant configuration can be unlocked.
  List<String> get _missingBaseFields {
    final missing = <String>[];
    if (_nameCtrl.text.trim().isEmpty) {
      missing.add(AppLocalizations.of(context).productTitle2);
    }
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (price <= 0) missing.add(AppLocalizations.of(context).baseMrpPrice);
    final unit = double.tryParse(_unitCtrl.text.trim()) ?? 0;
    if (unit <= 0) missing.add(AppLocalizations.of(context).baseUnitValue);
    if (_baseSkuCtrl.text.trim().isEmpty) {
      missing.add(AppLocalizations.of(context).baseSku);
    }
    return missing;
  }

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

  // --- Structured content: migration + legacy compatibility ---

  /// Old products carry `highlights` / `subDetails` as plain strings; split
  /// them into editable rows so the admin can fill in the titles.
  List<HighlightItem> _migrateHighlights(Product p) {
    if (p.highlights.isNotEmpty) {
      return [
        for (var i = 0; i < p.highlights.length; i++)
          p.highlights[i].copyWith(order: i),
      ];
    }
    final raw = p.subDetails.trim();
    if (raw.isEmpty) return <HighlightItem>[];
    final lines = raw
        .split(RegExp(r'\n|•|\u2022'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return [
      for (var i = 0; i < lines.length; i++)
        HighlightItem(
          id: 'h_mig_${DateTime.now().microsecondsSinceEpoch}_$i',
          title: '',
          value: lines[i],
          order: i,
        ),
    ];
  }

  /// Old products carry `description` / `details` as one string; fold it into
  /// a single "Description" text section when no structured data exists.
  List<DetailSection> _migrateAllDetails(Product p) {
    if (p.allDetails.isNotEmpty) {
      return [
        for (var i = 0; i < p.allDetails.length; i++)
          p.allDetails[i].copyWith(order: i),
      ];
    }
    final raw = p.details.trim();
    if (raw.isEmpty) return <DetailSection>[];
    return [
      DetailSection(
        id: 'd_mig_${DateTime.now().microsecondsSinceEpoch}',
        title: 'Description',
        type: DetailSectionType.text,
        text: raw,
        order: 0,
      ),
    ];
  }

  /// Legacy `description` string kept in sync until migration is confirmed.
  String _legacyDescription(List<DetailSection> sections) {
    for (final s in sections) {
      if (s.isText && s.title.trim().toLowerCase() == 'description') {
        return s.text.trim();
      }
    }
    for (final s in sections) {
      if (s.isText && s.text.trim().isNotEmpty) return s.text.trim();
    }
    return '';
  }

  /// Legacy `subDetails` string kept in sync until migration is confirmed.
  String _legacySubDetails(List<HighlightItem> rows) => rows
      .where((h) => h.value.trim().isNotEmpty)
      .map(
        (h) => h.title.trim().isEmpty
            ? h.value.trim()
            : '${h.title.trim()}: ${h.value.trim()}',
      )
      .join('\n');

  void _initFromProduct(Product p) {
    _loadedProductId = p.id;
    _nameCtrl.text = p.name;
    _highlights = _migrateHighlights(p);
    _allDetails = _migrateAllDetails(p);
    _baseSkuCtrl.text = p.sku.isNotEmpty
        ? p.sku
        : 'PROD-${p.id.isNotEmpty ? p.id : DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _colorCtrl.text = p.color;
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
    _imageUrlCtrl.dispose();
    _priceCtrl.dispose();
    _discountPriceCtrl.dispose();
    _baseSkuCtrl.dispose();
    _colorCtrl.dispose();
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
        SnackBar(
          content: Text(
            AppLocalizations.of(context).pleaseEnterAValidHttpOrHttpsImageUrl,
          ),
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

  /// Dynamic synchronization when the base product unit type is changed.
  void _syncUnitTypeToVariantsAndOptions(String newUnitType) {
    final oldUnit = _unitTypeCtrl.text.trim().toLowerCase();
    final cleanNewUnit = newUnitType.trim().toLowerCase();
    if (oldUnit == cleanNewUnit &&
        _variants.every((v) => v.unitType == cleanNewUnit)) {
      return;
    }

    setState(() {
      _unitTypeCtrl.text = cleanNewUnit;

      // 1. Synchronize all variants
      for (int i = 0; i < _variants.length; i++) {
        final v = _variants[i];
        final updatedAttrs = Map<String, String>.from(v.attributes);
        updatedAttrs.forEach((k, val) {
          if (oldUnit.isNotEmpty && val.toLowerCase().contains(oldUnit)) {
            updatedAttrs[k] = val.replaceAll(
              RegExp(oldUnit, caseSensitive: false),
              cleanNewUnit,
            );
          }
        });

        String updatedTitle = v.title;
        if (oldUnit.isNotEmpty &&
            updatedTitle.toLowerCase().contains(oldUnit)) {
          updatedTitle = updatedTitle.replaceAll(
            RegExp(oldUnit, caseSensitive: false),
            cleanNewUnit,
          );
        } else if (!updatedTitle.toLowerCase().contains(cleanNewUnit) &&
            v.unitValue > 0) {
          updatedTitle =
              '${v.unitValue == v.unitValue.roundToDouble() ? v.unitValue.toInt() : v.unitValue} $cleanNewUnit${v.color.isNotEmpty ? " / ${v.color}" : ""}';
        }

        _variants[i] = v.copyWith(
          unitType: cleanNewUnit,
          title: updatedTitle,
          attributes: updatedAttrs,
        );
      }

      // 2. Synchronize existing configured options
      for (int i = 0; i < _options.length; i++) {
        final opt = _options[i];
        final updatedValues = opt.values.map((val) {
          if (oldUnit.isNotEmpty && val.toLowerCase().contains(oldUnit)) {
            return val.replaceAll(
              RegExp(oldUnit, caseSensitive: false),
              cleanNewUnit,
            );
          }
          return val;
        }).toList();

        String updatedName = opt.name;
        if (oldUnit.isNotEmpty &&
            (updatedName.toLowerCase() == oldUnit ||
                (updatedName.toLowerCase() == 'box' && cleanNewUnit != 'box') ||
                (updatedName.toLowerCase() == 'pack' &&
                    cleanNewUnit != 'pack') ||
                (updatedName.toLowerCase() == 'weight' &&
                    _measurementType != 'weight_based'))) {
          updatedName = _measurementType == 'weight_based'
              ? AppLocalizations.of(context).weight
              : AppLocalizations.of(context).quantity;
        }

        _options[i] = ProductOption(name: updatedName, values: updatedValues);
      }
    });
  }

  List<Widget> _buildQuickOptionTemplateChips(
    TextEditingController nameCtrl,
    TextEditingController valuesCtrl,
    String currentUnit,
  ) {
    final chips = <Widget>[];

    // 1. Unit/Dimension templates strictly tailored to currentUnit
    if (currentUnit == 'pieces' || currentUnit == 'unit') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(
              context,
            ).quantity12510(currentUnit, currentUnit, currentUnit, currentUnit),
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).quantity;
            valuesCtrl.text =
                '1 $currentUnit, 2 $currentUnit, 5 $currentUnit, 10 $currentUnit';
          },
        ),
      );
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(
              context,
            ).quantity246(currentUnit, currentUnit, currentUnit),
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).quantity;
            valuesCtrl.text = '2 $currentUnit, 4 $currentUnit, 6 $currentUnit';
          },
        ),
      );
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).clothingSizeSMLXlXxl,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).size;
            valuesCtrl.text = AppLocalizations.of(context).sMLXlXxl;
          },
        ),
      );
    } else if (currentUnit == 'kg') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).weight1kg2kg5kg10kg,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).weight;
            valuesCtrl.text = AppLocalizations.of(context).msg1kg2kg5kg10kg;
          },
        ),
      );
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).weight500g1kg2kg5kg,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).weight;
            valuesCtrl.text = AppLocalizations.of(context).msg500g1kg2kg5kg;
          },
        ),
      );
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).weight250g500g1kg,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).weight;
            valuesCtrl.text = AppLocalizations.of(context).msg250g500g1kg;
          },
        ),
      );
    } else if (currentUnit == 'g') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).weight50g100g250g500g,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).weight;
            valuesCtrl.text = '50g, 100g, 250g, 500g';
          },
        ),
      );
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).weight100g200g500g1000g,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).weight;
            valuesCtrl.text = '100g, 200g, 500g, 1000g';
          },
        ),
      );
    } else if (currentUnit == 'mg') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).weight50mg100mg250mg500mg,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).weight;
            valuesCtrl.text = AppLocalizations.of(
              context,
            ).msg50mg100mg250mg500mg;
          },
        ),
      );
    } else if (currentUnit == 'lb') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).weight1lb2lb5lb10lb,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).weight;
            valuesCtrl.text = AppLocalizations.of(context).msg1lb2lb5lb10lb;
          },
        ),
      );
    } else if (currentUnit == 'box') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).box1Box2Boxes5Boxes10Boxes,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).box;
            valuesCtrl.text = AppLocalizations.of(
              context,
            ).msg1Box2Boxes5Boxes10Boxes;
          },
        ),
      );
    } else if (currentUnit == 'pack') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).pack1Pack2Packs5Packs10Packs,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).pack;
            valuesCtrl.text = AppLocalizations.of(
              context,
            ).msg1Pack2Packs5Packs10Packs;
          },
        ),
      );
    } else if (currentUnit == 'bottle') {
      chips.add(
        ActionChip(
          label: Text(
            AppLocalizations.of(context).bottle1Bottle2Bottles4Bottles6Bottles,
            style: const TextStyle(fontSize: 11),
          ),
          onPressed: () {
            nameCtrl.text = AppLocalizations.of(context).bottle;
            valuesCtrl.text = AppLocalizations.of(
              context,
            ).msg1Bottle2Bottles4Bottles6Bottles;
          },
        ),
      );
    }

    // 2. Color templates (Always available for every product type)
    chips.add(
      ActionChip(
        label: Text(
          AppLocalizations.of(context).colorRedBlueBlackWhiteGreen,
          style: const TextStyle(fontSize: 11),
        ),
        onPressed: () {
          nameCtrl.text = AppLocalizations.of(context).color;
          valuesCtrl.text = AppLocalizations.of(context).redBlueBlackWhiteGreen;
        },
      ),
    );
    chips.add(
      ActionChip(
        label: Text(
          AppLocalizations.of(context).colorNavyCrimsonOliveGold,
          style: const TextStyle(fontSize: 11),
        ),
        onPressed: () {
          nameCtrl.text = AppLocalizations.of(context).color;
          valuesCtrl.text = AppLocalizations.of(context).navyCrimsonOliveGold;
        },
      ),
    );

    return chips;
  }

  // --- Step 4 Helpers: Dynamic Options & Cartesian Matrix Generator ---
  void _showAddOptionDialog() {
    if (!_isVariantSectionEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).pleaseCompleteTheRequiredProductDetailsAboveBeforeConfiguringOptions(
              _missingBaseFields.join(', '),
            ),
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final valuesCtrl = TextEditingController();
    final currentUnit = _unitTypeCtrl.text.trim().toLowerCase().isNotEmpty
        ? _unitTypeCtrl.text.trim().toLowerCase()
        : (_measurementType == 'weight_based' ? 'kg' : 'pieces');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).addProductOption),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).unitOptionsStrictlySynchronizedWith(currentUnit),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).optionName,
                  hintText: AppLocalizations.of(context).eGQuantitySizeColor,
                  prefixIcon: const Icon(Icons.tune),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valuesCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(
                    context,
                  ).optionValuesCommaSeparated,
                  hintText: AppLocalizations.of(
                    context,
                  ).eG125(currentUnit, currentUnit, currentUnit),
                  prefixIcon: const Icon(Icons.list),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(
                  context,
                ).quickTemplatesStrictlyFor(currentUnit),
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
                children: _buildQuickOptionTemplateChips(
                  nameCtrl,
                  valuesCtrl,
                  currentUnit,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
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

              // Restrict contradicting unit option names
              const allKnownUnits = [
                'box',
                'pack',
                'bottle',
                'kg',
                'g',
                'pieces',
                'unit',
                'mg',
                'lb',
              ];
              final conflictingUnits = allKnownUnits
                  .where((u) => u != currentUnit)
                  .toList();

              if (conflictingUnits.contains(optName.toLowerCase())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(
                        context,
                      ).cannotAddOptionTheProductUnitIsLockedToPleaseUseQuantityOrSizeColor(
                        optName,
                        currentUnit,
                      ),
                    ),
                    backgroundColor: Colors.orange.shade800,
                  ),
                );
                return;
              }

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
            child: Text(AppLocalizations.of(context).saveOption),
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
    if (u == 'ton' ||
        u == 'tonne' ||
        u == AppLocalizations.of(context).metricTon) {
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
    if (u == AppLocalizations.of(context).halfDozen || u == 'half-dozen') {
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
    if (val == AppLocalizations.of(context).halfDozen || val == 'half-dozen') {
      return const MapEntry(6.0, 'pcs');
    }
    if (val == 'dozen' || val == AppLocalizations.of(context).msg1Dozen) {
      return const MapEntry(12.0, 'pcs');
    }
    if (val == 'pair' || val == AppLocalizations.of(context).msg1Pair) {
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

  /// Proportional auto-pricing helper for a single variant unit value based on the primary product's base price and base unit.
  double _calculateVariantAutoPrice({required double variantUnitValue}) {
    final baseSellingPrice = double.tryParse(_discountPriceCtrl.text) ?? 0.0;
    final baseMrp = double.tryParse(_priceCtrl.text) ?? 0.0;
    final effectiveBasePrice = baseSellingPrice > 0
        ? baseSellingPrice
        : baseMrp;
    final baseUnitQty = double.tryParse(_unitCtrl.text) ?? 1.0;
    final baseUnitType = _unitTypeCtrl.text.trim().toLowerCase();

    if (effectiveBasePrice <= 0 || baseUnitQty <= 0 || variantUnitValue <= 0) {
      return effectiveBasePrice;
    }

    final baseCanonical = _toCanonicalUnit(
      baseUnitQty,
      baseUnitType,
      _measurementType,
    );
    final variantCanonical = _toCanonicalUnit(
      variantUnitValue,
      baseUnitType,
      _measurementType,
    );

    if (baseCanonical != null &&
        variantCanonical != null &&
        baseCanonical > 0) {
      final computed = (variantCanonical / baseCanonical) * effectiveBasePrice;
      return double.parse(computed.toStringAsFixed(2));
    }

    final computed = (variantUnitValue / baseUnitQty) * effectiveBasePrice;
    return double.parse(computed.toStringAsFixed(2));
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

  /// Computes the Cartesian Product matrix of all options with intelligent auto-pricing and locked unit type.
  void _generateVariantMatrix() {
    if (!_isVariantSectionEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).pleaseCompleteTheRequiredProductDetailsAboveBeforeGeneratingMatrix(
              _missingBaseFields.join(', '),
            ),
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    if (_options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).pleaseAddAtLeastOneOptionFirstToGenerateCombinations,
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
        : AppLocalizations.of(context).sku;
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
        ? _unitTypeCtrl.text.trim().toLowerCase()
        : (_measurementType == 'weight_based' ? 'kg' : 'pieces');

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

      // Extract variant unit value from combo attributes
      double variantUnitVal = baseUnitQty;
      for (final entry in combo.entries) {
        final parsed = _parseQuantityAndUnit(
          entry.value,
          entry.key,
          baseUnitType,
        );
        if (parsed != null) {
          variantUnitVal = parsed.key;
          break;
        }
      }

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
        unitValue: (existing != null && existing.unitValue > 0)
            ? existing.unitValue
            : variantUnitVal,
        unitType: baseUnitType, // Globally locked to base product unit type
        size:
            combo[AppLocalizations.of(context).size] ??
            combo[AppLocalizations.of(context).weight] ??
            combo[AppLocalizations.of(context).quantity] ??
            combo[AppLocalizations.of(context).pack] ??
            combo[AppLocalizations.of(context).volume] ??
            '',
        color: combo[AppLocalizations.of(context).color] ?? '',
      );
    }).toList();

    setState(() {
      _variants.clear();
      _variants.addAll(newVariants);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(
            context,
          ).generatedVariantCombinationsWithLockedUnitAutoCalculatedPrices(
            '${_variants.length}',
            baseUnitType,
          ),
        ),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  void _showAddManualVariantDialog() {
    if (!_isVariantSectionEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).pleaseCompleteTheRequiredProductDetailsAboveBeforeAddingVariants(
              _missingBaseFields.join(', '),
            ),
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final lockedUnitType = _unitTypeCtrl.text.trim().toLowerCase().isNotEmpty
        ? _unitTypeCtrl.text.trim().toLowerCase()
        : (_measurementType == 'weight_based' ? 'kg' : 'pieces');

    final skuCtrl = TextEditingController(
      text:
          'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final unitValCtrl = TextEditingController(
      text: _unitCtrl.text.trim().isNotEmpty ? _unitCtrl.text.trim() : '1',
    );
    final colorCtrl = TextEditingController(text: _colorCtrl.text.trim());
    final labelCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final priceOverrideCtrl = TextEditingController();
    bool variantUnlimited = _stockMode == 'unlimited';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final typedUnitVal = double.tryParse(unitValCtrl.text.trim()) ?? 0.0;
          final calculatedAutoPrice = _calculateVariantAutoPrice(
            variantUnitValue: typedUnitVal > 0 ? typedUnitVal : 1.0,
          );

          return AlertDialog(
            title: Text(AppLocalizations.of(context).addProductVariant),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Locked Unit Type Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).unitTypeLockedFromBaseProduct(lockedUnitType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Unit Value (Required)
                  TextField(
                    controller: unitValCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).unitValue,
                      hintText: AppLocalizations.of(context).eG500125,
                      suffixText: lockedUnitType,
                      prefixIcon: const Icon(Icons.scale),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Color Variant Field
                  TextField(
                    controller: colorCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).colorOptional,
                      hintText: AppLocalizations.of(
                        context,
                      ).eGRedMidnightBlueBlack,
                      prefixIcon: const Icon(Icons.palette_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Optional Variant Title / Label
                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).variantLabelNameOptional,
                      hintText: AppLocalizations.of(
                        context,
                      ).eGLarge500PackOf2(lockedUnitType),
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // SKU
                  TextField(
                    controller: skuCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).sku2,
                      hintText: AppLocalizations.of(context).eGSku500g01,
                      prefixIcon: const Icon(Icons.qr_code_2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Stock Availability (Required)
                  Text(
                    AppLocalizations.of(context).stockAvailability,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context).unlimitedInventory,
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: variantUnlimited,
                    onChanged: (val) =>
                        setDialogState(() => variantUnlimited = val),
                  ),
                  if (!variantUnlimited) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).stockQuantity,
                        prefixIcon: const Icon(Icons.warehouse_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 3. Price & Auto-Calculation
                  TextField(
                    controller: priceOverrideCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).price,
                      hintText: AppLocalizations.of(
                        context,
                      ).auto(calculatedAutoPrice.toStringAsFixed(2)),
                      helperText: priceOverrideCtrl.text.trim().isEmpty
                          ? AppLocalizations.of(
                              context,
                            ).blankAutoCalculatesToBasedOnBasePrice(
                              calculatedAutoPrice.toStringAsFixed(2),
                            )
                          : AppLocalizations.of(
                              context,
                            ).customPriceOverrideApplied,
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.currency_rupee),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              FilledButton(
                onPressed: () {
                  final sku = skuCtrl.text.trim();
                  if (sku.isEmpty) return;

                  final unitVal =
                      double.tryParse(unitValCtrl.text.trim()) ??
                      (double.tryParse(_unitCtrl.text) ?? 1.0);
                  final enteredPrice = double.tryParse(
                    priceOverrideCtrl.text.trim(),
                  );
                  final finalPrice = (enteredPrice != null && enteredPrice > 0)
                      ? enteredPrice
                      : _calculateVariantAutoPrice(variantUnitValue: unitVal);

                  final customLabel = labelCtrl.text.trim();
                  final colorVal = colorCtrl.text.trim();
                  final defaultTitle =
                      '$unitVal $lockedUnitType${colorVal.isNotEmpty ? " / $colorVal" : ""}';
                  final title = customLabel.isNotEmpty
                      ? customLabel
                      : defaultTitle;

                  final attrs = <String, String>{
                    AppLocalizations.of(context).unit:
                        '$unitVal $lockedUnitType',
                    if (colorVal.isNotEmpty)
                      AppLocalizations.of(context).color: colorVal,
                    if (customLabel.isNotEmpty)
                      AppLocalizations.of(context).option: customLabel,
                  };

                  final variant = ProductVariant(
                    sku: sku,
                    title: title,
                    attributes: attrs,
                    size: title,
                    color: colorVal,
                    unitValue: unitVal,
                    unitType: lockedUnitType,
                    isUnlimitedStock: variantUnlimited,
                    stockQty: variantUnlimited
                        ? 0
                        : (int.tryParse(stockCtrl.text) ?? 0),
                    priceOverride: finalPrice,
                  );

                  setState(() => _variants.add(variant));
                  Navigator.pop(ctx);
                },
                child: Text(AppLocalizations.of(context).addVariant),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editVariant(int index) {
    final v = _variants[index];
    final lockedUnitType = _unitTypeCtrl.text.trim().toLowerCase().isNotEmpty
        ? _unitTypeCtrl.text.trim().toLowerCase()
        : (_measurementType == 'weight_based' ? 'kg' : 'pieces');

    final skuCtrl = TextEditingController(text: v.sku);
    final unitValCtrl = TextEditingController(
      text: v.unitValue > 0
          ? (v.unitValue == v.unitValue.roundToDouble()
                ? v.unitValue.toInt().toString()
                : v.unitValue.toString())
          : (_unitCtrl.text.trim().isNotEmpty ? _unitCtrl.text.trim() : '1'),
    );
    final colorCtrl = TextEditingController(text: v.color);
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
        builder: (context, setDialogState) {
          final typedUnitVal = double.tryParse(unitValCtrl.text.trim()) ?? 0.0;
          final calculatedAutoPrice = _calculateVariantAutoPrice(
            variantUnitValue: typedUnitVal > 0 ? typedUnitVal : 1.0,
          );

          return AlertDialog(
            title: Text(
              AppLocalizations.of(
                context,
              ).editVariant(v.title.isNotEmpty ? v.title : v.sku),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Locked Unit Type Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).unitTypeLockedFromBaseProduct(lockedUnitType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Unit Value (Required)
                  TextField(
                    controller: unitValCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).unitValue,
                      hintText: AppLocalizations.of(context).eG500125,
                      suffixText: lockedUnitType,
                      prefixIcon: const Icon(Icons.scale),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Color Variant Field
                  TextField(
                    controller: colorCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).colorOptional,
                      hintText: AppLocalizations.of(
                        context,
                      ).eGRedMidnightBlueBlack,
                      prefixIcon: const Icon(Icons.palette_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // SKU
                  TextField(
                    controller: skuCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).sku,
                      prefixIcon: const Icon(Icons.qr_code_2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Stock Availability (Required)
                  Text(
                    AppLocalizations.of(context).stockAvailability,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context).unlimitedInventory,
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: variantUnlimited,
                    onChanged: (val) =>
                        setDialogState(() => variantUnlimited = val),
                  ),
                  if (!variantUnlimited) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).stockQuantity,
                        prefixIcon: const Icon(Icons.warehouse_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 3. Price & Auto-Calculation
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).price,
                      hintText: AppLocalizations.of(
                        context,
                      ).auto(calculatedAutoPrice.toStringAsFixed(2)),
                      helperText: priceCtrl.text.trim().isEmpty
                          ? AppLocalizations.of(
                              context,
                            ).blankAutoCalculatesToBasedOnBasePrice(
                              calculatedAutoPrice.toStringAsFixed(2),
                            )
                          : AppLocalizations.of(
                              context,
                            ).customPriceOverrideApplied,
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.currency_rupee),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              FilledButton(
                onPressed: () {
                  final unitVal =
                      double.tryParse(unitValCtrl.text.trim()) ??
                      (v.unitValue > 0 ? v.unitValue : 1.0);
                  final enteredPrice = double.tryParse(priceCtrl.text.trim());
                  final finalPrice = (enteredPrice != null && enteredPrice > 0)
                      ? enteredPrice
                      : _calculateVariantAutoPrice(variantUnitValue: unitVal);
                  final colorVal = colorCtrl.text.trim();
                  final updatedAttrs = Map<String, String>.from(v.attributes);
                  if (colorVal.isNotEmpty) {
                    updatedAttrs[AppLocalizations.of(context).color] = colorVal;
                  } else {
                    updatedAttrs.remove(AppLocalizations.of(context).color);
                  }

                  setState(() {
                    _variants[index] = v.copyWith(
                      sku: skuCtrl.text.trim().isNotEmpty
                          ? skuCtrl.text.trim()
                          : v.sku,
                      unitValue: unitVal,
                      unitType: lockedUnitType,
                      color: colorVal,
                      attributes: updatedAttrs,
                      isUnlimitedStock: variantUnlimited,
                      stockQty: variantUnlimited
                          ? 0
                          : (int.tryParse(stockCtrl.text) ?? v.stockQty),
                      priceOverride: finalPrice,
                    );
                  });
                  Navigator.pop(ctx);
                },
                child: Text(AppLocalizations.of(context).save),
              ),
            ],
          );
        },
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
        SnackBar(
          content: Text(
            AppLocalizations.of(context).pleaseCheckAllRequiredFields,
          ),
        ),
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

      // Structured content: drop untouched rows/sections, then validate.
      final highlights = _highlights.where((h) => !h.isEmpty).toList();
      final allDetails = _allDetails
          .where((s) => s.title.trim().isNotEmpty || !s.isEmptyContent)
          .toList();
      if (highlights.any((h) => h.isHalfWritten) ||
          !HighlightsEditor.isValid(highlights) ||
          !AllDetailsEditor.isValid(allDetails)) {
        if (mounted) {
          setState(() => _contentShowErrors = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).pleaseCompleteTheProductHighlightsAndAllDetailsSections,
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final product = Product(
        id: resolvedId,
        companyId: _companyId,
        name: _nameCtrl.text.trim(),
        // Legacy fields kept in sync until the data migration is confirmed.
        details: _legacyDescription(allDetails),
        subDetails: _legacySubDetails(highlights),
        color: _colorCtrl.text.trim(),
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
        highlights: [
          for (var i = 0; i < highlights.length; i++)
            highlights[i].copyWith(order: i),
        ],
        allDetails: [
          for (var i = 0; i < allDetails.length; i++)
            allDetails[i].copyWith(order: i),
        ],
        policy: _policyCtrl.text.trim(),
      );

      await repo.saveProduct(product);

      int removedTrendingCount = 0;
      bool trendingCleanupFailed = false;
      Object? trendingCleanupError;

      if (isEditMode) {
        try {
          removedTrendingCount = await repo.removeProductFromTrendingNow(
            shopId: product.companyId,
            productId: product.id,
          );
        } catch (err) {
          trendingCleanupFailed = true;
          trendingCleanupError = err;
        }
      }

      if (!mounted) return;

      if (trendingCleanupFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).productUpdatedSuccessfully(product.name)}, but removing from Trending Now failed: $trendingCleanupError',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final errColor = Theme.of(context).colorScheme.error;
                try {
                  final retryCount = await repo.removeProductFromTrendingNow(
                    shopId: product.companyId,
                    productId: product.id,
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        retryCount > 0
                            ? 'Successfully removed ${product.name} from Trending Now.'
                            : 'No active Trending Now entry found for ${product.name}.',
                      ),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                } catch (retryErr) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Retry failed: $retryErr'),
                      backgroundColor: errColor,
                    ),
                  );
                }
              },
            ),
          ),
        );
      } else {
        final successMsg = (isEditMode && removedTrendingCount > 0)
            ? '${AppLocalizations.of(context).productUpdatedSuccessfully(product.name)} (removed from Trending Now)'
            : (isEditMode
                  ? AppLocalizations.of(
                      context,
                    ).productUpdatedSuccessfully(product.name)
                  : AppLocalizations.of(
                      context,
                    ).productCreatedSuccessfully(product.name));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }

      if (context.canPop()) {
        context.pop();
      } else {
        try {
          context.go(AppRoutes.adminProducts);
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToSaveProduct('$e')),
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
        appBar: AppBar(title: Text(AppLocalizations.of(context).editProduct)),
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

    bool canPop() {
      try {
        return context.canPop();
      } catch (_) {
        return Navigator.of(context).canPop();
      }
    }

    void handleBack() {
      try {
        if (context.canPop()) {
          context.pop();
          return;
        }
      } catch (_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }
      }
      try {
        context.go(AppRoutes.adminProducts);
      } catch (_) {}
    }

    return PopScope(
      canPop: canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          handleBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditMode
                ? AppLocalizations.of(context).editProduct
                : AppLocalizations.of(context).addNewProduct,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: handleBack,
          ),
          actions: [
            if (isEditMode && widget.product != null)
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
                tooltip: 'QR Code & Share Link',
                onPressed: () {
                  final p = widget.product!;
                  final shopId = p.companyId.isNotEmpty
                      ? p.companyId
                      : (_companyId.isNotEmpty ? _companyId : 'masala-mart');
                  showEntityQrDialog(
                    context: context,
                    type: QrEntityType.product,
                    title: p.name,
                    shopId: shopId,
                    shopName: AdminCompanyName.instance.displayName(
                      AuthSession.currentUser,
                      fallback: shopId,
                    ),
                    productId: p.id,
                    subtitle: 'Product ID: ${p.id} · Shop: $shopId',
                  );
                },
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Full width of the screen; a little more side padding on
            // wide screens so fields don't touch the window edge.
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width >= 900 ? 32 : 20,
              vertical: 24,
            ),
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
                            AppLocalizations.of(context).productSpecification,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEditMode
                                ? AppLocalizations.of(
                                    context,
                                  ).updateCatalogItemDetailsPricingImagesVariantsAndSpecifications
                                : AppLocalizations.of(
                                    context,
                                  ).createNewCatalogItemsWithDynamicVariantsCustomOptionsGalleryAndInventoryControls,
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                                      ? AppLocalizations.of(
                                          context,
                                        ).companyScope
                                      : AppLocalizations.of(
                                          context,
                                        ).globalScope),
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
                              AppLocalizations.of(context).basicInformation,
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
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).productTitle,
                          hintText: AppLocalizations.of(
                            context,
                          ).eGOrganicHassAvocadoChanderiSilkSaree15In1SweetsBox,
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(
                                context,
                              ).productTitleIsRequired2
                            : null,
                      ),
                      const SizedBox(height: 16),
                      HighlightsEditor(
                        value: _highlights,
                        showErrors: _contentShowErrors,
                        onChanged: (rows) => setState(() => _highlights = rows),
                      ),
                      const SizedBox(height: 20),
                      AllDetailsEditor(
                        value: _allDetails,
                        showErrors: _contentShowErrors,
                        onChanged: (sections) =>
                            setState(() => _allDetails = sections),
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
                              AppLocalizations.of(context).productGallery,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).added('${_images.length}'),
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
                        AppLocalizations.of(
                          context,
                        ).addMultipleImageUrlsTheFirstImageWillAutomaticallyActAsTheHeroMainProductImage,
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
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(
                                  context,
                                ).imageUrl,
                                hintText: AppLocalizations.of(
                                  context,
                                ).httpsImagesUnsplashCom,
                                prefixIcon: const Icon(Icons.link),
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
                            label: Text(AppLocalizations.of(context).add),
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
                                    // Tap the photo to view it full screen.
                                    GestureDetector(
                                      key: Key('product-image-thumb-$idx'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => showFullScreenImages(
                                        context,
                                        urls: _images,
                                        initialIndex: idx,
                                      ),
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Container(
                                            width: 105,
                                            height: 110,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isHero
                                                    ? theme.colorScheme.primary
                                                    : (isDark
                                                          ? AppTheme.borderDark
                                                          : AppTheme
                                                                .borderLight),
                                                width: isHero ? 2 : 1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: AppProductImage(
                                              url: url,
                                              width: 105,
                                              height: 110,
                                              fit: BoxFit.cover,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              fallback: Container(
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
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                ).heroMain,
                                                style: const TextStyle(
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
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  ).makeHero,
                                                  style: const TextStyle(
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
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).mrpOriginalPrice,
                          hintText: AppLocalizations.of(context).eG99900,
                          prefixIcon: const Icon(Icons.currency_rupee),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return AppLocalizations.of(context).enterPrice;
                          }
                          if (double.tryParse(v) == null) {
                            return AppLocalizations.of(context).validNumber;
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
                          labelText: AppLocalizations.of(
                            context,
                          ).sellingDiscountedPrice,
                          hintText: AppLocalizations.of(context).eG79900,
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
                                    AppLocalizations.of(
                                      context,
                                    ).off('$discountPercent'),
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
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).baseSkuProductCode,
                          hintText: AppLocalizations.of(context).eGProdHoney01,
                          prefixIcon: const Icon(Icons.qr_code_2),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(context).msgRequired
                            : null,
                      );

                      final colorField = TextFormField(
                        controller: _colorCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).productBaseColorOptional,
                          hintText: AppLocalizations.of(
                            context,
                          ).eGRedMidnightBlueMatteBlack,
                          prefixIcon: const Icon(Icons.palette_outlined),
                        ),
                      );

                      final stockField = TextFormField(
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).stockQuantity,
                          hintText: AppLocalizations.of(
                            context,
                          ).availableInventoryUnits,
                          prefixIcon: const Icon(Icons.warehouse_outlined),
                        ),
                        validator: (v) {
                          if (_stockMode == 'specific') {
                            if (v == null || v.trim().isEmpty) {
                              return AppLocalizations.of(
                                context,
                              ).enterInventoryCount;
                            }
                            if (int.tryParse(v) == null) {
                              return AppLocalizations.of(context).validInteger;
                            }
                          }
                          return null;
                        },
                      );

                      final unitValField = TextFormField(
                        controller: _unitCtrl,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).unitValue,
                          hintText: AppLocalizations.of(context).eG1Or500,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(context).msgRequired
                            : null,
                      );

                      final unitTypeField = DropdownButtonFormField<String>(
                        key: ValueKey(
                          'unit_type_${_measurementType}_${_unitTypeCtrl.text}',
                        ),
                        initialValue:
                            _currentUnitTypes.contains(
                              _unitTypeCtrl.text.trim().toLowerCase(),
                            )
                            ? _unitTypeCtrl.text.trim().toLowerCase()
                            : _currentUnitTypes.first,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).unitType,
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                        items: _currentUnitTypes.map((u) {
                          return DropdownMenuItem<String>(
                            value: u,
                            child: Text(u),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _syncUnitTypeToVariantsAndOptions(val);
                          }
                        },
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(context).msgRequired
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
                                  AppLocalizations.of(
                                    context,
                                  ).pricingMeasurement,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
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
                          if (isNarrow) ...[
                            skuField,
                            const SizedBox(height: 14),
                            colorField,
                          ] else
                            Row(
                              children: [
                                Expanded(child: skuField),
                                const SizedBox(width: 16),
                                Expanded(child: colorField),
                              ],
                            ),
                          const SizedBox(height: 20),

                          // Stock Availability Selection (Specific Count / Unlimited / Finished)
                          Text(
                            AppLocalizations.of(
                              context,
                            ).stockAvailabilityInventoryMode,
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
                                    isNarrow
                                        ? AppLocalizations.of(context).count
                                        : AppLocalizations.of(
                                            context,
                                          ).specificCount,
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
                                        ? AppLocalizations.of(context).unlimited
                                        : AppLocalizations.of(
                                            context,
                                          ).unlimitedStock,
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
                                        ? AppLocalizations.of(
                                            context,
                                          ).outOfStock2
                                        : AppLocalizations.of(
                                            context,
                                          ).finishedOutOfStock,
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
                                      AppLocalizations.of(
                                        context,
                                      ).unlimitedInventoryProductWillAlwaysAppearInStockForCustomersIdealForDigitalGoodsOrMadeToOrderItems,
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
                                      AppLocalizations.of(
                                        context,
                                      ).outOfStockFinishedProductWillShowAsSoldOutOnTheStorefrontUntilRestocked,
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
                            AppLocalizations.of(context).baseMeasurementType,
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
                                    isNarrow
                                        ? AppLocalizations.of(context).quantity
                                        : AppLocalizations.of(
                                            context,
                                          ).quantityBased2,
                                  ),
                                  icon: const Icon(Icons.tag, size: 18),
                                ),
                                ButtonSegment<String>(
                                  value: 'weight_based',
                                  label: Text(
                                    isNarrow
                                        ? AppLocalizations.of(context).weight
                                        : AppLocalizations.of(
                                            context,
                                          ).weightBased2,
                                  ),
                                  icon: const Icon(Icons.scale, size: 18),
                                ),
                              ],
                              selected: {_measurementType},
                              onSelectionChanged: (set) => setState(() {
                                _measurementType = set.first;
                                final available = _currentUnitTypes;
                                final targetUnit =
                                    available.contains(
                                      _unitTypeCtrl.text.trim().toLowerCase(),
                                    )
                                    ? _unitTypeCtrl.text.trim().toLowerCase()
                                    : available.first;
                                _syncUnitTypeToVariantsAndOptions(targetUnit);
                              }),
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
                            children: _currentUnitTypes.map((u) {
                              return ActionChip(
                                label: Text(
                                  u,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () =>
                                    _syncUnitTypeToVariantsAndOptions(u),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                AppLocalizations.of(
                                  context,
                                ).featuredRecommendation,
                              ),
                              subtitle: Text(
                                AppLocalizations.of(
                                  context,
                                ).flagThisProductToAppearInTheRecommendationsEngineCarousel,
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
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune,
                                    color: _isVariantSectionEnabled
                                        ? theme.colorScheme.primary
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context).variantMatrix,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              if (_isVariantSectionEnabled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 13,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context).ready,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 13,
                                        color: Colors.amber.shade900,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context).locked,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isVariantSectionEnabled
                                    ? _showAddOptionDialog
                                    : null,
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(
                                  AppLocalizations.of(context).addOption,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _isVariantSectionEnabled
                                    ? _generateVariantMatrix
                                    : null,
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                label: Text(
                                  AppLocalizations.of(context).generateMatrix,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _isVariantSectionEnabled
                                    ? _showAddManualVariantDialog
                                    : null,
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(
                                  AppLocalizations.of(context).addVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).configureCustomizableOptionTypesEGSizeColorWeightStorageAndAutomaticallyGenerateCartesianCombinationsWithDistinctSkuStockAndPriceOverrides,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!_isVariantSectionEnabled) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: Colors.amber.shade900,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      ).variantConfigurationLocked,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).pleaseEnterTheRequiredPrimaryProductDetailsAboveToUnlockVariantOptionsAndMatrixGeneration,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _missingBaseFields.map((field) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.amber.shade400,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          size: 10,
                                          color: Colors.amber.shade900,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          field,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Option Types List
                      if (_options.isNotEmpty) ...[
                        Text(
                          AppLocalizations.of(context).configuredOptionSets,
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
                              AppLocalizations.of(
                                context,
                              ).noVariantsConfiguredSingleStandardSkuTapAddOptionToDefineDimensionsThenGenerateMatrix,
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
                              AppLocalizations.of(
                                context,
                              ).variantCombinations('${_variants.length}'),
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
                                                    fontWeight: FontWeight.bold,
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
                                                  color: Colors.grey.withValues(
                                                    alpha: 0.2,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                            AppLocalizations.of(
                                              context,
                                            ).unitStock(
                                              '${_variants[idx].unitValue > 0 ? (_variants[idx].unitValue == _variants[idx].unitValue.roundToDouble() ? _variants[idx].unitValue.toInt() : _variants[idx].unitValue) : (_variants[idx].size.isNotEmpty ? _variants[idx].size : "1")}',
                                              _variants[idx].unitType.isNotEmpty
                                                  ? _variants[idx].unitType
                                                  : _unitTypeCtrl.text.trim(),
                                              '${_variants[idx].isUnlimitedStock ? AppLocalizations.of(context).unlimited : _variants[idx].stockQty}',
                                              _variants[idx].priceOverride > 0
                                                  ? AppLocalizations.of(
                                                      context,
                                                    ).price2(
                                                      '${_variants[idx].priceOverride % 1 == 0 ? _variants[idx].priceOverride.toInt() : _variants[idx].priceOverride.toStringAsFixed(2)}',
                                                    )
                                                  : AppLocalizations.of(
                                                      context,
                                                    ).basePrice,
                                              _variants[idx]
                                                      .attributes
                                                      .isNotEmpty
                                                  ? " • ${_variants[idx].attributes.entries.map((e) => "${e.key}: ${e.value}").join(", ")}"
                                                  : '',
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppTheme.textSecondaryDark
                                                  : AppTheme.textSecondaryLight,
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
                                      tooltip: AppLocalizations.of(
                                        context,
                                      ).editStockPriceOverride,
                                      onPressed: () => _editVariant(idx),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      tooltip: AppLocalizations.of(
                                        context,
                                      ).remove,
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
                              AppLocalizations.of(
                                context,
                              ).specificationsPolicies,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addSpecRow,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              AppLocalizations.of(context).addSpec,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).addDynamicKeyValueSpecificationsEGFabricShelfLifeProcessorStorageOriginAndReturnDeliveryPolicies,
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
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(
                                      context,
                                    ).specKey,
                                    hintText: AppLocalizations.of(
                                      context,
                                    ).eGFabricShelfLife,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _specControllers[i].value,
                                  decoration: InputDecoration(
                                    labelText: AppLocalizations.of(
                                      context,
                                    ).specValue,
                                    hintText: AppLocalizations.of(
                                      context,
                                    ).eGPureSilk30Days,
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
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).deliveryReturnPolicy,
                          hintText: AppLocalizations.of(
                            context,
                          ).eGFreeShippingOnOrdersAbove499Easy7DayHassleFreeReplacementForDefectiveProducts,
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.local_shipping_outlined),
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
                  text: isEditMode
                      ? AppLocalizations.of(context).updateProduct
                      : AppLocalizations.of(context).createProduct,
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
    );
  }
}

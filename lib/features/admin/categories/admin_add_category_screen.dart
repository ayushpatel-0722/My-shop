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
import 'widgets/product_assignment_picker.dart';

/// Screen for creating and editing a Category with dual-panel product assignment.
///
/// Features:
/// - Create mode: fresh form, auto-assigned companyId from session.
/// - Edit mode: pre-filled fields, pre-populated assigned product list.
/// - Required fields validation:
///   - `name`: trimmed, non-empty, unique (case-insensitive) within same company.
///   - `type`: broad classification, required.
///   - `parentId`: nesting hierarchy with cycle prevention (blocks self and descendants).
///   - `iconUrl`: single image link/emoji with visual preview; defaults to '🛍️'.
///   - `companyId`: auto-assigned from admin session, read-only.
///   - `productList`: auto-managed through [ProductAssignmentPicker].
class AdminAddCategoryScreen extends StatefulWidget {
  final Category? category;
  final String? categoryId;

  const AdminAddCategoryScreen({super.key, this.category, this.categoryId});

  @override
  State<AdminAddCategoryScreen> createState() => _AdminAddCategoryScreenState();
}

class _AdminAddCategoryScreenState extends State<AdminAddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: 'Grocery');
  final _iconCtrl = TextEditingController(text: '🛍️');

  String _companyId = '';
  String _companyName = '';
  String? _selectedParentId;
  List<String> _selectedProductIds = [];
  bool _isSaving = false;
  bool _isLoadingCategory = false;
  String? _loadedCategoryId;

  final List<String> _suggestedEmojis = [
    '🛍️',
    '🍎',
    '🥦',
    '🥛',
    '🥩',
    '🍞',
    '📱',
    '💻',
    '👕',
    '👟',
    '🧴',
    '💊',
    '🏠',
    '🎮',
  ];

  final List<String> _suggestedTypes = [
    'Grocery',
    'Electronics',
    'Fashion & Apparel',
    'Health & Beauty',
    'Home & Kitchen',
    'Bakery & Dairy',
    'Beverages',
    'Personal Care',
    'Sports & Outdoors',
    'Toys & Games',
  ];

  bool get isEditMode => widget.category != null || widget.categoryId != null;

  @override
  void initState() {
    super.initState();

    // Auto-set companyId from logged-in Admin's session, never manual
    final sessionCompanyId = AuthSession.currentUser?.companyId ?? '';
    final sessionCompanyName = AuthSession.currentUser?.companyName ?? '';
    _companyId = sessionCompanyId;
    _companyName = sessionCompanyName;

    if (_companyName.isEmpty && _companyId.isNotEmpty) {
      _loadCompanyName(_companyId);
    }

    if (widget.category != null) {
      _initFromCategory(widget.category!);
    } else if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      _loadCategoryById(widget.categoryId!);
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

  void _initFromCategory(Category cat) {
    _loadedCategoryId = cat.id;
    _nameCtrl.text = cat.name;
    _detailsCtrl.text = cat.details;
    _typeCtrl.text = cat.type.isNotEmpty ? cat.type : 'Grocery';
    _iconCtrl.text = cat.iconUrl.isNotEmpty ? cat.iconUrl : '🛍️';
    _selectedParentId = cat.parentId?.isNotEmpty == true ? cat.parentId : null;
    _selectedProductIds = List<String>.from(cat.productList);
    if (cat.companyId.isNotEmpty) {
      _companyId = cat.companyId;
    }
  }

  Future<void> _loadCategoryById(String id) async {
    setState(() => _isLoadingCategory = true);
    try {
      final cat = await repo.category(id, companyId: _companyId);
      if (cat != null && mounted) {
        _initFromCategory(cat);
      }
    } catch (_) {
      // Ignored; fallback to empty
    } finally {
      if (mounted) setState(() => _isLoadingCategory = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _detailsCtrl.dispose();
    _typeCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  /// Calculates all descendant category IDs of [rootId] to prevent cycle formation.
  Set<String> _getDescendantIds(String rootId, List<Category> allCategories) {
    final descendants = <String>{};
    final queue = <String>[rootId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final cat in allCategories) {
        if (cat.parentId == current && !descendants.contains(cat.id)) {
          descendants.add(cat.id);
          queue.add(cat.id);
        }
      }
    }
    return descendants;
  }

  Future<void> _handleSave(List<Category> existingCategories) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one product for the category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final trimmedName = _nameCtrl.text.trim();
    final trimmedType = _typeCtrl.text.trim();
    final currentCatId =
        _loadedCategoryId ?? widget.category?.id ?? widget.categoryId ?? '';

    // 1. Validate Name uniqueness (case-insensitive) within the same companyId
    final isDuplicate = existingCategories.any((cat) {
      if (currentCatId.isNotEmpty && cat.id == currentCatId) return false;
      final sameCompany =
          cat.companyId == _companyId ||
          (_companyId.isEmpty && cat.companyId.isEmpty);
      return sameCompany &&
          cat.name.trim().toLowerCase() == trimmedName.toLowerCase();
    });

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A category named "$trimmedName" already exists in this company.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // 2. Validate parentId cycle prevention
    if (currentCatId.isNotEmpty && _selectedParentId != null) {
      if (_selectedParentId == currentCatId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('A category cannot have itself as its parent.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final descendants = _getDescendantIds(currentCatId, existingCategories);
      if (descendants.contains(_selectedParentId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Invalid parent: Selecting a descendant category creates a cycle.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final category = Category(
        id: currentCatId,
        companyId: _companyId,
        name: trimmedName,
        details: _detailsCtrl.text.trim(),
        type: trimmedType,
        parentId: _selectedParentId?.isNotEmpty == true
            ? _selectedParentId
            : null,
        iconUrl: _iconCtrl.text.trim().isEmpty ? '🛍️' : _iconCtrl.text.trim(),
        productList: _selectedProductIds,
      );

      await repo.saveCategory(category);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Category "${category.name}" updated successfully!'
                : 'Category "${category.name}" created successfully!',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.adminCategories);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save category: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildIconPreview(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconVal = _iconCtrl.text.trim();

    final isHttp =
        iconVal.startsWith('http://') || iconVal.startsWith('https://');

    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
        ),
      ),
      child: isHttp
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                iconVal,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 28),
              ),
            )
          : Text(
              iconVal.isNotEmpty ? iconVal : '🛍️',
              style: const TextStyle(fontSize: 32),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingCategory) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Category...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<Category>>(
      stream: repo.categories(companyId: _companyId),
      builder: (context, catSnap) {
        final existingCategories = catSnap.data ?? const <Category>[];

        final currentCatId =
            _loadedCategoryId ?? widget.category?.id ?? widget.categoryId ?? '';
        final invalidParentIds = currentCatId.isNotEmpty
            ? ({
                currentCatId,
                ..._getDescendantIds(currentCatId, existingCategories),
              })
            : <String>{};

        // Allowed parent categories (filter out self and any descendants)
        final validParentCategories = existingCategories
            .where((c) => !invalidParentIds.contains(c.id))
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(isEditMode ? 'Edit Category' : 'Add New Category'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.adminCategories);
                }
              },
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    // Header Info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditMode
                                    ? 'Edit Category'
                                    : 'Category Details',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configure hierarchy, catalog classification, and assigned products.',
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
                        // Read-only Company Scope Pill (Auto-assigned)
                        Flexible(
                          child: Container(
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
                                Flexible(
                                  child: Text(
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Card 1: Core Information (Name, Type, Details)
                    ModernCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.label_outline,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Basic Information',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Category Name *',
                              hintText: 'e.g. Fresh Organic Vegetables',
                              prefixIcon: Icon(Icons.drive_file_rename_outline),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Category name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _typeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Classification / Type *',
                              hintText: 'e.g. Grocery, Electronics',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Classification type is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _suggestedTypes.map((type) {
                              final isSelected = _typeCtrl.text.trim() == type;
                              return ChoiceChip(
                                label: Text(
                                  type,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _typeCtrl.text = type);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _detailsCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Description / Details',
                              hintText:
                                  'Description shown on the category header...',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 2: Icon & Visual Branding
                    ModernCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Icon & Visuals',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildIconPreview(context),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _iconCtrl,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Category Icon (Image URL or Emoji)',
                                    hintText:
                                        'Enter image URL or emoji (e.g. 🛍️)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Quick select emoji:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _suggestedEmojis.map((emoji) {
                              return ActionChip(
                                label: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                onPressed: () =>
                                    setState(() => _iconCtrl.text = emoji),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 3: Nesting Hierarchy & Cycle Prevention
                    ModernCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_tree_outlined,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hierarchy & Nesting',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Assign an existing parent category in the same company for nesting. '
                            'Self and descendant categories are automatically blocked to prevent hierarchy cycles.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue:
                                validParentCategories.any(
                                  (c) => c.id == _selectedParentId,
                                )
                                ? _selectedParentId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Parent Category',
                              prefixIcon: Icon(Icons.subdirectory_arrow_right),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'None (Top-Level Category)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...validParentCategories.map((c) {
                                final prefix = (c.hasIcon && !c.hasImageIcon)
                                    ? '${c.iconUrl} '
                                    : '📁 ';
                                return DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(
                                    '$prefix${c.name}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedParentId = val),
                          ),
                          if (invalidParentIds.isNotEmpty && isEditMode) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Note: ${invalidParentIds.length} categories (this category and its descendants) are blocked from being chosen as parent.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card 4: Interactive Product Assignment Picker
                    StreamBuilder<List<Product>>(
                      stream: repo.products(companyId: _companyId),
                      builder: (context, prodSnap) {
                        final allCompanyProducts =
                            prodSnap.data ?? const <Product>[];

                        return ModernCard(
                          padding: const EdgeInsets.all(20),
                          child: ProductAssignmentPicker(
                            allProducts: allCompanyProducts,
                            selectedProductIds: _selectedProductIds,
                            onSelectedChanged: (updatedList) {
                              setState(() => _selectedProductIds = updatedList);
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Save Action Button
                    ModernButton(
                      text: isEditMode ? 'Save Changes' : 'Create Category',
                      icon: const Icon(Icons.check, size: 20),
                      isLoading: _isSaving,
                      height: 52,
                      onPressed: _isSaving
                          ? null
                          : () => _handleSave(existingCategories),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

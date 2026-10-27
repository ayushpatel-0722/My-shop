import 'package:flutter/material.dart';

import '../../../core/models/category.dart';
import '../../../core/models/company.dart';
import '../../../core/models/home_explore_category.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/category_cover_builder.dart';
import '../admin_shell.dart';
import 'widgets/shop_selector_bar.dart';

/// Admin screen to manage category cards displayed in the user home screen's
/// "Explore Categories" section for a specific shop.
class AdminExploreCategoriesScreen extends StatefulWidget {
  const AdminExploreCategoriesScreen({super.key});

  @override
  State<AdminExploreCategoriesScreen> createState() =>
      _AdminExploreCategoriesScreenState();
}

class _AdminExploreCategoriesScreenState
    extends State<AdminExploreCategoriesScreen> {
  Company? _selectedShop;
  bool _isLoadingShop = true;

  @override
  void initState() {
    super.initState();
    _initShop();
  }

  Future<void> _initShop() async {
    final user = AuthSession.currentUser;
    final adminCompanyId = user?.companyId ?? '';

    final shops = await repo.companies().first;
    if (!mounted) return;

    if (adminCompanyId.isNotEmpty) {
      final found = shops.where((s) => s.id == adminCompanyId).firstOrNull;
      setState(() {
        _selectedShop =
            found ??
            Company(
              id: adminCompanyId,
              slug: adminCompanyId,
              name: user?.companyName.isNotEmpty == true
                  ? user!.companyName
                  : adminCompanyId,
            );
        _isLoadingShop = false;
      });
    } else if (shops.isNotEmpty) {
      // Default to Masala Mart if available, else first shop
      final masala = shops
          .where(
            (s) =>
                s.id == 'masala-mart' ||
                s.name.toLowerCase().contains('masala'),
          )
          .firstOrNull;
      setState(() {
        _selectedShop = masala ?? shops.first;
        _isLoadingShop = false;
      });
    } else {
      setState(() {
        _isLoadingShop = false;
      });
    }
  }

  void _onShopChanged(Company shop) {
    setState(() {
      _selectedShop = shop;
    });
  }

  void _showAddCategorySheet(
    BuildContext context,
    Company shop,
    List<HomeExploreCategory> existing,
  ) {
    final existingCategoryIds = existing.map((e) => e.categoryId).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.category_rounded,
                      color: Color(0xFFFF5247),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add Category to Explore (${shop.name})',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.60,
                  ),
                  child: CategoryCoverBuilder(
                    companyId: shop.id,
                    builder: (context, coverFor) => StreamBuilder<List<Category>>(
                      stream: repo.categories(companyId: shop.id),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final categories = snap.data ?? const <Category>[];
                        if (categories.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No categories found for this shop.\nPlease add categories first in Category Management.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final cat = categories[i];
                            final isAlreadyConfigured = existingCategoryIds
                                .contains(cat.id);

                            return ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildCategoryIcon(cat, coverFor(cat)),
                                ),
                              ),
                              title: Text(
                                cat.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isAlreadyConfigured
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF1E2229),
                                ),
                              ),
                              subtitle: Text(
                                'ID: ${cat.id}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: isAlreadyConfigured
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Already Added',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFFF5247,
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                      ),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await _addCategory(
                                          shop,
                                          cat,
                                          existing.length,
                                        );
                                      },
                                      child: const Text('Add'),
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addCategory(Company shop, Category cat, int nextOrder) async {
    final entry = HomeExploreCategory(
      id: '${shop.id}_${cat.id}',
      shopId: shop.id,
      shopName: shop.name,
      categoryId: cat.id,
      categoryName: cat.name,
      isActive: true,
      displayOrder: nextOrder,
      createdAt: DateTime.now(),
      createdBy: AuthSession.currentUser?.id ?? '',
    );

    await repo.saveHomeExploreCategory(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${cat.name}" to Explore Categories.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteCategory(HomeExploreCategory entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Category?'),
        content: Text(
          'Remove "${entry.categoryName.isNotEmpty ? entry.categoryName : entry.categoryId}" from Explore Categories on the home screen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await repo.deleteHomeExploreCategory(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed category from Explore Categories.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// The category's own image, else the photo of its first product that has
  /// one ([coverUrl]), else its emoji / a generic icon.
  Widget _buildCategoryIcon(Category cat, String? coverUrl) {
    final isImageIcon =
        cat.iconUrl.startsWith('http://') || cat.iconUrl.startsWith('https://');
    final image = isImageIcon ? cat.iconUrl : (coverUrl ?? '');
    if (image.isNotEmpty) {
      return Image.network(
        image,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackCategoryIcon(cat),
      );
    }
    return _fallbackCategoryIcon(cat);
  }

  Widget _fallbackCategoryIcon(Category cat) {
    if (cat.iconUrl.isNotEmpty && cat.iconUrl.runes.length <= 4) {
      return Center(
        child: Text(cat.iconUrl, style: const TextStyle(fontSize: 22)),
      );
    }
    return const Center(
      child: Icon(Icons.category_rounded, color: Color(0xFFFF5247), size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingShop) {
      return const AdminShell(
        title: 'Home Explore Categories',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final shop = _selectedShop;
    if (shop == null) {
      return AdminShell(
        title: 'Home Explore Categories',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No authorized shop found.'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _initShop, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return AdminShell(
      title: 'Home Explore Categories',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Help',
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Explore Categories'),
                content: const Text(
                  'Configure the categories that appear on the customer home screen in the "Explore Categories" section.\n\n'
                  '• Toggle the switch to activate/deactivate an item.\n'
                  '• Reorder using drag-and-drop or the Up/Down buttons.\n'
                  '• Delete an item to remove it from this shop\'s home screen section.\n'
                  '• If no categories are configured, the screen falls back to the default catalogue.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF5247),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
        onPressed: () async {
          final entries = await repo
              .homeExploreCategories(shopId: shop.id)
              .first;
          if (context.mounted) {
            _showAddCategorySheet(context, shop, entries);
          }
        },
      ),
      child: Column(
        children: [
          ShopSelectorBar(selectedShop: shop, onShopChanged: _onShopChanged),
          Expanded(
            child: StreamBuilder<List<HomeExploreCategory>>(
              stream: repo.homeExploreCategories(shopId: shop.id),
              builder: (context, configSnap) {
                if (configSnap.connectionState == ConnectionState.waiting &&
                    !configSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final entries =
                    configSnap.data ?? const <HomeExploreCategory>[];

                return CategoryCoverBuilder(
                  companyId: shop.id,
                  builder: (context, coverFor) => StreamBuilder<List<Category>>(
                    stream: repo.categories(companyId: shop.id),
                    builder: (context, catSnap) {
                      final categories = catSnap.data ?? const <Category>[];
                      final catMap = {for (final c in categories) c.id: c};

                      if (entries.isEmpty) {
                        return _buildEmptyState(context, shop, entries);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                            child: Row(
                              children: [
                                Text(
                                  '${entries.length} Configured Categories',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5247),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Category'),
                                  onPressed: () => _showAddCategorySheet(
                                    context,
                                    shop,
                                    entries,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: entries.length,
                              onReorderItem: (oldIndex, target) async {
                                final list = List<HomeExploreCategory>.from(
                                  entries,
                                );
                                final moved = list.removeAt(oldIndex);
                                list.insert(target, moved);
                                await repo.reorderHomeExploreCategories(list);
                              },
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final resolvedCat = catMap[entry.categoryId];
                                final displayName =
                                    resolvedCat?.name ??
                                    (entry.categoryName.isNotEmpty
                                        ? entry.categoryName
                                        : entry.categoryId);

                                return Container(
                                  key: ValueKey(entry.id),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: entry.isActive
                                          ? const Color(0xFFE2E8F0)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromRGBO(0, 0, 0, 0.02),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '#${index + 1}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEBEA),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: resolvedCat != null
                                                ? _buildCategoryIcon(
                                                    resolvedCat,
                                                    coverFor(resolvedCat),
                                                  )
                                                : const Icon(
                                                    Icons.category_outlined,
                                                    color: Color(0xFFFF5247),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      displayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: entry.isActive
                                            ? const Color(0xFF1E2229)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Category ID: ${entry.categoryId}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch.adaptive(
                                          value: entry.isActive,
                                          activeThumbColor: const Color(
                                            0xFFFF5247,
                                          ),
                                          onChanged: (val) async {
                                            await repo.saveHomeExploreCategory(
                                              entry.copyWith(isActive: val),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFDC2626),
                                            size: 20,
                                          ),
                                          tooltip: 'Remove',
                                          onPressed: () =>
                                              _deleteCategory(entry),
                                        ),
                                        const Icon(
                                          Icons.drag_handle,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Company shop,
    List<HomeExploreCategory> entries,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 48,
                color: Color(0xFFFF5247),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Explore Categories for ${shop.name}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2229),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure the category order shown on the customer home screen. If none are configured, the home screen displays the shop\'s default categories.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5247),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Category to Explore'),
              onPressed: () => _showAddCategorySheet(context, shop, entries),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/models/company.dart';
import '../../../../core/services/auth_session.dart';
import '../../../../core/services/service_locator.dart';

/// Reusable bar displaying the currently active shop for admin home-screen
/// configuration, allowing admins with appropriate permissions to switch shops.
class ShopSelectorBar extends StatelessWidget {
  final Company? selectedShop;
  final ValueChanged<Company> onShopChanged;

  const ShopSelectorBar({
    super.key,
    required this.selectedShop,
    required this.onShopChanged,
  });

  bool get _canSwitchShop {
    final user = AuthSession.currentUser;
    // Platform / Super Admins (empty companyId) can switch to any shop.
    // Shop admins are restricted to their assigned shop unless none is set.
    return user == null || user.companyId.isEmpty;
  }

  void _showShopPicker(BuildContext context) {
    showModalBottomSheet<Company>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: StreamBuilder<List<Company>>(
            stream: repo.companies(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final shops = snap.data ?? const <Company>[];
              if (shops.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: Text('No shops found.')),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFFFF5247),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Select Shop',
                            style: TextStyle(
                              fontSize: 18,
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
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: shops.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = shops[i];
                          final isSelected = s.id == selectedShop?.id;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  s.name.isNotEmpty
                                      ? s.name.substring(0, 1).toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFFFF5247),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              s.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              s.category.isNotEmpty
                                  ? s.category
                                  : 'Shop ID: ${s.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFFF5247),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(ctx, s);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).then((chosen) {
      if (chosen != null) {
        onShopChanged(chosen);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shop = selectedShop;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFFFF5247),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Managing Shop:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  shop?.name ?? 'Loading Shop...',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2229),
                  ),
                ),
              ],
            ),
          ),
          if (_canSwitchShop) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Color(0xFFFF5247)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(
                Icons.swap_horiz,
                size: 16,
                color: Color(0xFFFF5247),
              ),
              label: const Text(
                'Change',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFFF5247),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _showShopPicker(context),
            ),
          ],
        ],
      ),
    );
  }
}

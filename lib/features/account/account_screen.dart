import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../auth/auth_cubit.dart';
import '../auth/widgets/auth_bottom_sheet.dart';
import '../marketplace/widgets/marketplace_bottom_nav.dart';

/// Full-screen Account/Profile screen with AppBar and MarketplaceBottomNav.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Widget _statCard(String label, String value, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F2F5)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.03),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2229),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext c,
    String title, {
    VoidCallback? onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2229),
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text(
                'View',
                style: TextStyle(color: Color(0xFFFF5247)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final user = authCubit.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F2F5)),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.03),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFFFEBEA),
                  child: Text(
                    user != null && user.name.isNotEmpty
                        ? user.name[0].toUpperCase()
                        : 'G',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5247),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Guest Customer',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2229),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email.isNotEmpty == true
                            ? user!.email
                            : (user?.mobileNumber.isNotEmpty == true
                                  ? user!.mobileNumber
                                  : 'Sign in to sync your cart and orders'),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (user == null)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5247),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => AuthBottomSheet.show(context),
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFFAF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Verified Member',
                            style: TextStyle(
                              color: Color(0xFF1E8F66),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stat cards: Orders / Vouchers / Wishlist
          Row(
            children: [
              _statCard('Orders', '—', () {
                if (user == null) {
                  AuthBottomSheet.show(context);
                } else {
                  context.go(AppRoutes.orders);
                }
              }),
              const SizedBox(width: 10),
              _statCard('Vouchers', '—', () {}),
              const SizedBox(width: 10),
              _statCard('Saved', '—', () {}),
            ],
          ),

          const SizedBox(height: 16),

          _sectionHeader(context, 'My Activity'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFFFF5247),
                  ),
                  title: const Text('My Orders'),
                  subtitle: const Text('Orders, tracking & status'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (user == null) {
                      AuthBottomSheet.show(context);
                      return;
                    }
                    context.go(AppRoutes.orders);
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_none,
                    color: Color(0xFF3D38D9),
                  ),
                  title: const Text('Notifications'),
                  subtitle: const Text('Order updates & promo alerts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.notifications),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _sectionHeader(context, 'Portals & Admin'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Color(0xFFFF5247),
                  ),
                  title: const Text('Admin Dashboard'),
                  subtitle: const Text('Manage products, categories & orders'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.adminLogin),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF3D38D9),
                  ),
                  title: const Text('Employee Portal'),
                  subtitle: const Text('Packing, order queue & fulfillment'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.employeeLogin),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _sectionHeader(context, 'Account Settings'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Saved Addresses'),
                  subtitle: user?.defaultAddress != null
                      ? Text(user!.defaultAddress!.address)
                      : const Text('Add delivery location'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Contact customer helpline'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          if (user != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFEBEA),
                foregroundColor: const Color(0xFFFF5247),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                await authCubit.signOut();
                if (context.mounted) context.go(AppRoutes.home);
              },
              icon: const Icon(Icons.logout),
              label: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: const MarketplaceBottomNav(currentIndex: 3),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/l10n/locale_cubit.dart';

import '../../app/routes/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/responsive_extensions.dart';
import '../../core/widgets/back_to_admin_button.dart';
import '../auth/auth_cubit.dart';
import '../auth/widgets/auth_bottom_sheet.dart';
import '../marketplace/widgets/location_picker_sheet.dart';
import '../marketplace/widgets/marketplace_bottom_nav.dart';
import '../marketplace/widgets/web_header.dart';

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

  /// Display name of a supported language code (shown in its own script).
  static String _languageName(String code) {
    switch (code) {
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'gu':
        return 'ગુજરાતી (Gujarati)';
      default:
        return 'English';
    }
  }

  Widget _sectionHeader(
    BuildContext context,
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
              child: Text(
                AppLocalizations.of(context).view,
                style: const TextStyle(color: Color(0xFFFF5247)),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: context.isDesktop
            ? const PreferredSize(
                preferredSize: Size.fromHeight(64),
                child: WebHeader(currentIndex: 3),
              )
            : AppBar(
                title: Text(
                  AppLocalizations.of(context).account,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                  ),
                ),
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 1,
                actions: const [BackToAdminButton()],
              ),
        body: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.isDesktop ? 24 : 16,
            vertical: 16,
          ),
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
                            label: Text(
                              AppLocalizations.of(context).signIn,
                              style: const TextStyle(
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
                            child: Text(
                              AppLocalizations.of(context).verifiedMember,
                              style: const TextStyle(
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
                  AuthGuard.runWithAuth(
                    context,
                    message: 'Please log in to view your orders.',
                    onAuthenticated: () {
                      context.go(AppRoutes.orders);
                    },
                  );
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
                    title: Text(AppLocalizations.of(context).myOrders),
                    subtitle: Text(
                      AppLocalizations.of(context).ordersTrackingStatus,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AuthGuard.runWithAuth(
                        context,
                        message: 'Please log in to view your orders.',
                        onAuthenticated: () {
                          context.go(AppRoutes.orders);
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_none,
                      color: Color(0xFF3D38D9),
                    ),
                    title: Text(
                      AppLocalizations.of(context).notificationCentre,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context).orderUpdatesPromoAlerts,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.notifications),
                  ),
                ],
              ),
            ),

            if (user != null && (user.isAdmin || user.isEmployee)) ...[
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
                    if (user.isAdmin)
                      ListTile(
                        leading: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Color(0xFFFF5247),
                        ),
                        title: Text(
                          AppLocalizations.of(context).adminDashboard,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(
                            context,
                          ).manageProductsCategoriesOrders,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(AppRoutes.admin),
                      ),
                    if (user.isAdmin && user.isEmployee)
                      const Divider(height: 1, indent: 56),
                    if (user.isEmployee)
                      ListTile(
                        leading: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF3D38D9),
                        ),
                        title: Text(
                          AppLocalizations.of(context).employeePortal,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(
                            context,
                          ).packingOrderQueueFulfillment,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(AppRoutes.employeeLogin),
                      ),
                  ],
                ),
              ),
            ],

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
                  BlocBuilder<LocaleCubit, Locale>(
                    builder: (context, locale) {
                      return ListTile(
                        leading: const Icon(Icons.language_outlined),
                        title: Text(
                          AppLocalizations.of(context).selectLanguage,
                        ),
                        subtitle: Text(_languageName(locale.languageCode)),
                        trailing: DropdownButton<String>(
                          value: locale.languageCode,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                            DropdownMenuItem(
                              value: 'hi',
                              child: Text('हिन्दी (Hindi)'),
                            ),
                            DropdownMenuItem(
                              value: 'gu',
                              child: Text('ગુજરાતી (Gujarati)'),
                            ),
                          ],
                          onChanged: (code) {
                            if (code != null) {
                              context.read<LocaleCubit>().setByCode(code);
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(AppLocalizations.of(context).savedAddresses2),
                    subtitle: user != null && user.addresses.isNotEmpty
                        ? Text(
                            AppLocalizations.of(context).msg3(
                              user.defaultAddress?.label ??
                                  AppLocalizations.of(context).default2,
                              user.defaultAddress?.shortLocation ??
                                  user.defaultAddress?.formattedAddress ??
                                  '',
                              '${user.addresses.length}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            AppLocalizations.of(
                              context,
                            ).manageDeliveryLocations03,
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      AuthGuard.runWithAuth(
                        context,
                        message:
                            'Please log in to manage your saved addresses.',
                        onAuthenticated: () {
                          LocationPickerSheet.show(context);
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(AppLocalizations.of(context).helpSupport),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      ).faqsCustomerHelplineQueryForm,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.helpSupport),
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
                label: Text(
                  AppLocalizations.of(context).logOut,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
        bottomNavigationBar: context.isDesktop
            ? null
            : const MarketplaceBottomNav(currentIndex: 3),
      ),
    );
  }
}

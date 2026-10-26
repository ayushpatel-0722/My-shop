import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:myshop/app/theme/app_theme.dart';
import 'package:myshop/core/models/app_user.dart';

import '../../app/routes/app_router.dart';
import '../../core/services/auth_session.dart';
import '../auth/auth_cubit.dart';

/// Breakpoint at which the admin layout transitions from mobile/tablet drawer to
/// a dedicated desktop sidebar layout (matches AppBreakpoints.tabletMax).
const double kAdminDesktopBreakpoint = 1024.0;

/// Shared scaffold for admin modules with a responsive layout:
/// - On Desktop / Web (width >= 900): Dedicated persistent left sidebar, clean top
///   bar with store/account status, and framed content area with max width constraint.
/// - On Mobile / Tablet portrait (width < 900): Preserves classic mobile AppBar
///   and slide-out navigation drawer with identical behavior.
class AdminShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  /// When true, shows a back arrow in the AppBar (in addition to the drawer/sidebar).
  /// Use this for detail/form screens that are navigated to from a list screen.
  final bool showBack;

  /// Route to navigate to when the back button is tapped.
  /// Defaults to [AppRoutes.admin] (dashboard).
  final String backRoute;
  final Widget? floatingActionButton;

  const AdminShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.showBack = false,
    this.backRoute = AppRoutes.admin,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthSession.instance,
      builder: (context, _) {
        final user = AuthSession.currentUser;
        final companyName = user?.companyName ?? '';

        // Only block while we genuinely have nobody to show. Widget tests and
        // deep links set the session without a restoring phase, and they must
        // not be stuck on a spinner.
        final blocking = AuthSession.isRestoring && user == null;

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
            context.go(backRoute);
          } catch (_) {}
        }

        String currentPath = '';
        try {
          currentPath = GoRouterState.of(context).matchedLocation;
        } catch (_) {}

        final blockingWidget = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).restoringSession,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );

        final scaffold = LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > kAdminDesktopBreakpoint;

            if (!isDesktop) {
              // ---------------------------------------------------------------
              // Mobile / Tablet Portrait Layout (Preserve existing drawer & AppBar)
              // ---------------------------------------------------------------
              return Scaffold(
                appBar: AppBar(
                  title: Text(title),
                  actions: actions,
                  leading: showBack ? BackButton(onPressed: handleBack) : null,
                ),
                drawer: Drawer(
                  child: SafeArea(
                    child: _AdminMobileDrawerContent(
                      companyName: companyName,
                      user: user,
                      currentPath: currentPath,
                    ),
                  ),
                ),
                floatingActionButton: floatingActionButton,
                body: blocking ? blockingWidget : child,
              );
            }

            // -----------------------------------------------------------------
            // Dedicated Desktop / Web Layout (Persistent Sidebar + Framed Content)
            // -----------------------------------------------------------------
            return Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Persistent Navigation Sidebar
                  SizedBox(
                    width: 260,
                    child: _AdminDesktopSidebar(
                      companyName: companyName,
                      user: user,
                      currentPath: currentPath,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppTheme.adminSidebarBorder(context),
                  ),
                  // Main Content Area
                  Expanded(
                    child: Scaffold(
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      appBar: _AdminDesktopAppBar(
                        title: title,
                        actions: actions,
                        showBack: showBack,
                        onBack: handleBack,
                        companyName: companyName,
                        user: user,
                      ),
                      floatingActionButton: floatingActionButton,
                      body: blocking
                          ? blockingWidget
                          : _AdminDesktopContentFrame(child: child),
                    ),
                  ),
                ],
              ),
            );
          },
        );

        if (showBack) {
          return PopScope(
            canPop: canPop(),
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                handleBack();
              }
            },
            child: scaffold,
          );
        }
        return scaffold;
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Navigation Item Data & Structure
// -----------------------------------------------------------------------------
class _AdminNavItemData {
  final IconData icon;
  final String label;
  final String route;
  final String? section;

  const _AdminNavItemData({
    required this.icon,
    required this.label,
    required this.route,
    this.section,
  });
}

List<_AdminNavItemData> _getAdminNavItems(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    // MAIN
    _AdminNavItemData(
      icon: Icons.dashboard,
      label: l10n.dashboard,
      route: AppRoutes.admin,
      section: 'MAIN',
    ),
    _AdminNavItemData(
      icon: Icons.view_kanban,
      label: l10n.ordersPipeline,
      route: AppRoutes.adminOrders,
    ),

    // CATALOG & SALES
    _AdminNavItemData(
      icon: Icons.inventory_2,
      label: l10n.products,
      route: AppRoutes.adminProducts,
      section: 'CATALOG & SALES',
    ),
    _AdminNavItemData(
      icon: Icons.category,
      label: l10n.categories,
      route: AppRoutes.adminCategories,
    ),
    _AdminNavItemData(
      icon: Icons.local_offer,
      label: l10n.vouchers,
      route: AppRoutes.adminVouchers,
    ),
    _AdminNavItemData(
      icon: Icons.local_shipping,
      label: l10n.deliveryCharges,
      route: AppRoutes.adminDelivery,
    ),

    // STOREFRONT
    _AdminNavItemData(
      icon: Icons.image,
      label: l10n.banners,
      route: AppRoutes.adminBanners,
      section: 'STOREFRONT CONFIG',
    ),
    const _AdminNavItemData(
      icon: Icons.grid_view_rounded,
      label: 'Home Explore Categories',
      route: AppRoutes.adminExploreCategories,
    ),
    const _AdminNavItemData(
      icon: Icons.local_fire_department,
      label: 'Home Trending Now',
      route: AppRoutes.adminTrendingNow,
    ),
    _AdminNavItemData(
      icon: Icons.qr_code_2,
      label: l10n.qrCodes,
      route: AppRoutes.adminQr,
    ),

    // OPERATIONS & DATA
    _AdminNavItemData(
      icon: Icons.bar_chart,
      label: l10n.reports,
      route: AppRoutes.adminReports,
      section: 'OPERATIONS & DATA',
    ),
    _AdminNavItemData(
      icon: Icons.star,
      label: l10n.reviews,
      route: AppRoutes.adminReviews,
    ),
    _AdminNavItemData(
      icon: Icons.recommend,
      label: l10n.recommendations,
      route: AppRoutes.adminRecommendations,
    ),
    _AdminNavItemData(
      icon: Icons.badge,
      label: l10n.employees,
      route: AppRoutes.adminEmployees,
    ),
    _AdminNavItemData(
      icon: Icons.admin_panel_settings,
      label: l10n.admins,
      route: AppRoutes.adminAdmins,
    ),
  ];
}

bool _isRouteActive(String currentPath, String itemRoute) {
  if (currentPath.isEmpty) return false;
  if (itemRoute == AppRoutes.admin) {
    return currentPath == AppRoutes.admin ||
        currentPath == '${AppRoutes.admin}/';
  }
  return currentPath == itemRoute || currentPath.startsWith('$itemRoute/');
}

// -----------------------------------------------------------------------------
// Desktop Persistent Sidebar
// -----------------------------------------------------------------------------
class _AdminDesktopSidebar extends StatelessWidget {
  final String companyName;
  final AppUser? user;
  final String currentPath;

  const _AdminDesktopSidebar({
    required this.companyName,
    required this.user,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _getAdminNavItems(context);

    return Container(
      color: AppTheme.adminSidebarBackground(context),
      child: SafeArea(
        child: Column(
          children: [
            // Header / Brand Branding
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.store_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).adminConsole,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (companyName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  companyName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.adminSidebarBorder(context),
            ),

            // Navigation Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = _isRouteActive(currentPath, item.route);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.section != null) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            10,
                            index == 0 ? 4 : 14,
                            10,
                            6,
                          ),
                          child: Text(
                            item.section!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                      _SidebarNavItem(
                        icon: item.icon,
                        label: item.label,
                        route: item.route,
                        isActive: isActive,
                      ),
                    ],
                  );
                },
              ),
            ),

            // Footer / Shopper App & User Account
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.adminSidebarBorder(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                children: [
                  _SidebarNavItem(
                    icon: Icons.storefront_rounded,
                    label: AppLocalizations.of(context).shopperApp,
                    route: AppRoutes.home,
                    isActive: false,
                    isStorefrontLink: true,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : 'A',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name
                                    : 'Administrator',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user?.role.toUpperCase() ?? 'ADMIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          tooltip: AppLocalizations.of(context).logout,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () async {
                            try {
                              await context.read<AuthCubit>().signOut();
                            } catch (_) {
                              AuthSession.currentUser = null;
                            }
                            if (context.mounted) {
                              try {
                                context.go(AppRoutes.role);
                              } catch (_) {}
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final bool isStorefrontLink;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    this.isStorefrontLink = false,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bg;
    Color fg;
    FontWeight weight;

    if (widget.isActive) {
      bg = AppTheme.adminActiveNavBackground(context);
      fg = theme.colorScheme.primary;
      weight = FontWeight.bold;
    } else if (_isHovered) {
      bg = AppTheme.adminHoverNavBackground(context);
      fg = theme.colorScheme.onSurface;
      weight = FontWeight.w600;
    } else {
      bg = Colors.transparent;
      fg = theme.colorScheme.onSurfaceVariant;
      weight = FontWeight.w500;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              try {
                context.go(widget.route);
              } catch (_) {}
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: fg,
                        fontWeight: weight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isActive)
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  if (widget.isStorefrontLink)
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 15,
                      color: fg.withValues(alpha: 0.6),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Desktop AppBar (Right Pane Header)
// -----------------------------------------------------------------------------
class _AdminDesktopAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback onBack;
  final String companyName;
  final AppUser? user;

  const _AdminDesktopAppBar({
    required this.title,
    required this.actions,
    required this.showBack,
    required this.onBack,
    required this.companyName,
    required this.user,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: showBack ? BackButton(onPressed: onBack) : null,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        ...?actions,
        const SizedBox(width: 8),
        // Live Store Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.adminSidebarBorder(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7.5,
                height: 7.5,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                companyName.isNotEmpty ? companyName : 'Masala Mart',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Quick Storefront Button
        IconButton(
          tooltip: AppLocalizations.of(context).shopperApp,
          icon: const Icon(Icons.storefront_outlined, size: 20),
          onPressed: () {
            try {
              context.go(AppRoutes.home);
            } catch (_) {}
          },
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppTheme.adminSidebarBorder(context),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Desktop Content Frame (Constrains Width on Ultra-Wide Displays)
// -----------------------------------------------------------------------------
class _AdminDesktopContentFrame extends StatelessWidget {
  final Widget child;

  const _AdminDesktopContentFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: child,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mobile Drawer Content (Preserved Identical Mobile Architecture)
// -----------------------------------------------------------------------------
class _AdminMobileDrawerContent extends StatelessWidget {
  final String companyName;
  final AppUser? user;
  final String currentPath;

  const _AdminMobileDrawerContent({
    required this.companyName,
    required this.user,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _getAdminNavItems(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).adminConsole,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (companyName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  companyName,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final item in items)
          ListTile(
            leading: Icon(
              item.icon,
              color: _isRouteActive(currentPath, item.route)
                  ? theme.colorScheme.primary
                  : null,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                fontWeight: _isRouteActive(currentPath, item.route)
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _isRouteActive(currentPath, item.route)
                    ? theme.colorScheme.primary
                    : null,
              ),
            ),
            selected: _isRouteActive(currentPath, item.route),
            onTap: () {
              Navigator.of(context).pop(); // Close drawer
              try {
                context.go(item.route);
              } catch (_) {}
            },
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.storefront),
          title: Text(AppLocalizations.of(context).shopperApp),
          onTap: () {
            Navigator.of(context).pop();
            try {
              context.go(AppRoutes.home);
            } catch (_) {}
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(AppLocalizations.of(context).logout),
          onTap: () async {
            try {
              await context.read<AuthCubit>().signOut();
            } catch (_) {
              AuthSession.currentUser = null;
            }
            if (context.mounted) {
              try {
                context.go(AppRoutes.role);
              } catch (_) {}
            }
          },
        ),
      ],
    );
  }
}

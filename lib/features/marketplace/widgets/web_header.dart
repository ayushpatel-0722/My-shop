import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/responsive_extensions.dart';
import '../../../core/widgets/back_to_admin_button.dart';
import '../../checkout/cart/cart_cubit.dart';

/// Sticky desktop web header (≥1024 px).
///
/// Layout: [Logo | Location] ── [Search bar] ── [Nav links | Cart | Account]
///
/// Hidden on mobile/tablet — use [MarketplaceBottomNav] there.
class WebHeader extends StatefulWidget {
  /// 0=Home, 1=Categories, 2=Orders, 3=Account, –1=none
  final int currentIndex;

  const WebHeader({super.key, this.currentIndex = -1});

  @override
  State<WebHeader> createState() => _WebHeaderState();
}

class _WebHeaderState extends State<WebHeader> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final state = GoRouterState.of(context);
      if (state.uri.path == AppRoutes.search) {
        final q =
            state.uri.queryParameters['q'] ??
            state.uri.queryParameters['query'] ??
            '';
        if (q.isNotEmpty && _searchCtrl.text != q && !_searchFocus.hasFocus) {
          _searchCtrl.text = q;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _submitSearch(String query) {
    final q = query.trim();
    String currentPath = '';
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {}
    final isAlreadyOnSearch = currentPath == AppRoutes.search;

    if (q.isEmpty) {
      if (!isAlreadyOnSearch) {
        context.push(AppRoutes.search);
      }
    } else {
      final target = '${AppRoutes.search}?q=${Uri.encodeComponent(q)}';
      if (isAlreadyOnSearch) {
        context.go(target);
      } else {
        context.push(target);
      }
    }
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Only show on desktop
    if (!context.isDesktop) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final user = AuthSession.currentUser;
    final address = AuthSession.activeAddress;
    final locationLabel = address != null
        ? (address.shortLocation.isNotEmpty
              ? address.shortLocation
              : address.label.isNotEmpty
              ? address.label
              : address.name)
        : null;

    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB);
    const accent = Color(0xFFFF5247);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.isDesktop ? 24 : 16,
            ),
            child: Row(
              children: [
                // ── Left: Logo + Location ───────────────────────────────
                _LogoSection(
                  locationLabel: locationLabel,
                  isDark: isDark,
                  onLocationTap: () =>
                      context.push('${AppRoutes.home}?showLocation=1'),
                ),

                const SizedBox(width: 20),

                // ── Center: Search bar (fluid full-width) ─────────────────
                Expanded(
                  child: _SearchBar(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    focused: _searchFocused,
                    isDark: isDark,
                    l10n: l10n,
                    onSubmit: _submitSearch,
                  ),
                ),

                const SizedBox(width: 20),

                // Admins previewing the shopper app get a way back.
                const BackToAdminButton(),

                // ── Right: Nav links + Cart + Account ───────────────────
                _NavActions(
                  currentIndex: widget.currentIndex,
                  user: user,
                  isDark: isDark,
                  accent: accent,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo + Location pill
// ---------------------------------------------------------------------------
class _LogoSection extends StatelessWidget {
  const _LogoSection({
    required this.locationLabel,
    required this.isDark,
    required this.onLocationTap,
  });

  final String? locationLabel;
  final bool isDark;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Branded Logo Image + Text
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go(AppRoutes.home),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5247),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.storefront,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MyShop',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF5247),
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Location pill (only if address exists)
        if (locationLabel != null) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onLocationTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 13,
                    color: Color(0xFFFF5247),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      locationLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.isDark,
    required this.l10n,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final bool isDark;
  final AppLocalizations l10n;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    final borderColor = focused
        ? const Color(0xFFFF5247)
        : isDark
        ? const Color(0xFF334155)
        : const Color(0xFFD1D5DB);

    final fillColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF9FAFB);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: focused ? 1.5 : 1),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: const Color(0xFFFF5247).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, val, _) {
          final hasText = val.text.trim().isNotEmpty;

          return TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmit,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            decoration: InputDecoration(
              hintText: l10n.searchProductsCategoriesOrStores,
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFFFF5247),
                size: 20,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasText)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                      tooltip: 'Clear',
                      onPressed: () => controller.clear(),
                    ),
                  Material(
                    color: const Color(0xFFFF5247),
                    child: InkWell(
                      onTap: () => onSubmit(controller.text),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav actions (Home, Categories, Orders, Notifications, Cart, Account)
// ---------------------------------------------------------------------------
class _NavActions extends StatelessWidget {
  const _NavActions({
    required this.currentIndex,
    required this.user,
    required this.isDark,
    required this.accent,
    required this.l10n,
  });

  final int currentIndex;
  final dynamic user;
  final bool isDark;
  final Color accent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF374151);
    final activeColor = accent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: l10n.home,
          isActive: currentIndex == 0,
          labelColor: labelColor,
          activeColor: activeColor,
          isDark: isDark,
          onTap: () => context.go(AppRoutes.home),
        ),
        _NavItem(
          icon: Icons.grid_view_outlined,
          activeIcon: Icons.grid_view_rounded,
          label: l10n.categories,
          isActive: currentIndex == 1,
          labelColor: labelColor,
          activeColor: activeColor,
          isDark: isDark,
          onTap: () => context.go(AppRoutes.categories),
        ),
        _NavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          label: l10n.orders,
          isActive: currentIndex == 2,
          labelColor: labelColor,
          activeColor: activeColor,
          isDark: isDark,
          onTap: () => AuthGuard.runWithAuth(
            context,
            message: 'Please log in to view your orders.',
            onAuthenticated: () => context.go(AppRoutes.orders),
          ),
        ),
        const SizedBox(width: 4),

        // Notifications icon
        _NotificationButton(isDark: isDark),

        // Cart with badge
        _CartButton(isDark: isDark, accent: accent),

        const SizedBox(width: 4),

        // Account avatar / login
        _AccountButton(user: user, isDark: isDark, accent: accent),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.labelColor,
    required this.activeColor,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color labelColor;
  final Color activeColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? widget.activeColor
        : _hovered
        ? widget.activeColor.withValues(alpha: 0.8)
        : widget.labelColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.activeColor.withValues(alpha: 0.08)
                : _hovered
                ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isActive ? widget.activeIcon : widget.icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatefulWidget {
  const _NotificationButton({required this.isDark});
  final bool isDark;

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.notifications),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Badge(
            smallSize: 7,
            backgroundColor: const Color(0xFFFF5247),
            child: Icon(
              Icons.notifications_outlined,
              size: 22,
              color: widget.isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF374151),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartButton extends StatefulWidget {
  const _CartButton({required this.isDark, required this.accent});
  final bool isDark;
  final Color accent;

  @override
  State<_CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<_CartButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final count = state.totalItems;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (AuthSession.currentUser == null) {
                AuthGuard.runWithAuth(
                  context,
                  message: 'Please log in to view your cart.',
                  onAuthenticated: () => context.push(AppRoutes.cart),
                );
              } else {
                context.push(AppRoutes.cart);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _hovered
                      ? widget.accent.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: count > 0,
                    label: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: widget.accent,
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 22,
                      color: widget.isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF374151),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountButton extends StatefulWidget {
  const _AccountButton({
    required this.user,
    required this.isDark,
    required this.accent,
  });
  final dynamic user;
  final bool isDark;
  final Color accent;

  @override
  State<_AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<_AccountButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final firstName = user != null && (user.name as String).isNotEmpty
        ? (user.name as String).split(' ').first
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.account),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user != null
                      ? widget.accent.withValues(alpha: 0.12)
                      : (widget.isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF3F4F6)),
                  border: Border.all(
                    color: user != null
                        ? widget.accent.withValues(alpha: 0.3)
                        : (widget.isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFD1D5DB)),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: user != null
                    ? Text(
                        (user.name as String).isNotEmpty
                            ? (user.name as String)[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.accent,
                        ),
                      )
                    : Icon(
                        Icons.person_outline,
                        size: 16,
                        color: widget.isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user != null ? 'Hi, ${firstName ?? 'User'}' : 'Sign In',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    user != null ? 'My Account' : 'or Sign Up',
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: widget.isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

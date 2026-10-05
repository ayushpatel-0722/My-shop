import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../utils/responsive_extensions.dart';

/// A modern, silky-smooth animated shimmer effect for loading states, skeletons, and cards.
class ModernShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shapeBorder;

  const ModernShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shapeBorder,
  });

  const ModernShimmer.rectangular({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : shapeBorder = null;

  const ModernShimmer.circular({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = null,
      shapeBorder = const CircleBorder();

  @override
  State<ModernShimmer> createState() => _ModernShimmerState();
}

class _ModernShimmerState extends State<ModernShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE5E7EB);
    final highlightColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF3F4F6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape:
                widget.shapeBorder ??
                RoundedRectangleBorder(
                  borderRadius:
                      widget.borderRadius ??
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// M3 Expressive container-type shadow card loader wrapper
class M3ShadowCardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;

  const M3ShadowCardContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// M3 Product Card Skeleton with container shadow
class M3ProductCardSkeleton extends StatelessWidget {
  const M3ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return M3ShadowCardContainer(
      padding: const EdgeInsets.all(10),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: ModernShimmer(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Category / brand placeholder
          const ModernShimmer.rectangular(
            width: 60,
            height: 10,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          const SizedBox(height: 6),
          // Product name line
          const ModernShimmer.rectangular(
            width: double.infinity,
            height: 14,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          const SizedBox(height: 10),
          // Price and add button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ModernShimmer.rectangular(
                width: 50,
                height: 16,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              ModernShimmer.rectangular(
                width: 32,
                height: 32,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// M3 Product Grid Skeleton (e.g. for Home, Search, Category products)
class M3ProductGridSkeleton extends StatelessWidget {
  final int itemCount;
  const M3ProductGridSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = ResponsiveGrid.calculateCrossAxisCount(
            width,
            maxCardWidth: 250,
          );
          final childAspectRatio = ResponsiveGrid.calculateProductAspectRatio(
            width,
            crossAxisCount,
            showBrand: true,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) => const M3ProductCardSkeleton(),
          );
        },
      ),
    );
  }
}

/// M3 Banner Carousel Skeleton with container shadow
class M3BannerSkeleton extends StatelessWidget {
  const M3BannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          M3ShadowCardContainer(
            padding: EdgeInsets.zero,
            borderRadius: 16,
            height: 155,
            width: double.infinity,
            child: const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              child: ModernShimmer(width: double.infinity, height: 155),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == 0 ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == 0
                      ? const Color(0xFFFF5247).withValues(alpha: 0.3)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// M3 Category Horizontal Rail Skeleton
class M3CategoryRailSkeleton extends StatelessWidget {
  const M3CategoryRailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Column(
          children: const [
            M3ShadowCardContainer(
              padding: EdgeInsets.zero,
              width: 58,
              height: 58,
              borderRadius: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                child: ModernShimmer(width: 58, height: 58),
              ),
            ),
            SizedBox(height: 6),
            ModernShimmer.rectangular(
              width: 48,
              height: 10,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }
}

/// M3 Voucher Rail Skeleton
class M3VoucherRailSkeleton extends StatelessWidget {
  const M3VoucherRailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => M3ShadowCardContainer(
          width: 275,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          borderRadius: 14,
          child: Row(
            children: [
              const ModernShimmer.rectangular(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    ModernShimmer.rectangular(
                      width: 80,
                      height: 12,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    SizedBox(height: 6),
                    ModernShimmer.rectangular(
                      width: 55,
                      height: 14,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ModernShimmer.rectangular(
                width: 48,
                height: 24,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M3 Shop Card Skeleton with container shadow
class M3ShopCardSkeleton extends StatelessWidget {
  const M3ShopCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return M3ShadowCardContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      borderRadius: 16,
      child: Row(
        children: [
          const ModernShimmer.rectangular(
            width: 72,
            height: 72,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ModernShimmer.rectangular(
                  width: 140,
                  height: 15,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 8),
                ModernShimmer.rectangular(
                  width: 100,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 8),
                ModernShimmer.rectangular(
                  width: 60,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// M3 Order Card Skeleton for Orders Screen
class M3OrderCardSkeleton extends StatelessWidget {
  const M3OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return M3ShadowCardContainer(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ModernShimmer.rectangular(
                width: 100,
                height: 14,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              ModernShimmer.rectangular(
                width: 75,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          const SizedBox(height: 12),
          Row(
            children: [
              const ModernShimmer.rectangular(
                width: 50,
                height: 50,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ModernShimmer.rectangular(
                      width: 120,
                      height: 13,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    SizedBox(height: 6),
                    ModernShimmer.rectangular(
                      width: 70,
                      height: 11,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ),
              const ModernShimmer.rectangular(
                width: 60,
                height: 15,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// M3 List Tile / Item Skeleton
class M3ListTileSkeleton extends StatelessWidget {
  const M3ListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return M3ShadowCardContainer(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Row(
        children: [
          const ModernShimmer.circular(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ModernShimmer.rectangular(
                  width: double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 6),
                ModernShimmer.rectangular(
                  width: 120,
                  height: 11,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const ModernShimmer.rectangular(
            width: 20,
            height: 20,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ],
      ),
    );
  }
}

/// M3 Product Detail Screen Skeleton
class M3ProductDetailSkeleton extends StatelessWidget {
  const M3ProductDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image banner skeleton
          Container(
            height: 280,
            width: double.infinity,
            color: const Color(0xFFF9FAFB),
            child: const ModernShimmer(width: double.infinity, height: 280),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category pill
                const ModernShimmer.rectangular(
                  width: 70,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 10),
                // Title
                const ModernShimmer.rectangular(
                  width: double.infinity,
                  height: 22,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                const SizedBox(height: 8),
                const ModernShimmer.rectangular(
                  width: 180,
                  height: 18,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                const SizedBox(height: 16),
                // Price & Badge
                Row(
                  children: const [
                    ModernShimmer.rectangular(
                      width: 90,
                      height: 26,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    SizedBox(width: 12),
                    ModernShimmer.rectangular(
                      width: 60,
                      height: 20,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
                const SizedBox(height: 20),
                // Variants title & chips
                const ModernShimmer.rectangular(
                  width: 110,
                  height: 14,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    ModernShimmer.rectangular(
                      width: 70,
                      height: 34,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(width: 10),
                    ModernShimmer.rectangular(
                      width: 70,
                      height: 34,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    SizedBox(width: 10),
                    ModernShimmer.rectangular(
                      width: 70,
                      height: 34,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Description block
                const ModernShimmer.rectangular(
                  width: 90,
                  height: 14,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 10),
                const ModernShimmer.rectangular(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 6),
                const ModernShimmer.rectangular(
                  width: double.infinity,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 6),
                const ModernShimmer.rectangular(
                  width: 220,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// M3 Expressive Loading Indicator with container shadow
class M3CenterLoader extends StatelessWidget {
  final String? message;
  const M3CenterLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F2F5)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: Color(0xFFFF5247),
                backgroundColor: Color(0xFFFFEBEA),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

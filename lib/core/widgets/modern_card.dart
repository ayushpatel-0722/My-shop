import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// A modern, responsive, interactive card implementing Stripe/Linear depth aesthetics.
///
/// Depth handling:
/// - **Light Mode**: Pure white surface with soft, diffused drop shadows and subtle 1px border.
/// - **Dark Mode**: Elevated surface lightness (#1E293B) with subtle 1px translucent white border (zero muddy shadows).
///
/// Micro-interactions:
/// - Smooth scale-down press feedback ([AnimatedScale]).
/// - Smooth 200ms background and border color transitions ([AnimatedContainer]).
class ModernCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Border? customBorder;
  final bool enableHoverScale;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.customBorder,
    this.enableHoverScale = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusLarge);

    // Dynamic background color
    final defaultBg = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final bg = widget.backgroundColor ?? defaultBg;

    // Dynamic border
    final border =
        widget.customBorder ??
        Border.all(
          color: isDark
              ? (_isHovered
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppTheme.borderDark)
              : (_isHovered
                    ? AppTheme.primaryLight.withValues(alpha: 0.3)
                    : AppTheme.borderLight),
          width: 1,
        );

    // Dynamic shadows (Light mode only; Dark mode uses surface lightness)
    final shadows = isDark
        ? AppTheme.darkCardShadow
        : (_isHovered
              ? AppTheme.lightFloatingShadow
              : AppTheme.lightCardShadow);

    final interactive = widget.onTap != null;
    final scale = (interactive && _isPressed)
        ? 0.98
        : (interactive && widget.enableHoverScale && _isHovered ? 1.01 : 1.0);

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border,
        boxShadow: shadows,
      ),
      child: Material(color: Colors.transparent, child: widget.child),
    );

    if (interactive) {
      cardContent = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: cardContent,
          ),
        ),
      );
    }

    if (widget.margin != null) {
      cardContent = Padding(padding: widget.margin!, child: cardContent);
    }

    return cardContent;
  }
}

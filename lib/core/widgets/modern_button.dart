import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum ModernButtonVariant { primary, secondary, outline, ghost }

/// A modern interactive button with fluid scale-down press animations and hover states.
class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool isLoading;
  final ModernButtonVariant variant;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = ModernButtonVariant.primary,
    this.width,
    this.height = 48,
    this.borderRadius,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.isLoading;
    final radius = widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusMedium);

    Color bg;
    Color fg;
    Border? border;

    switch (widget.variant) {
      case ModernButtonVariant.primary:
        bg = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
        fg = isDark ? const Color(0xFF0B0F19) : Colors.white;
        if (!enabled) bg = bg.withValues(alpha: 0.5);
        break;
      case ModernButtonVariant.secondary:
        bg = isDark ? const Color(0xFF243044) : const Color(0xFFEEF2FF);
        fg = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
        break;
      case ModernButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
        border = Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.2,
        );
        break;
      case ModernButtonVariant.ghost:
        bg = _isHovered
            ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04))
            : Colors.transparent;
        fg = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
        break;
    }

    final scale = enabled && _isPressed ? 0.97 : (enabled && _isHovered ? 1.01 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: border,
              boxShadow: (widget.variant == ModernButtonVariant.primary && !isDark && enabled)
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryLight.withValues(alpha: _isHovered ? 0.35 : 0.2),
                        blurRadius: _isHovered ? 16 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: widget.isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

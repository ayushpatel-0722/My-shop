import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// A modern, silky-smooth animated shimmer effect for loading states, skeletons, and cards.
class ModernShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shapeBorder;

  const ModernShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.shapeBorder,
  });

  const ModernShimmer.rectangular({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : shapeBorder = null;

  const ModernShimmer.circular({
    super.key,
    required double size,
  })  : width = size,
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
        : const Color(0xFFE2E8F0);
    final highlightColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shapeBorder ??
                RoundedRectangleBorder(
                  borderRadius: widget.borderRadius ??
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
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

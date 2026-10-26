import 'package:flutter/material.dart';

import '../../../core/utils/responsive_extensions.dart';

/// A centered, max-width-constrained page container that adapts padding
/// based on screen size. Replaces scattered [ConstrainedBox] + [Center]
/// pairs throughout the shopper app.
///
/// Usage:
/// ```dart
/// ResponsivePageContainer(
///   child: Column(...),
/// )
/// ```
class ResponsivePageContainer extends StatelessWidget {
  const ResponsivePageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1440.0,
    this.horizontalPadding,
    this.verticalPadding,
    this.topPadding,
    this.bottomPadding,
  });

  final Widget child;

  /// Maximum content width. Defaults to 1440.
  final double maxWidth;

  /// Horizontal padding. If null, it is computed from breakpoints.
  final double? horizontalPadding;

  /// Vertical padding applied evenly (top + bottom).
  final double? verticalPadding;

  /// Explicit top padding (overrides [verticalPadding] top).
  final double? topPadding;

  /// Explicit bottom padding (overrides [verticalPadding] bottom).
  final double? bottomPadding;

  /// Responsive horizontal gutter based on screen size.
  static double gutterFor(BuildContext context) {
    final w = context.screenWidth;
    if (w >= 1440) return 48;
    if (w >= 1024) return 32;
    if (w >= 700) return 24;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPadding ?? gutterFor(context);
    final vPadTop = topPadding ?? verticalPadding ?? 0;
    final vPadBottom = bottomPadding ?? verticalPadding ?? 0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, vPadTop, hPad, vPadBottom),
          child: child,
        ),
      ),
    );
  }
}

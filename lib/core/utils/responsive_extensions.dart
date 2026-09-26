import 'package:flutter/widgets.dart';

/// Breakpoint constants used across the application.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Web / desktop / tablet view breakpoint (>= 700 width)
  static const double mobileMax = 700.0;

  /// Desktop view breakpoint (>= 1024 width)
  static const double tabletMax = 1024.0;
}

/// Extension on [BuildContext] providing convenient screen sizing & responsive checks.
extension ResponsiveContext on BuildContext {
  /// Total width of the current screen or viewport.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Total height of the current screen or viewport.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True when the screen width is less than 700.
  bool get isMobile => screenWidth < AppBreakpoints.mobileMax;

  /// True when the screen width is greater than or equal to 700.
  bool get isWeb => screenWidth >= AppBreakpoints.mobileMax;

  /// True when the screen width is between 700 and 1024.
  bool get isTablet =>
      screenWidth >= AppBreakpoints.mobileMax &&
      screenWidth < AppBreakpoints.tabletMax;

  /// True when the screen width is 1024 or wider.
  bool get isDesktop => screenWidth >= AppBreakpoints.tabletMax;
}

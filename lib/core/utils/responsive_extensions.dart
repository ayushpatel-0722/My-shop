import 'package:flutter/material.dart';

/// Breakpoint constants used across the application.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Below 360 px
  static const double compactMobileMax = 360.0;

  /// Mobile view breakpoint (< 600 width for tablet boundary, < 700 for legacy web)
  static const double mobileMax = 700.0;

  /// Tablet view breakpoint (600 - 1023 width)
  static const double tabletMin = 600.0;
  static const double tabletMax = 1024.0;

  /// Large desktop view breakpoint (>= 1440 width)
  static const double desktopMax = 1440.0;
}

/// Responsive layout category based on screen width.
enum ResponsiveLayout { compactMobile, mobile, tablet, desktop, largeDesktop }

/// Extension on [BuildContext] providing convenient screen sizing & responsive checks.
extension ResponsiveContext on BuildContext {
  /// Total width of the current screen or viewport.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Total height of the current screen or viewport.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Layout category for granular responsive styling.
  ResponsiveLayout get responsiveLayout {
    final w = screenWidth;
    if (w < AppBreakpoints.compactMobileMax) {
      return ResponsiveLayout.compactMobile;
    }
    if (w < AppBreakpoints.tabletMin) return ResponsiveLayout.mobile;
    if (w < AppBreakpoints.tabletMax) return ResponsiveLayout.tablet;
    if (w < AppBreakpoints.desktopMax) return ResponsiveLayout.desktop;
    return ResponsiveLayout.largeDesktop;
  }

  /// True when the screen width is less than 360 px.
  bool get isCompactMobile => screenWidth < AppBreakpoints.compactMobileMax;

  /// True when the screen width is less than 700 (preserves legacy compatibility).
  bool get isMobile => screenWidth < AppBreakpoints.mobileMax;

  /// True when the screen width is greater than or equal to 700.
  bool get isWeb => screenWidth >= AppBreakpoints.mobileMax;

  /// True when the screen width is between 600 and 1024.
  bool get isTablet =>
      screenWidth >= AppBreakpoints.tabletMin &&
      screenWidth < AppBreakpoints.tabletMax;

  /// True when the screen width is 1024 or wider.
  bool get isDesktop => screenWidth >= AppBreakpoints.tabletMax;

  /// True when the screen width is 1440 or wider.
  bool get isLargeDesktop => screenWidth >= AppBreakpoints.desktopMax;

  // ---------------------------------------------------------------------------
  // Responsive Typography Tokens (Logical px)
  // ---------------------------------------------------------------------------

  /// Main page title: 22 Mobile | 26 Tablet | 32 Desktop | 36 Large Desktop
  double get titleSize => isLargeDesktop
      ? 36.0
      : isDesktop
      ? 32.0
      : isTablet
      ? 26.0
      : 22.0;

  /// Section heading: 18 Mobile | 21 Tablet | 26 Desktop | 28 Large Desktop
  double get sectionHeadingSize => isLargeDesktop
      ? 28.0
      : isDesktop
      ? 26.0
      : isTablet
      ? 21.0
      : 18.0;

  /// Subsection heading: 16 Mobile | 18 Tablet | 21 Desktop | 24 Large Desktop
  double get subSectionHeadingSize => isLargeDesktop
      ? 24.0
      : isDesktop
      ? 21.0
      : isTablet
      ? 18.0
      : 16.0;

  /// Product name: 14 Mobile | 16 Tablet | 18 Desktop | 20 Large Desktop
  double get productNameSize => isLargeDesktop
      ? 20.0
      : isDesktop
      ? 18.0
      : isTablet
      ? 16.0
      : 14.0;

  /// Product price: 16 Mobile | 18 Tablet | 22 Desktop | 24 Large Desktop
  double get productPriceSize => isLargeDesktop
      ? 24.0
      : isDesktop
      ? 22.0
      : isTablet
      ? 18.0
      : 16.0;

  /// Original price: 12 Mobile | 13 Tablet | 15 Desktop | 16 Large Desktop
  double get originalPriceSize => isLargeDesktop
      ? 16.0
      : isDesktop
      ? 15.0
      : isTablet
      ? 13.0
      : 12.0;

  /// Discount label: 11 Mobile | 12 Tablet | 14 Desktop | 15 Large Desktop
  double get discountLabelSize => isLargeDesktop
      ? 15.0
      : isDesktop
      ? 14.0
      : isTablet
      ? 12.0
      : 11.0;

  /// Body text: 14 Mobile | 15 Tablet | 16 Desktop | 17 Large Desktop
  double get bodyTextSize => isLargeDesktop
      ? 17.0
      : isDesktop
      ? 16.0
      : isTablet
      ? 15.0
      : 14.0;

  /// Form input text: 14 Mobile | 15 Tablet | 16 Desktop | 17 Large Desktop
  double get formInputTextSize => isLargeDesktop
      ? 17.0
      : isDesktop
      ? 16.0
      : isTablet
      ? 15.0
      : 14.0;

  /// Button label: 14 Mobile | 15 Tablet | 16 Desktop | 17 Large Desktop
  double get buttonLabelSize => isLargeDesktop
      ? 17.0
      : isDesktop
      ? 16.0
      : isTablet
      ? 15.0
      : 14.0;

  /// Navigation label: 12 Mobile | 14 Tablet | 15 Desktop | 16 Large Desktop
  double get navigationLabelSize => isLargeDesktop
      ? 16.0
      : isDesktop
      ? 15.0
      : isTablet
      ? 14.0
      : 12.0;

  /// Supporting text: 12 Mobile | 13 Tablet | 14 Desktop | 15 Large Desktop
  double get supportingTextSize => isLargeDesktop
      ? 15.0
      : isDesktop
      ? 14.0
      : isTablet
      ? 13.0
      : 12.0;

  /// Small metadata: 11 Mobile | 12 Tablet | 13 Desktop | 14 Large Desktop
  double get smallMetadataSize => isLargeDesktop
      ? 14.0
      : isDesktop
      ? 13.0
      : isTablet
      ? 12.0
      : 11.0;

  // ---------------------------------------------------------------------------
  // Responsive Component Dimension Tokens (Logical px)
  // ---------------------------------------------------------------------------

  /// Main horizontal page padding: 16 Mobile | 24 Tablet | 32 Desktop | 40 Large Desktop
  double get pagePadding => isLargeDesktop
      ? 40.0
      : isDesktop
      ? 32.0
      : isTablet
      ? 24.0
      : 16.0;

  /// Standard section spacing: 20 Mobile | 24 Tablet | 32 Desktop | 36 Large Desktop
  double get sectionSpacing => isLargeDesktop
      ? 36.0
      : isDesktop
      ? 32.0
      : isTablet
      ? 24.0
      : 20.0;

  /// Card internal padding: 12 Mobile | 14 Tablet | 18 Desktop | 20 Large Desktop
  double get cardInternalPadding => isLargeDesktop
      ? 20.0
      : isDesktop
      ? 18.0
      : isTablet
      ? 14.0
      : 12.0;

  /// Standard card radius: 12 Mobile | 14 Tablet | 16 Desktop | 16 Large Desktop
  double get cardRadius => isDesktop
      ? 16.0
      : isTablet
      ? 14.0
      : 12.0;

  /// Standard button height: 44 Mobile | 46 Tablet | 48 Desktop | 50 Large Desktop
  double get buttonHeight => isLargeDesktop
      ? 50.0
      : isDesktop
      ? 48.0
      : isTablet
      ? 46.0
      : 44.0;

  /// Text input height: 48 Mobile | 48 Tablet | 52 Desktop | 54 Large Desktop
  double get inputHeight => isLargeDesktop
      ? 54.0
      : isDesktop
      ? 52.0
      : 48.0;

  /// Icon-only button target: 44 Mobile | 44 Tablet | 44 Desktop | 48 Large Desktop
  double get iconButtonTarget => isLargeDesktop ? 48.0 : 44.0;

  /// AppBar height: 56 Mobile | 64 Tablet | 72 Desktop | 76 Large Desktop
  double get responsiveAppBarHeight => isLargeDesktop
      ? 76.0
      : isDesktop
      ? 72.0
      : isTablet
      ? 64.0
      : 56.0;

  /// Product grid gap: 12 Mobile | 16 Tablet | 20 Desktop | 24 Large Desktop
  double get productGridGap => isLargeDesktop
      ? 24.0
      : isDesktop
      ? 20.0
      : isTablet
      ? 16.0
      : 12.0;

  /// Reusable page EdgeInsets with responsive horizontal and standard vertical padding.
  EdgeInsets get pageInsets => EdgeInsets.symmetric(
    horizontal: pagePadding,
    vertical: isDesktop ? 24.0 : 16.0,
  );
}

/// Grid sizing utilities ensuring product cards do not exceed max width and
/// adaptively increase column count as screen width grows.
class ResponsiveGrid {
  const ResponsiveGrid._();

  /// Calculates the grid cross-axis count so that cards never exceed [maxCardWidth].
  static int calculateCrossAxisCount(
    double availableWidth, {
    double maxCardWidth = 250.0,
    double spacing = 12.0,
    int minCount = 2,
    int maxCount = 8,
  }) {
    final count = ((availableWidth + spacing) / (maxCardWidth + spacing))
        .ceil();
    return count.clamp(minCount, maxCount);
  }

  /// Calculates dynamic childAspectRatio based on card width to prevent overflow
  /// while keeping cards compact and well-proportioned.
  static double calculateProductAspectRatio(
    double availableWidth,
    int crossAxisCount, {
    double spacing = 12.0,
    bool showBrand = false,
  }) {
    final cardWidth =
        (availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
    final cardHeight = (cardWidth / 1.15) + (showBrand ? 155 : 140);
    return (cardWidth / cardHeight).clamp(0.55, 0.75);
  }
}

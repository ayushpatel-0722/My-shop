import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/responsive_extensions.dart';

/// Comprehensive Modern Design System & Design Tokens (M3 UI).
///
/// Crafted following modern aesthetics seen on Stripe, Linear, and Vercel:
/// - Crisp off-white light background (#F8FAFC) & Pure white surface cards (#FFFFFF).
/// - Midnight blue/charcoal dark background (#0B0F19) & Elevated slate surface cards (#1E293B).
/// - Modern Indigo & Violet primary accents (#4F46E5 & #7C3AED in light, #818CF8 & #A78BFA in dark).
/// - Soft diffused large-spread drop shadows in Light Mode.
/// - Surface lightness depth + subtle 1px translucent borders in Dark Mode (zero muddy shadows).
/// - Modern Inter sans-serif typography with calibrated weights and tracking.
/// - Seamless FadeThrough web & desktop page transitions.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Color Palette Tokens
  // ---------------------------------------------------------------------------

  // Primary brand accents (Vibrant Coral Red & Deep Crimson from design system spec)
  static const Color primaryLight = Color(
    0xFFFF5247,
  ); // Vibrant Coral Red (70%)
  static const Color primaryDeep = Color(
    0xFFC5221F,
  ); // Deep Crimson (Primary solid buttons & badges)
  static const Color primaryDark = Color(0xFFFF6B61); // Accessible Coral
  static const Color primaryViolet = Color(
    0xFF3D38D9,
  ); // Vibrant Royal Blue (Secondary)

  // Secondary brand accents (Royal Blue from spec #3D38D9)
  static const Color secondaryLight = Color(0xFF3D38D9);
  static const Color secondaryDark = Color(0xFF8581F7);

  // Tertiary brand accents (Emerald / Mint Green from spec #0CA678)
  static const Color tertiaryLight = Color(0xFF0CA678);
  static const Color tertiaryDark = Color(0xFF20C997);

  // Light Mode Tokens (Vibrant Marketplace canvas & surfaces)
  static const Color backgroundLight = Color(
    0xFFF4F6F9,
  ); // Clean marketplace soft canvas
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure crisp white
  static const Color surfaceContainerLight = Color(
    0xFFEDEFF4,
  ); // Soft neutral container
  static const Color textPrimaryLight = Color(
    0xFF1E2229,
  ); // Dark Charcoal (#1E2229 from spec)
  static const Color textSecondaryLight = Color(0xFF6C757D); // Muted slate gray
  static const Color borderLight = Color(
    0xFFE2E6EC,
  ); // Clean subtle border (#E2E6EC from spec)

  // Dark Mode Tokens
  static const Color backgroundDark = Color(0xFF0B0F19); // Midnight charcoal
  static const Color surfaceDark = Color(0xFF1E293B); // Elevated slate
  static const Color surfaceContainerDark = Color(
    0xFF243044,
  ); // Container slate
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Crisp off-white
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Muted gray
  static const Color textMutedDark = Color(0xFF94A3B8); // Muted gray alias
  static const Color borderDark = Color(0x1FFFFFFF); // 12% subtle white border

  // Semantic Status Colors
  static const Color success = Color(0xFF0CA678); // Emerald Green
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3D38D9); // Royal Blue

  // ---------------------------------------------------------------------------
  // Centralized Admin Dashboard Design Tokens
  // ---------------------------------------------------------------------------
  static const Color adminBgLight = Color(
    0xFFF8FAFC,
  ); // Clean slate-50 SaaS canvas
  static const Color adminBgDark = Color(
    0xFF0B0F19,
  ); // Midnight charcoal dark canvas

  static const Color adminSidebarBgLight = Color(
    0xFFFFFFFF,
  ); // Pure white sidebar
  static const Color adminSidebarBgDark = Color(
    0xFF0F172A,
  ); // Elevated slate-900 sidebar

  static const Color adminSidebarBorderLight = Color(0xFFE2E8F0);
  static const Color adminSidebarBorderDark = Color(0x1FFFFFFF);

  static const Color adminActiveIndicator = Color(0xFFC5221F);
  static const Color adminActiveNavBgLight = Color(0xFFFFF1F0);
  static const Color adminActiveNavBgDark = Color(0xFF2A1C1D);

  static const Color adminHoverNavBgLight = Color(0xFFF1F5F9);
  static const Color adminHoverNavBgDark = Color(0xFF1E293B);

  static const Color adminCardBorderLight = Color(0xFFE2E8F0);
  static const Color adminCardBorderDark = Color(0x1FFFFFFF);

  static const Color adminCardHoverLight = Color(0xFFF8FAFC);
  static const Color adminCardHoverDark = Color(0xFF1E293B);

  /// Helper to get theme-aware admin sidebar background
  static Color adminSidebarBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? adminSidebarBgDark
        : adminSidebarBgLight;
  }

  /// Helper to get theme-aware admin sidebar border
  static Color adminSidebarBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? adminSidebarBorderDark
        : adminSidebarBorderLight;
  }

  /// Helper to get theme-aware admin card border
  static Color adminCardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? adminCardBorderDark
        : adminCardBorderLight;
  }

  /// Helper to get theme-aware admin active nav background
  static Color adminActiveNavBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? adminActiveNavBgDark
        : adminActiveNavBgLight;
  }

  /// Helper to get theme-aware admin hover nav background
  static Color adminHoverNavBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? adminHoverNavBgDark
        : adminHoverNavBgLight;
  }

  // ---------------------------------------------------------------------------
  // Centralized Admin Responsive Typography & Component Tokens
  // ---------------------------------------------------------------------------

  /// Responsive page title style
  static TextStyle adminPageTitle(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: isDesktop ? 24 : 20,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.3,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Responsive section heading style
  static TextStyle adminSectionTitle(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: isDesktop ? 18 : 16,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Responsive card title style
  static TextStyle adminCardTitle(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: isDesktop ? 15.5 : 14,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Responsive metric KPI value style
  static TextStyle adminMetricValue(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: isDesktop ? 26 : 20,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Responsive metric KPI label style
  static TextStyle adminMetricLabel(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: isDesktop ? 13.5 : 12,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Responsive body text style
  static TextStyle adminBody(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: isDesktop ? 14.5 : 13.5,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Responsive secondary body / subtitle text style
  static TextStyle adminBodySmall(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: isDesktop ? 13 : 11.5,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Responsive badge / tag style
  static TextStyle adminBadgeText(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return TextStyle(
      fontSize: isDesktop ? 11.5 : 10.5,
      fontWeight: FontWeight.bold,
      height: 1.0,
    );
  }

  // ---------------------------------------------------------------------------
  // Centralized Shopper Web & Responsive Design Tokens
  // ---------------------------------------------------------------------------

  /// Recommended max content width for shopper web screens to maintain readable,
  /// centered layouts without stretching across ultrawide monitors.
  static const double shopperMaxContentWidth = 1200.0;
  static const double shopperNarrowMaxContentWidth = 1000.0;

  /// Responsive section heading for shopper screens (18 Mobile | 21 Tablet | 26 Desktop | 28 Large Desktop)
  static TextStyle shopperSectionHeading(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      fontSize: context.sectionHeadingSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: theme.colorScheme.onSurface,
    );
  }

  // ---------------------------------------------------------------------------
  // Shadows, Elevations & Depth ("Sedoe")
  // ---------------------------------------------------------------------------

  /// Soft, diffused, large-spread drop shadow for cards and surfaces in Light Mode.
  static const List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: Color.fromRGBO(30, 34, 41, 0.05),
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color.fromRGBO(30, 34, 41, 0.03),
      blurRadius: 6,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevated shadow for floating elements, dropdowns, and dialogs in Light Mode.
  static const List<BoxShadow> lightFloatingShadow = [
    BoxShadow(
      color: Color.fromRGBO(30, 34, 41, 0.10),
      blurRadius: 28,
      spreadRadius: 0,
      offset: Offset(0, 14),
    ),
    BoxShadow(
      color: Color.fromRGBO(30, 34, 41, 0.04),
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  /// In Dark Mode, depth is communicated through surface lightness and subtle borders.
  static const List<BoxShadow> darkCardShadow = [];

  // Corner Radii Tokens
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // ---------------------------------------------------------------------------
  // Themes
  // ---------------------------------------------------------------------------

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary:
          primaryDeep, // Primary action color #C5221F (deep crimson from spec)
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFEBEA), // Soft coral tint
      onPrimaryContainer: primaryDeep,
      secondary: secondaryLight, // Royal Blue #3D38D9
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEEEDFC),
      onSecondaryContainer: Color(0xFF1B12A8),
      tertiary: tertiaryLight, // Emerald Green #0CA678
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE6F7F2),
      onTertiaryContainer: Color(0xFF087F5B),
      surface: surfaceLight, // Crisp White #FFFFFF
      onSurface: textPrimaryLight, // Dark Charcoal #1E2229
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF8F9FA),
      surfaceContainer: surfaceContainerLight, // Soft neutral #EDEFF4
      surfaceContainerHigh: Color(0xFFE4E7ED),
      surfaceContainerHighest: Color(0xFFD9DFE7),
      error: error,
      onError: Colors.white,
      outline: borderLight, // Subtle border #E2E6EC
      outlineVariant: Color(0xFFEDEFF4),
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBg: backgroundLight, // #F4F6F9 light canvas
      textPrimary: textPrimaryLight, // #1E2229
      textSecondary: textSecondaryLight,
      borderColor: borderLight, // #E2E6EC
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: primaryDark,
      onPrimary: Color(0xFF0B0F19),
      primaryContainer: Color(0xFF801A14),
      onPrimaryContainer: Color(0xFFFFDAD6),
      secondary: secondaryDark,
      onSecondary: Color(0xFF0B0F19),
      secondaryContainer: Color(0xFF1B12A8),
      onSecondaryContainer: Color(0xFFEEEDFC),
      tertiary: tertiaryDark,
      onTertiary: Color(0xFF0B0F19),
      tertiaryContainer: Color(0xFF087F5B),
      onTertiaryContainer: Color(0xFFE6F7F2),
      surface: surfaceDark,
      onSurface: textPrimaryDark,
      surfaceContainerLowest: Color(0xFF0B0F19),
      surfaceContainerLow: Color(0xFF141C2E),
      surfaceContainer: surfaceContainerDark,
      surfaceContainerHigh: Color(0xFF2E3E55),
      surfaceContainerHighest: Color(0xFF3B4F6C),
      error: Color(0xFFF87171),
      onError: Color(0xFF0B0F19),
      outline: borderDark,
      outlineVariant: Color(0x0FFFFFFF),
    );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBg: backgroundDark,
      textPrimary: textPrimaryDark,
      textSecondary: textSecondaryDark,
      borderColor: borderDark,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
  }) {
    final isDark = brightness == Brightness.dark;

    // Typography: Vibrant Marketplace Plus Jakarta Sans
    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTextTheme)
        .copyWith(
          displayLarge: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          displayMedium: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          displaySmall: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
          headlineLarge: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
          ),
          headlineMedium: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
          headlineSmall: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
          titleSmall: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodySmall: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          labelLarge: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,

      // Seamless modern Web & Mobile page transitions (FadeThrough)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
        },
      ),

      // App Bar Theme (Clean crisp white header in Light mode)
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? scaffoldBg : Colors.white,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Card Theme (16px radius, subtle border #E2E6EC, clean white surface)
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // Elevated Button Theme (Primary #C5221F crimson from spec, white text, 12px radius)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Filled Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button Theme (White surface, #D9DFE7 border, #1E2229 text from spec)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? Colors.transparent : Colors.white,
          foregroundColor: textPrimary,
          side: BorderSide(
            color: isDark ? borderColor : const Color(0xFFD9DFE7),
            width: 1.2,
          ),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme (Soft #F4F6F9 container, #E2E6EC border from spec)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceContainerDark : const Color(0xFFF4F6F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryLight, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
      ),

      // Navigation Bar Theme (Clean white bar with soft coral indicator)
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? surfaceDark : Colors.white,
        indicatorColor: const Color(0xFFFFEBEA),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryDeep);
          }
          return IconThemeData(
            color: isDark ? textSecondaryDark : textPrimaryLight,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryDeep,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: isDark ? textSecondaryDark : textSecondaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),

      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: borderColor, width: 1),
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 24,
      ),

      // Dialog & BottomSheet Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: isDark ? 0 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        elevation: isDark ? 0 : 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(radiusLarge),
          ),
        ),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: borderColor.withValues(alpha: 0.2)),
        ),
      ),
    );
  }
}

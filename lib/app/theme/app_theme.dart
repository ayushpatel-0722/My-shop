import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Primary brand accents
  static const Color primaryLight = Color(0xFF4F46E5); // Modern Indigo
  static const Color primaryDark = Color(0xFF818CF8);  // Accessible Lighter Indigo
  static const Color primaryViolet = Color(0xFF7C3AED); // Deep Violet

  // Light Mode Tokens
  static const Color backgroundLight = Color(0xFFF8FAFC); // Crisp off-white
  static const Color surfaceLight = Color(0xFFFFFFFF);    // Pure white
  static const Color surfaceContainerLight = Color(0xFFF1F5F9); // Light slate
  static const Color textPrimaryLight = Color(0xFF0F172A); // Dark slate
  static const Color textSecondaryLight = Color(0xFF64748B); // Medium gray
  static const Color borderLight = Color(0xFFE2E8F0); // Subtle 1px border

  // Dark Mode Tokens
  static const Color backgroundDark = Color(0xFF0B0F19); // Midnight charcoal
  static const Color surfaceDark = Color(0xFF1E293B);    // Elevated slate
  static const Color surfaceContainerDark = Color(0xFF243044); // Container slate
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Crisp off-white
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Muted gray
  static const Color textMutedDark = Color(0xFF94A3B8); // Muted gray alias
  static const Color borderDark = Color(0x1FFFFFFF); // 12% subtle white border

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ---------------------------------------------------------------------------
  // Shadows, Elevations & Depth ("Sedoe")
  // ---------------------------------------------------------------------------

  /// Soft, diffused, large-spread drop shadow for cards and surfaces in Light Mode.
  static const List<BoxShadow> lightCardShadow = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.04),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.02),
      blurRadius: 6,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevated shadow for floating elements, dropdowns, and dialogs in Light Mode.
  static const List<BoxShadow> lightFloatingShadow = [
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.08),
      blurRadius: 32,
      spreadRadius: 0,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color.fromRGBO(15, 23, 42, 0.03),
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
      primary: primaryLight,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEEF2FF),
      onPrimaryContainer: Color(0xFF312E81),
      secondary: primaryViolet,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF3E8FF),
      onSecondaryContainer: Color(0xFF581C87),
      surface: surfaceLight,
      onSurface: textPrimaryLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF8FAFC),
      surfaceContainer: surfaceContainerLight,
      surfaceContainerHigh: Color(0xFFE2E8F0),
      surfaceContainerHighest: Color(0xFFCBD5E1),
      error: error,
      onError: Colors.white,
      outline: borderLight,
      outlineVariant: Color(0xFFF1F5F9),
    );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBg: backgroundLight,
      textPrimary: textPrimaryLight,
      textSecondary: textSecondaryLight,
      borderColor: borderLight,
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: primaryDark,
      onPrimary: Color(0xFF0B0F19),
      primaryContainer: Color(0xFF312E81),
      onPrimaryContainer: Color(0xFFEEF2FF),
      secondary: Color(0xFFA78BFA),
      onSecondary: Color(0xFF0B0F19),
      secondaryContainer: Color(0xFF581C87),
      onSecondaryContainer: Color(0xFFF3E8FF),
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

    // Typography: Modern Inter sans-serif font
    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.25),
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.25),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.25),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w400, height: 1.4),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
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

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Card Theme (16px radius, subtle border)
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

      // Elevated Button Theme (12px rounded, modern height & typography)
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

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: textPrimary,
          side: BorderSide(color: borderColor, width: 1.2),
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

      // Input Decoration Theme (Stripe/Linear style crisp rounded inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
      ),

      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: borderColor, width: 1)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge)),
        ),
      ),

      // Drawer Theme
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(radiusLarge)),
        ),
      ),

      // SnackBar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: borderColor.withValues(alpha: 0.2)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Modern coastal palette inspired by Pondicherry's coastline.
/// Lagoon Teal + Terracotta Coral on a crisp off-white canvas.
abstract final class AppTheme {
  // --- Brand colors ---
  static const lagoon = Color(0xFF0D9488);   // Lagoon Teal — primary
  static const lagoonLight = Color(0xFF14B8A6);
  static const lagoonDark = Color(0xFF0F766E);
  static const coral = Color(0xFFF97316);    // Terracotta Coral — accent
  static const coralLight = Color(0xFFFB923C);
  static const night = Color(0xFF1E293B);    // Deep slate for text
  static const sand = Color(0xFFF8FAFC);     // Crisp off-white background
  static const gold = Color(0xFFE9C46A);
  static const sky = Color(0xFF4895EF);
  static const seed = lagoon;                // Keep seed aliased for compat

  // --- Semantic colors ---
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // --- Surface colors ---
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardShadow = Color(0x0D000000); // black.withOpacity(0.05)

  // --- Dark mode colors ---
  static const darkBackground = Color(0xFF0F172A);   // Slate 900
  static const darkSurface = Color(0xFF1E293B);     // Slate 800
  static const darkCard = Color(0xFF334155);        // Slate 700
  static const darkTextPrimary = Color(0xFFF1F5F9); // Slate 100
  static const darkTextSecondary = Color(0xFF94A3B8); // Slate 400

  // --- Gradient presets for contextual cards ---
  static const sunsetGradient = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const lagoonGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const nightGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF6A11CB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const oceanGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF4895EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: lagoon,
      primary: lagoon,
      secondary: coral,
      surface: cardBackground,
      error: Color(0xFFEF4444),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: sand,
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBackground,
        foregroundColor: night,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: cardBackground,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lagoon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lagoon,
          side: const BorderSide(color: lagoon, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: lagoon, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: lagoon.withValues(alpha: 0.1),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: lagoon.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),
    );
  }
  /// Dark theme — coastal palette on a deep slate canvas.
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: lagoon,
      primary: lagoonLight,
      secondary: coral,
      brightness: Brightness.dark,
      surface: darkSurface,
      error: const Color(0xFFEF4444),
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: darkCard,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lagoon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lagoonLight,
          side: const BorderSide(color: lagoonLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: lagoonLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: lagoon.withValues(alpha: 0.2),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: darkTextPrimary),
        side: BorderSide(color: Colors.grey.shade700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: lagoon.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Driver app theme — darker teal accent for a focused operational UI.
  static ThemeData get driverTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: lagoonDark,
      primary: lagoonDark,
      secondary: coral,
      surface: cardBackground,
      error: Color(0xFFEF4444),
    );
    return light.copyWith(
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: lagoonDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: lagoonDark.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lagoonDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  /// Partner app theme — coral accent for a warm vendor POS interface.
  static ThemeData get partnerTheme {
    const slate900 = Color(0xFF0F172A);
    const slate800 = Color(0xFF1E293B);
    const slate700 = Color(0xFF334155);
    final scheme = ColorScheme.fromSeed(
      seedColor: coral,
      primary: coral,
      secondary: lagoon,
      surface: slate800,
      onSurface: Colors.white,
      error: const Color(0xFFEF4444),
      brightness: Brightness.dark,
    );
    return light.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: slate900,
      appBarTheme: const AppBarTheme(
        backgroundColor: slate800,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: slate800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: slate800,
        indicatorColor: coral.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      textTheme: light.textTheme.copyWith(
        bodyLarge: const TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        bodySmall: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        titleLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleSmall: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        labelLarge: const TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        labelSmall: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  /// Admin web theme — enterprise dark SaaS palette (Stripe/Uber Fleet standard).
  /// Unified across all admin screens: Dashboard, Users, Drivers, Vendors, etc.
  static ThemeData get adminTheme {
    const bg = Color(0xFF0B0F19);           // Deep Charcoal Slate
    const surface = Color(0xFF111827);      // Card surface
    const surfaceHover = Color(0xFF1F2937); // Hover/active surface
    const border = Color(0x14FFFFFF);       // rgba(255,255,255,0.08)
    const textPrimary = Color(0xFFF9FAFB);  // High contrast white
    const textMuted = Color(0xFF9CA3AF);    // Clear readable slate
    const accent = Color(0xFF0D9488);       // Lagoon (brand consistency)
    const accentLight = Color(0xFF14B8A6);
    const danger = Color(0xFFEF4444);

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      secondary: coral,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.15),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: bg,
        selectedIconTheme: const IconThemeData(color: accent),
        unselectedIconTheme: const IconThemeData(color: textMuted),
        selectedLabelTextStyle: const TextStyle(
          color: accent,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textMuted,
          fontSize: 14,
        ),
        indicatorColor: accent.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textMuted),
        bodySmall: TextStyle(color: textMuted, fontSize: 12),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium: TextStyle(color: textMuted, fontSize: 12),
        labelSmall: TextStyle(color: textMuted, fontSize: 11),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
      ),
      iconTheme: const IconThemeData(color: textMuted),
      dataTableTheme: DataTableThemeData(
        dataRowColor: WidgetStateProperty.all(surface),
        headingRowColor: WidgetStateProperty.all(bg),
        dataTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        headingTextStyle: const TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: textMuted, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceHover,
      ),
    );
  }

  /// Admin theme color tokens for use in screen code — see [AdminColors].
}

/// Admin theme color tokens for use in screen code.
/// These match the [AppTheme.adminTheme] palette and should be used
/// consistently across all admin web screens.
abstract final class AdminColors {
  static const bg = Color(0xFF0B0F19);
  static const surface = Color(0xFF111827);
  static const surfaceHover = Color(0xFF1F2937);
  static const border = Color(0x14FFFFFF);
  static const textPrimary = Color(0xFFF9FAFB);
  static const textMuted = Color(0xFF9CA3AF);
  static const accent = Color(0xFF0D9488);
  static const accentLight = Color(0xFF14B8A6);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);
}

/// Consistent spacing tokens used across all screens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Consistent border radius tokens.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

import 'package:flutter/material.dart';

/// Modern coastal palette inspired by Pondicherry's coastline.
/// Lagoon Teal + Terracotta Coral on a crisp off-white canvas.
abstract final class AppTheme {
  // --- Brand colors (Premium Swiggy/Uber Standard) ---
  static const emerald = Color(0xFF00D290);  // Pondy Emerald — primary CTA
  static const emeraldLight = Color(0xFF10E3A0);
  static const emeraldDark = Color(0xFF00B07D);
  // Legacy brand aliases for compatibility during migration
  static const lagoon = Color(0xFF0D9488);
  static const lagoonLight = Color(0xFF14B8A6);
  static const lagoonDark = Color(0xFF0F766E);
  static const coral = Color(0xFFF97316);
  static const coralLight = Color(0xFFFB923C);

  // --- Neutral text & surfaces ---
  static const white = Color(0xFFFFFFFF);
  static const offWhite = Color(0xFFF8F9FA);
  static const pureBlack = Color(0xFF000000);
  static const night = Color(0xFF1E293B);    // Deep slate for text
  static const charcoal = Color(0xFF111827); // Uber/Swiggy primary text
  static const slate = Color(0xFF6B7280);    // Muted secondary text
  static const gold = Color(0xFFE9C46A);
  static const sky = Color(0xFF4895EF);
  static const seed = emerald;
  static const primary = emerald;

  // --- Semantic colors ---
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // --- Surface colors ---
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardShadow = Color(0x0A000000); // black.withOpacity(0.04)
  static const searchFill = Color(0xFFF3F4F6); // soft grey for input fills

  // --- Dark mode colors (OLED Premium) ---
  static const darkBackground = Color(0xFF000000);    // Pure OLED Black
  static const darkSurface = Color(0xFF121212);       // Dark Slate Surface
  static const darkCard = Color(0xFF1E1E1E);          // Elevated card surface
  static const darkBorder = Color(0x14FFFFFF);        // rgba(255,255,255,0.08)
  static const darkTextPrimary = Color(0xFFFFFFFF);   // Pure White
  static const darkTextSecondary = Color(0xFF9CA3AF); // Light Slate

  // --- Gradient presets (subtle, used sparingly) ---
  static const emeraldGradient = LinearGradient(
    colors: [Color(0xFF00D290), Color(0xFF00B07D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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

  /// Bottom image scrim for text legibility without solid-color blocks.
  static const bottomImageScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xCC000000)],
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      primary: emerald,
      secondary: emeraldLight,
      surface: cardBackground,
      surfaceContainerHighest: searchFill,
      onSurface: charcoal,
      onSurfaceVariant: slate,
      error: Color(0xFFEF4444),
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: charcoal,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
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
          foregroundColor: emerald,
          side: const BorderSide(color: emerald, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: searchFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: white,
        selectedColor: emerald.withValues(alpha: 0.1),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: charcoal),
        side: const BorderSide(color: Color(0xFFF3F4F6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: emerald.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF3F4F6),
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: charcoal),
        bodyMedium: TextStyle(color: charcoal),
        bodySmall: TextStyle(color: slate, fontSize: 12),
        titleLarge: TextStyle(color: charcoal, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: charcoal, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: charcoal, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: charcoal),
        labelMedium: TextStyle(color: slate),
      ),
      iconTheme: const IconThemeData(color: slate),
    );
  }
  /// Dark theme — pure OLED black with premium dark slate surfaces.
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      primary: emerald,
      secondary: emeraldLight,
      brightness: Brightness.dark,
      surface: darkSurface,
      surfaceContainerHighest: darkCard,
      onSurface: darkTextPrimary,
      onSurfaceVariant: darkTextSecondary,
      error: const Color(0xFFEF4444),
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
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
          foregroundColor: emerald,
          side: const BorderSide(color: emerald, width: 1.5),
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
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary),
        labelStyle: const TextStyle(color: darkTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: emerald.withValues(alpha: 0.2),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: darkTextPrimary),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: emerald.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextPrimary),
        bodySmall: TextStyle(color: darkTextSecondary, fontSize: 12),
        titleLarge: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: darkTextPrimary, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: darkTextPrimary),
        labelMedium: TextStyle(color: darkTextSecondary),
      ),
      iconTheme: const IconThemeData(color: darkTextSecondary),
    );
  }

  /// Driver app theme — high-contrast operational UI.
  static ThemeData get driverTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      primary: emerald,
      secondary: emeraldLight,
      surface: cardBackground,
      onSurface: charcoal,
      error: const Color(0xFFEF4444),
    );
    return light.copyWith(
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: emerald.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  /// Partner app theme — delegates to the global dark theme.
  static ThemeData get partnerTheme => AppTheme.dark;

  /// Admin web theme — enterprise dark SaaS palette (Stripe/Uber Fleet standard).
  /// Unified across all admin screens: Dashboard, Users, Drivers, Vendors, etc.
  static ThemeData get adminTheme {
    const bg = Color(0xFF0B0F19);           // Deep Slate background
    const surface = Color(0xFF111827);      // Card surface
    const surfaceHover = Color(0xFF1F2937); // Hover/active surface + faint border
    const border = Color(0xFF1F2937);       // 1px faint border (#1F2937)
    const textPrimary = Color(0xFFF9FAFB);  // High contrast white
    const textMuted = Color(0xFF9CA3AF);    // Clear readable slate
    const accent = Color(0xFF00D290);       // Pondy Emerald — primary actions
    const accentLight = Color(0xFF10E3A0);
    const danger = Color(0xFFEF4444);       // Destructive actions

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
          borderSide: const BorderSide(color: accent, width: 1.5),
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
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
  static const border = Color(0xFF1F2937);
  static const textPrimary = Color(0xFFF9FAFB);
  static const textMuted = Color(0xFF9CA3AF);
  static const accent = Color(0xFF00D290);
  static const accentLight = Color(0xFF10E3A0);
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
  static const double xxl = 24;
  static const double pill = 999;
}

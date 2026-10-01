import 'package:flutter/material.dart';

class AppColors {
  // ATHLETE OS Locked Brand Colors
  static const obsidian = Color(0xFF07090D); // Main background #07090D
  static const carbon = Color(0xFF0D1117); // Secondary surface #0D1117
  static const graphite = Color(0xFF151A21); // Cards & panels #151A21
  static const titanium = Color(0xFF202730); // Elevated cards & modals #202730

  // Brand Accents
  static const electricCyan = Color(0xFF00F0FF); // Primary CTA, Skeleton, Active #00F0FF
  static const voltLime = Color(0xFFB6FF00); // Performance achieved, High quality #B6FF00
  static const energyOrange = Color(0xFFFF7A00); // Focus areas, Attention, Setup #FF7A00

  // Status Indicators
  static const statusExcellent = Color(0xFFB6FF00); // #B6FF00
  static const statusActive = Color(0xFF00F0FF); // #00F0FF
  static const statusAttention = Color(0xFFFFB000); // #FFB000
  static const statusCritical = Color(0xFFFF3B4D); // #FF3B4D
  static const statusInsufficient = Color(0xFF6F7B87); // #6F7B87

  // Text Hierarchy
  static const textPrimary = Color(0xFFF5F7FA); // Primary text #F5F7FA
  static const textSecondary = Color(0xFF8B96A3); // Secondary text #8B96A3
  static const textDisabled = Color(0xFF56616D); // Disabled text #56616D
  static const borderDivider = Color(0xFF29313A); // Divider & subtle borders #29313A

  // Backward Compatibility Aliases
  static const ink = obsidian;
  static const panel = carbon;
  static const panelLight = graphite;
  static const cyan = electricCyan;
  static const cyanBright = electricCyan;
  static const green = voltLime;
  static const orange = energyOrange;
  static const coral = statusCritical;
  static const criticalRed = statusCritical;
  static const text = textPrimary;
  static const muted = textSecondary;
  static const line = borderDivider;
  static const borderLight = titanium;

  // Gradients
  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00F0FF), Color(0xFF00A3AD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient voltLimeGradient = LinearGradient(
    colors: [Color(0xFFB6FF00), Color(0xFF82B800)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient graphiteCardGradient = LinearGradient(
    colors: [Color(0xFF151A21), Color(0xFF0D1117)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = graphiteCardGradient;
  static const LinearGradient greenGradient = voltLimeGradient;
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.obsidian,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.carbon,
      primary: AppColors.electricCyan,
      secondary: AppColors.voltLime,
      error: AppColors.statusCritical,
      onSurface: AppColors.textPrimary,
      onPrimary: AppColors.obsidian,
    ),
    fontFamily: 'Arial',
    useMaterial3: true,
    cardTheme: CardThemeData(
      color: AppColors.graphite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDivider, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.obsidian,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
      labelLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.carbon,
      indicatorColor: AppColors.electricCyan.withAlpha(35),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.electricCyan, size: 24);
        }
        return const IconThemeData(color: AppColors.textSecondary, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.electricCyan);
        }
        return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.graphite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDivider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDivider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.electricCyan, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textDisabled),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDivider,
      thickness: 1,
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF4F6F9),
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      primary: Color(0xFF009AA6),
      secondary: Color(0xFF70A800),
      error: AppColors.statusCritical,
      onSurface: Color(0xFF0D1117),
      onPrimary: Colors.white,
    ),
    fontFamily: 'Arial',
    useMaterial3: true,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E4E8), width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0D1117),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0D1117),
        letterSpacing: 0.5,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w900, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: Color(0xFF56616D), fontWeight: FontWeight.w600, letterSpacing: 0.5),
      bodyLarge: TextStyle(color: Color(0xFF0D1117), fontSize: 15),
      bodyMedium: TextStyle(color: Color(0xFF56616D), fontSize: 13, height: 1.45),
      labelLarge: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w800, letterSpacing: 0.5),
      labelSmall: TextStyle(color: Color(0xFF56616D), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF009AA6).withAlpha(35),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF009AA6), size: 24);
        }
        return const IconThemeData(color: Color(0xFF8B96A3), size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF009AA6));
        }
        return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8B96A3));
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF009AA6), width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF56616D)),
      hintStyle: const TextStyle(color: Color(0xFF8B96A3)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE1E4E8),
      thickness: 1,
    ),
  );
}

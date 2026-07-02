import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DataOff — Sistema de Diseño (Dark Mode Profesional)
/// Espejo del CSS design system del frontend web
class AppTheme {
  AppTheme._();

  // ── Paleta de colores ──────────────────────────────────────
  static const Color bgBase      = Color(0xFF0A0B0F);
  static const Color bgSurface   = Color(0xFF111318);
  static const Color bgElevated  = Color(0xFF1A1D26);
  static const Color bgCard      = Color(0xFF1E2130);
  static const Color bgHover     = Color(0xFF252840);

  static const Color border      = Color(0xFF2A2D3E);
  static const Color borderLight = Color(0xFF353850);

  static const Color textPrimary   = Color(0xFFE8EAF0);
  static const Color textSecondary = Color(0xFF8B92A5);
  static const Color textMuted     = Color(0xFF4F556A);

  static const Color accent      = Color(0xFF6366F1);
  static const Color accentLight = Color(0xFF818CF8);
  static const Color accentDim   = Color(0xFF312E81);

  static const Color violet      = Color(0xFF8B5CF6);
  static const Color violetLight = Color(0xFFA78BFA);

  static const Color success     = Color(0xFF10B981);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color danger      = Color(0xFFEF4444);
  static const Color info        = Color(0xFF3B82F6);

  // ── Gradientes ─────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, violet],
  );

  // ── Tipografía ─────────────────────────────────────────────
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall: TextStyle(color: textMuted, fontSize: 12),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: textMuted, fontSize: 11),
    ),
  );

  // ── Tema principal ─────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: violet,
      surface: bgSurface,
      error: danger,
      onPrimary: Colors.white,
      onSurface: textPrimary,
    ),
    scaffoldBackgroundColor: bgBase,
    textTheme: textTheme,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: bgSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: textSecondary),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
      margin: EdgeInsets.zero,
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: danger),
      ),
      hintStyle: const TextStyle(color: textMuted),
      labelStyle: const TextStyle(color: textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(color: border, space: 1),

    // BottomNavigationBar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bgSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: accentDim,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgCard,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: border),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

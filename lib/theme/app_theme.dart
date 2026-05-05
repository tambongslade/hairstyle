import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ═══════════════════════════════════════════
  //  BRAND COLORS (from LIS Beauty logo)
  // ═══════════════════════════════════════════
  static const Color navy = Color(0xFF142838);       // Deep navy — text, nav active
  static const Color navyLight = Color(0xFF1E3A50);  // Slightly lighter navy
  static const Color teal = Color(0xFF5AADA6);       // Primary teal accent
  static const Color tealLight = Color(0xFF7EC8C1);  // Lighter teal
  static const Color tealMint = Color(0xFFA8DDD7);   // Mint — card backgrounds
  static const Color tealPale = Color(0xFFD4F0EC);   // Very pale mint

  // ═══════════════════════════════════════════
  //  DARK MODE
  // ═══════════════════════════════════════════
  static const Color bgPrimary = Color(0xFF0B1722);
  static const Color bgSecondary = Color(0xFF12202E);
  static const Color bgCard = Color(0x0AFFFFFF);
  static const Color bgGlass = Color(0x0FFFFFFF);
  static const Color bgGlassStrong = Color(0x1AFFFFFF);
  static const Color gold = Color(0xFF6BBFB8);       // teal on dark
  static const Color goldLight = Color(0xFF8AD4CC);   // light teal on dark
  static const Color goldDim = Color(0x266BBFB8);     // teal dim
  static const Color goldGlow = Color(0x4D6BBFB8);    // teal glow
  static const Color textPrimary = Color(0xFFE4EAF0);
  static const Color textSecondary = Color(0x99E4EAF0);
  static const Color textTertiary = Color(0x4DE4EAF0);
  static const Color accentGreen = Color(0xFF4ECB8D);
  static const Color accentRed = Color(0xFFE05555);
  static const Color accentBlue = Color(0xFF5B8CF0);
  static const Color border = Color(0x14FFFFFF);

  // ═══════════════════════════════════════════
  //  LIGHT MODE
  // ═══════════════════════════════════════════
  static const Color lightBgPrimary = Color(0xFFF0F3F5);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightBgCard = Color(0x08000000);
  static const Color lightBgGlass = Color(0x0C000000);
  static const Color lightBgGlassStrong = Color(0x1A000000);
  static const Color lightGold = Color(0xFF3D8F88);      // darker teal for readability
  static const Color lightGoldLight = Color(0xFF5AADA6);  // teal accent
  static const Color lightGoldDim = Color(0x1A3D8F88);    // teal dim
  static const Color lightGoldGlow = Color(0x333D8F88);   // teal glow
  static const Color lightTextPrimary = Color(0xFF142838); // navy
  static const Color lightTextSecondary = Color(0xB3142838);
  static const Color lightTextTertiary = Color(0x66142838);
  static const Color lightBorder = Color(0x1E000000);

  // ═══════════════════════════════════════════
  //  THEMES
  // ═══════════════════════════════════════════

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: goldLight,
        surface: bgSecondary,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBgPrimary,
      colorScheme: const ColorScheme.light(
        primary: lightGold,
        secondary: lightGoldLight,
        surface: lightBgSecondary,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  static TextStyle get displayFont => GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.w600,
      );

  static TextStyle get monoFont => GoogleFonts.jetBrainsMono(
        color: gold,
      );

  static BoxDecoration get glassDecoration => BoxDecoration(
        color: bgGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      );

  static BoxDecoration get goldGlassDecoration => BoxDecoration(
        color: goldDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldGlow),
      );

  static List<BoxShadow> get goldShadow => [
        BoxShadow(
          color: teal.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  // ═══════════════════════════════════════════
  //  DYNAMIC COLOR GETTERS
  // ═══════════════════════════════════════════

  static Color getBgPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgPrimary
        : lightBgPrimary;
  }

  static Color getBgSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgSecondary
        : lightBgSecondary;
  }

  static Color getBgGlass(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgGlass
        : lightBgGlass;
  }

  static Color getBgGlassStrong(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? bgGlassStrong
        : lightBgGlassStrong;
  }

  static Color getGold(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? gold
        : lightGold;
  }

  static Color getGoldLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? goldLight
        : lightGoldLight;
  }

  static Color getGoldDim(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? goldDim
        : lightGoldDim;
  }

  static Color getGoldGlow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? goldGlow
        : lightGoldGlow;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : lightTextPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondary
        : lightTextSecondary;
  }

  static Color getTextTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textTertiary
        : lightTextTertiary;
  }

  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? border
        : lightBorder;
  }

  /// Navy color — for nav bar active states, headings, badges
  static Color getNavy(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE4EAF0) // In dark mode, "navy" role → light text
        : navy;
  }
}

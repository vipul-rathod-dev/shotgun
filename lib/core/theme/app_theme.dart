import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,

    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,

      // 🎨 Background (NOT white)
      backgroundColor: AppColors.primary.withOpacity(0.08),
      surfaceTintColor: AppColors.primary.withOpacity(0.08),

      // 🎯 Icons
      iconTheme: IconThemeData(
        color: AppColors.textPrimary,
      ),
      actionsIconTheme: IconThemeData(
        color: AppColors.textPrimary,
      ),

      // 🖋 Title text (Poppins)
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
      ),
    ),

    // 🌈 COLOR SCHEME
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      background: AppColors.background,
      brightness: Brightness.light,
    ),

    // ✅ GLOBAL FONT
    fontFamily: GoogleFonts.poppins().fontFamily,

    // 🖋 TYPOGRAPHY
    textTheme: GoogleFonts.poppinsTextTheme(),
    primaryTextTheme: GoogleFonts.poppinsTextTheme(),

    scaffoldBackgroundColor: AppColors.background,

    // 🧾 INPUT DECORATION THEME (IMPORTANT PART)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,

      // Label & hint
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
      ),

      floatingLabelBehavior: FloatingLabelBehavior.auto,

      // Padding
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),

      // Default border
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.textSecondary,
        ),
      ),

      // Enabled border
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.textSecondary,
        ),
      ),

      // Focused border
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),

      // Error border
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),

      // Focused error border
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.error,
          width: 2,
        ),
      ),

      // Icons
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,

      // Error text
      errorStyle: const TextStyle(
        fontSize: 12,
        height: 1.2,
      ),
    ),

    // 🔘 BUTTON THEME (BONUS)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        // ✅ background color
        backgroundColor: MaterialStateProperty.all(
          AppColors.primary, // same as seedColor
        ),

        // ✅ TEXT + ICON COLOR (THIS FIXES YOUR ISSUE)
        foregroundColor: MaterialStateProperty.all(
          Colors.white,
        ),

        textStyle: MaterialStateProperty.all(
          GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),

        padding: MaterialStateProperty.all(
          const EdgeInsets.symmetric(vertical: 14),
        ),

        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.all(
          AppColors.primary,
        ),
        iconColor: MaterialStateProperty.all(
          AppColors.textSecondary,
        ),
        textStyle: MaterialStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),

      // ✅ BORDER COLOR (unchecked)
      side: BorderSide(
        color: AppColors.textSecondary, // same as TextField border
        width: 1.4,
      ),

      // ✅ FILL COLOR (checked)
      fillColor: MaterialStateProperty.resolveWith(
        (states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        },
      ),

      // ✅ CHECK ICON COLOR
      checkColor: MaterialStateProperty.all(Colors.white),
    ),
  );
}

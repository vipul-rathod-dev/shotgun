import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,

    // 🌈 COLOR SCHEME
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      background: AppColors.background,
      brightness: Brightness.light,
    ),

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
          const TextStyle(
            fontWeight: FontWeight.w600,
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
          AppColors.textSecondary,
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
      fillColor: MaterialStateProperty.resolveWith(
        (states) => states.contains(MaterialState.selected)
            ? AppColors.primary
            : AppColors.background,
      ),
    ),
  );
}

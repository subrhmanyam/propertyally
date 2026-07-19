import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Bogineni Group dark theme — boginenigroup.com
/// Black backgrounds · silver text · gold accents · sharp corners · DTLNobel font
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        // DTLNobel is the brand font from boginenigroup.com.
        // Add assets/fonts/DTLNobel-Light.ttf + DTLNobel-Bold.ttf and register
        // them in pubspec.yaml to activate. Falls back to Inter in the meantime.
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.bgOuter,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentSilver,
          secondary: AppColors.accentGold,
          surface: AppColors.cardBg,
          error: AppColors.error,
          onPrimary: AppColors.bgOuter,
          onSecondary: AppColors.bgOuter,
          onSurface: AppColors.textPrimary,
          onError: Colors.white,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: AppDimensions.fontH1,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
            letterSpacing: 1.5,
          ),
          headlineMedium: TextStyle(
            fontSize: AppDimensions.fontH3,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
          titleMedium: TextStyle(
            fontSize: AppDimensions.fontMD,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: AppDimensions.fontBase,
            fontWeight: FontWeight.w300,
            color: AppColors.textPrimary,
          ),
          bodySmall: TextStyle(
            fontSize: AppDimensions.fontSM,
            fontWeight: FontWeight.w300,
            color: AppColors.textMuted,
          ),
          labelSmall: TextStyle(
            fontSize: AppDimensions.fontXS,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Sharp corners — brand rule
            side: BorderSide(color: AppColors.border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.searchBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
            borderSide: const BorderSide(color: AppColors.searchBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
            borderSide: const BorderSide(color: AppColors.searchBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
            borderSide:
                const BorderSide(color: AppColors.accentSilver, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD,
            vertical: AppDimensions.spaceSM,
          ),
          hintStyle: const TextStyle(
            color: AppColors.searchPlaceholder,
            fontSize: AppDimensions.fontBase,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentSilver,
            foregroundColor: AppColors.bgOuter,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero, // Sharp corners
            ),
            textStyle: const TextStyle(
              fontSize: AppDimensions.fontBase,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentSilver,
            side: const BorderSide(color: AppColors.border),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.accentSilver,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accentSilver,
          dividerColor: AppColors.border,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.sidebarBg,
          indicatorColor: AppColors.sidebarItemActive,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: AppDimensions.fontXS,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
}

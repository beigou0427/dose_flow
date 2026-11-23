import 'package:flutter/material.dart';

/// DoseFlow 1.1「Deep Medical Sci-Fi」核心色彩系統
class DoseFlowColors {
  const DoseFlowColors._();

  static const Color bgDeep = Color(0xFF060B12);
  static const Color bgNavy = Color(0xFF0D1929);
  static const Color cardSurface = Color(0xFF101F33);
  static const Color cardElevated = Color(0xFF152840);
  static const Color cardBorder = Color(0xFF213A57);
  static const Color mint = Color(0xFF2EE59D);
  static const Color teal = Color(0xFF00C9B8);
  static const Color cyan = Color(0xFF00B4D8);
  static const Color amber = Color(0xFFFFB84D);
  static const Color purple = Color(0xFF9B87F5);
  static const Color danger = Color(0xFFEF4444);

  static const Color textPrimary = Color(0xFFF4F9FF);
  static const Color textSecondary = Color(0xFFA0B2C6);
  static const Color textMuted = Color(0xFF6F86A0);
}

/// DoseFlow 1.1 深色醫療科技主題定義
class DoseFlowTheme {
  const DoseFlowTheme._();

  static ThemeData get darkTheme {
    const ColorScheme scheme = ColorScheme.dark(
      primary: DoseFlowColors.mint,
      onPrimary: Color(0xFF041A18),
      secondary: DoseFlowColors.cyan,
      onSecondary: Color(0xFF041620),
      tertiary: DoseFlowColors.purple,
      surface: DoseFlowColors.cardSurface,
      onSurface: DoseFlowColors.textPrimary,
      onSurfaceVariant: DoseFlowColors.textSecondary,
      outline: DoseFlowColors.cardBorder,
      error: DoseFlowColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: DoseFlowColors.bgDeep,
      appBarTheme: const AppBarTheme(
        backgroundColor: DoseFlowColors.bgNavy,
        foregroundColor: DoseFlowColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1.0,
      ),
      cardTheme: const CardThemeData(
        color: DoseFlowColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: DoseFlowColors.cardBorder, width: 1.0),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DoseFlowColors.bgNavy,
        indicatorColor: DoseFlowColors.mint.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: DoseFlowColors.mint, size: 24);
          }
          return const IconThemeData(color: DoseFlowColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: DoseFlowColors.mint,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            );
          }
          return const TextStyle(
            color: DoseFlowColors.textMuted,
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: DoseFlowColors.cardBorder,
        thickness: 1.0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : DoseFlowColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? DoseFlowColors.mint
              : const Color(0xFF1D3148);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: DoseFlowColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
          side: BorderSide(color: DoseFlowColors.cardBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: DoseFlowColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: DoseFlowColors.cardElevated,
        contentTextStyle: TextStyle(
          color: DoseFlowColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DoseFlowColors.textPrimary,
          side: const BorderSide(color: DoseFlowColors.cardBorder),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DoseFlowColors.mint,
          foregroundColor: const Color(0xFF041A18),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
    );
  }
}

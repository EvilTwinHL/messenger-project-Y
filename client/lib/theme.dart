import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 Основна палітра (Signal Blue)
  static const Color primaryColor = Color(0xFF3A76F0);

  // Кольори для повідомлень
  static const Color bubbleSelf = primaryColor;
  static const Color bubbleOtherDark = Color(
    0xFF262626,
  ); // Темний сірий для інших
  static const Color bubbleOtherLight = Color(0xFFF0F0F0); // Світлий сірий

  // Фонові кольори
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundLight = Colors.white;

  // Тексти
  static const Color textDark = Colors.white;
  static const Color textLight = Colors.black;

  // Отримання теми (Світла / Темна)
  static ThemeData getTheme(bool isDark) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: isDark ? backgroundDark : backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? backgroundDark : backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Стиль Drawer
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
    );
  }
}

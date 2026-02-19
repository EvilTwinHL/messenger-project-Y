import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
//  🎨  SignalColors  —  ВСІ КОЛЬОРИ В ОДНОМУ МІСЦІ
//  Змінюй тут — зміниться скрізь у додатку
// ═══════════════════════════════════════════════════════════════════
abstract class SignalColors {
  // ── Фони ──────────────────────────────────────────────────────────
  static const appBackground = Color(0xFF111113); // scaffold
  static const surface = Color(0xFF1A1B1D); // AppBar, картки
  static const elevated = Color(0xFF252528); // модали, контекст-меню
  static const inputField = Color(0xFF2E2E36); // поле вводу

  // ── Нижня навігація ───────────────────────────────────────────────
  static const navBarBg = Color(0xFF1C1C22); // фон "таблетки"
  static const navBarShadow = Color(0xFF000000); // тінь під таблеткою
  static const activeNavPill = Color(0xFF2B5CE6); // активна іконка
  static const inactiveNav = Color(0xFF8E8E9A); // неактивна іконка/лейбл

  // ── Бульбашки ──────────────────────────────────────────────────────
  static const outgoing = Color(0xFF2B5CE6); // мої повідомлення
  static const incoming = Color(0xFF2C2C2E); // чужі повідомлення

  // ── Акцент ────────────────────────────────────────────────────────
  static const primary = Color(0xFF2B5CE6);

  // ── Текст ─────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8E8E9A);
  static const textDisabled = Color(0xFF5A5A6A);

  // ── Системні ──────────────────────────────────────────────────────
  static const divider = Color(0xFF2A2A2E);
  static const online = Color(0xFF4CAF78);
  static const danger = Color(0xFFFF4B4B);

  // ── Аватар-пари (фон / колір літери) ─────────────────────────────
  static const List<List<Color>> avatarPairs = [
    [Color(0xFF1E3A1E), Color(0xFF6BCB6B)], // green
    [Color(0xFF1E2A3A), Color(0xFF6B9BFF)], // blue
    [Color(0xFF3A1E2A), Color(0xFFFF6BAA)], // pink
    [Color(0xFF2A1E3A), Color(0xFFB06BFF)], // purple
    [Color(0xFF3A2A1E), Color(0xFFFF9B6B)], // orange
    [Color(0xFF1E3A3A), Color(0xFF6BDDDD)], // teal
  ];

  static List<Color> avatarColorsFor(String name) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % avatarPairs.length;
    return avatarPairs[idx];
  }
}

// ═══════════════════════════════════════════════════════════════════
//  📐  AppSizes  —  ВСІ РОЗМІРИ В ОДНОМУ МІСЦІ
//  Змінюй тут — зміниться скрізь у додатку
// ═══════════════════════════════════════════════════════════════════
abstract class AppSizes {
  // ── Нижня навігація ───────────────────────────────────────────────
  static const double navBarHeight = 72; // висота "таблетки"
  static const double navBarPaddingH = 20; // горизонтальний відступ від країв
  static const double navBarPaddingBottom = 14; // відступ від низу екрану
  static const double navBarBorderRadius = 36; // заокруглення таблетки
  static const double navIconSize = 24; // розмір іконки
  static const double navLabelSize = 11; // розмір підпису

  // ── Поле вводу чату ───────────────────────────────────────────────
  static const double inputHeight = 52; // мінімальна висота поля
  static const double inputBorderRadius = 26; // заокруглення поля
  static const double inputFontSize = 16; // розмір тексту у полі
  static const double inputHintFontSize = 16; // розмір placeholder

  // ── Кнопки дій чату (мікрофон / відео / прикріпити / надіслати) ──
  static const double actionButtonSize = 44; // розмір круглої кнопки
  static const double actionIconSize = 22; // розмір іконки всередині
  static const double inlineIconSize = 24; // іконки мікрофон/відео в полі

  // ── Бульбашки ──────────────────────────────────────────────────────
  static const double bubblePadding = 14; // внутрішній відступ
  static const double bubbleRadius = 18; // заокруглення
  static const double bubbleMaxWidthRatio = 0.76; // макс. ширина від екрана
  static const double bubbleFontSize = 16; // розмір тексту
  static const double bubbleTimeFontSize = 11; // розмір часу

  // ── AppBar ────────────────────────────────────────────────────────
  static const double appBarHeight = 58; // висота AppBar
  static const double appBarTitleSize = 20; // розмір заголовку

  // ── Аватари ───────────────────────────────────────────────────────
  static const double avatarRadiusSmall = 20; // у списку чатів
  static const double avatarRadiusMedium = 27; // у тайлах
  static const double avatarRadiusLarge = 48; // на екрані профілю
}

// ═══════════════════════════════════════════════════════════════════
//  AppTheme  —  збірка ThemeData
// ═══════════════════════════════════════════════════════════════════
class AppTheme {
  static const Color primaryColor = SignalColors.primary;
  static const Color bubbleSelf = SignalColors.outgoing;
  static const Color bubbleOtherDark = SignalColors.incoming;
  static const Color backgroundDark = SignalColors.appBackground;

  static ThemeData getTheme([bool isDark = true]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SignalColors.appBackground,
      primaryColor: SignalColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SignalColors.primary,
        brightness: Brightness.dark,
        surface: SignalColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SignalColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(color: SignalColors.textPrimary),
        titleTextStyle: TextStyle(
          color: SignalColors.textPrimary,
          fontSize: AppSizes.appBarTitleSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: SignalColors.surface),
      dividerColor: SignalColors.divider,
      dividerTheme: const DividerThemeData(
        color: SignalColors.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: SignalColors.textPrimary,
        iconColor: SignalColors.textSecondary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? SignalColors.primary
              : SignalColors.textDisabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? SignalColors.primary.withOpacity(0.4)
              : SignalColors.inputField,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SignalColors.elevated,
        contentTextStyle: TextStyle(color: SignalColors.textPrimary),
      ),
    );
  }
}

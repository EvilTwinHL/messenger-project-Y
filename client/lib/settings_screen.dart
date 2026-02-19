import 'package:flutter/material.dart';
import 'theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignalColors.appBackground,
      // AppBar вбудований у HomeScreen через IndexedStack,
      // але якщо відкривається окремо — покажемо свій
      appBar: ModalRoute.of(context)?.settings.name != null
          ? AppBar(
              backgroundColor: SignalColors.surface,
              elevation: 0,
              title: const Text(
                'Налаштування',
                style: TextStyle(color: SignalColors.textPrimary),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader('Зовнішній вигляд'),
          _tile(
            icon: Icons.dark_mode_outlined,
            title: 'Темна тема',
            subtitle: 'Завжди увімкнена (Signal Dark)',
            trailing: Container(
              width: 42,
              height: 24,
              decoration: BoxDecoration(
                color: SignalColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: CircleAvatar(radius: 9, backgroundColor: Colors.white),
                ),
              ),
            ),
          ),
          _divider(),
          _sectionHeader('Загальне'),
          _tile(
            icon: Icons.language_outlined,
            title: 'Мова',
            subtitle: 'Українська',
          ),
          _tile(
            icon: Icons.notifications_outlined,
            title: 'Сповіщення',
            subtitle: 'Увімкнено',
          ),
          _tile(icon: Icons.data_saver_off_outlined, title: 'Збереження даних'),
          _divider(),
          _sectionHeader('Конфіденційність'),
          _tile(icon: Icons.lock_outline, title: 'Блокування екрану'),
          _tile(
            icon: Icons.visibility_outlined,
            title: 'Підтвердження прочитання',
          ),
          _divider(),
          _sectionHeader('Про додаток'),
          _tile(
            icon: Icons.info_outline,
            title: 'Messenger Y',
            subtitle: 'Версія 2.2.1',
          ),
          _tile(icon: Icons.code_outlined, title: 'Ліцензії'),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: SignalColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: SignalColors.surface,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: SignalColors.textSecondary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: SignalColors.textPrimary, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: SignalColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing:
          trailing ??
          const Icon(Icons.chevron_right, color: SignalColors.textDisabled),
      onTap: onTap ?? () {},
    );
  }

  Widget _divider() =>
      const Divider(color: SignalColors.divider, height: 1, indent: 68);
}

// lib/screens/settings_screen.dart
//
// Екран Налаштувань:
// - OTA-оновлення перенесено сюди (з AppBar чату)
// - Іконка: Icons.system_update_alt
// - Секція "Про додаток" з версією

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class SettingsScreen extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final String? email;
  final String? phoneNumber;

  const SettingsScreen({
    super.key,
    required this.username,
    this.avatarUrl,
    this.email,
    this.phoneNumber,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _updater = ShorebirdUpdater();
  bool _checkingUpdate = false;
  String _updateStatus = '';
  String _appVersion = '2.4.3+4';
  int? _patchNumber;

  @override
  void initState() {
    super.initState();
    _loadPatchNumber();
  }

  Future<void> _loadPatchNumber() async {
    // readCurrentPatch() повертає об'єкт Patch або null, якщо патчів немає
    final patch = await _updater.readCurrentPatch();

    if (mounted) {
      setState(() {
        // Отримуємо саме номер патча з об'єкта
        _patchNumber = patch?.number;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;

    setState(() {
      _checkingUpdate = true;
      _updateStatus = 'Перевіряємо оновлення...';
    });

    try {
      // 1. Отримуємо поточний статус оновлення
      final status = await _updater.checkForUpdate();

      if (status == UpdateStatus.upToDate) {
        if (mounted)
          setState(() => _updateStatus = '✅ Ви вже маєте найновішу версію');
        return;
      }

      if (status == UpdateStatus.restartRequired) {
        if (mounted)
          setState(
            () => _updateStatus =
                '🎉 Оновлення вже завантажено! Перезапустіть додаток',
          );
        _showRestartDialog();
        return;
      }

      if (status == UpdateStatus.outdated) {
        setState(() => _updateStatus = 'Завантажуємо оновлення...');

        // 2. Запускаємо оновлення
        await _updater.update();

        if (mounted) {
          setState(
            () => _updateStatus =
                '🎉 Оновлення встановлено! Перезапустіть додаток',
          );
          _showRestartDialog();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _updateStatus = '❌ Помилка: $e');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2128),
        title: const Text(
          'Оновлення встановлено',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Щоб застосувати оновлення, перезапустіть додаток.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Пізніше',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // ShorebirdCodePush.restart() — якщо потрібно
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5CE6),
            ),
            child: const Text('Перезапустити'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111113),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17191C),
        elevation: 0,
        title: const Text(
          'Налаштування',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        //leading: IconButton(
        // icon: const Icon(Icons.arrow_back, color: Colors.white),
        // onPressed: () => Navigator.pop(context),
        //),
      ),
      body: ListView(
        children: [
          // ── Профіль ────────────────────────────────────────
          _SectionHeader('Профіль'),
          ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF2B5CE6),
              backgroundImage: widget.avatarUrl != null
                  ? NetworkImage(widget.avatarUrl!)
                  : null,
              child: widget.avatarUrl == null
                  ? Text(
                      widget.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            title: Text(
              widget.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              widget.email ?? widget.phoneNumber ?? 'Без пошти',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            trailing: const Icon(
              Icons.edit_outlined,
              color: Colors.white54,
              size: 20,
            ),
            onTap: () {
              // TODO: відкрити екран редагування профілю
            },
          ),

          const _Divider(),

          // ── Сповіщення ─────────────────────────────────────
          _SectionHeader('Сповіщення'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push-сповіщення',
            subtitle: 'Увімкнено',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.vibration,
            title: 'Вібрація',
            onTap: () {},
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeColor: const Color(0xFF2B5CE6),
            ),
          ),

          const _Divider(),

          // ── Зовнішній вигляд ───────────────────────────────
          _SectionHeader('Зовнішній вигляд'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Тема',
            subtitle: 'Signal Dark',
            onTap: () {},
          ),
          _SettingsTile(icon: Icons.wallpaper, title: 'Фон чату', onTap: () {}),

          const _Divider(),

          // ── Конфіденційність ───────────────────────────────
          _SectionHeader('Конфіденційність'),
          _SettingsTile(
            icon: Icons.lock_outlined,
            title: 'Блокування екрану',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.block,
            title: 'Заблоковані контакти',
            onTap: () {},
          ),

          const _Divider(),

          // ── Про додаток ────────────────────────────────────
          _SectionHeader('Про додаток'),

          // ── OTA ОНОВЛЕННЯ (перенесено сюди з AppBar!) ──────
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2B5CE6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.system_update_alt,
                color: Color(0xFF2B5CE6),
                size: 22,
              ),
            ),
            title: const Text(
              'Перевірити оновлення',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _updateStatus.isNotEmpty
                  ? _updateStatus
                  : 'Версія $_appVersion${_patchNumber != null ? " (patch $_patchNumber)" : ""}',
              style: TextStyle(
                color: _updateStatus.startsWith('✅')
                    ? const Color(0xFF27AE60)
                    : _updateStatus.startsWith('❌')
                    ? Colors.red[300]
                    : Colors.white54,
                fontSize: 13,
              ),
            ),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2B5CE6),
                    ),
                  )
                : const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: _checkingUpdate ? null : _checkForUpdate,
          ),

          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Про Messenger Y',
            subtitle: 'v$_appVersion · Open source',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Messenger Y',
              applicationVersion: 'v$_appVersion',
              applicationLegalese: '© 2026 Messenger Y',
            ),
          ),

          const _Divider(),

          // ── Вихід ──────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Вийти',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E2128),
                  title: const Text(
                    'Вийти?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Ви впевнені що хочете вийти?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Скасувати'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Вийти',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) _logout();
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2B5CE6),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            )
          : null,
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: Color(0xFF2A2A30),
      height: 1,
      indent: 16,
      endIndent: 0,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  final String username;
  final String? avatarUrl;

  const SettingsScreen({super.key, required this.username, this.avatarUrl});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _updater = ShorebirdUpdater();
  bool _checkingUpdate = false;
  String _updateStatus = '';
  final String _appVersion = '2.6.3';
  int? _patchNumber;

  // Налаштування
  bool _vibration = true;
  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPatchNumber();
  }

  Future<void> _loadPatchNumber() async {
    final patch = await _updater.readCurrentPatch();
    if (mounted) setState(() => _patchNumber = patch?.number);
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    setState(() {
      _checkingUpdate = true;
      _updateStatus = 'Перевіряємо оновлення...';
    });
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.upToDate) {
        if (mounted) setState(() => _updateStatus = '✅ Вже найновіша версія');
        return;
      }
      if (status == UpdateStatus.restartRequired) {
        if (mounted)
          setState(() => _updateStatus = '🎉 Оновлено! Перезапустіть додаток');
        _showRestartDialog();
        return;
      }
      if (status == UpdateStatus.outdated) {
        setState(() => _updateStatus = 'Завантажуємо оновлення...');
        await _updater.update();
        if (mounted) {
          setState(
            () => _updateStatus = '🎉 Встановлено! Перезапустіть додаток',
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
        backgroundColor: SignalColors.elevated,
        title: const Text(
          'Оновлення встановлено',
          style: TextStyle(color: SignalColors.textPrimary),
        ),
        content: const Text(
          'Щоб застосувати оновлення, перезапустіть додаток.',
          style: TextStyle(color: SignalColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Пізніше',
              style: TextStyle(color: SignalColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: SignalColors.primary,
            ),
            child: const Text(
              'Перезапустити',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Сповіщення ─────────────────────────────────────
        _SectionHeader('Сповіщення'),
        _ToggleTile(
          icon: Icons.notifications_outlined,
          title: 'Push-сповіщення',
          subtitle: _pushEnabled ? 'Увімкнено' : 'Вимкнено',
          value: _pushEnabled,
          onChanged: (v) => setState(() => _pushEnabled = v),
        ),
        _ToggleTile(
          icon: Icons.vibration,
          title: 'Вібрація',
          value: _vibration,
          onChanged: (v) => setState(() => _vibration = v),
        ),

        const _Divider(),

        // ── Зовнішній вигляд ───────────────────────────────
        _SectionHeader('Зовнішній вигляд'),
        _Tile(
          icon: Icons.palette_outlined,
          title: 'Тема',
          subtitle: 'Signal Dark',
          onTap: () {},
        ),
        _Tile(icon: Icons.wallpaper, title: 'Фон чату', onTap: () {}),

        const _Divider(),

        // ── Конфіденційність ───────────────────────────────
        _SectionHeader('Конфіденційність'),
        _Tile(
          icon: Icons.lock_outlined,
          title: 'Блокування екрану',
          onTap: () {},
        ),
        _Tile(icon: Icons.block, title: 'Заблоковані контакти', onTap: () {}),

        const _Divider(),

        // ── Про додаток + OTA ──────────────────────────────
        _SectionHeader('Про додаток'),
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SignalColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update_alt,
              color: SignalColors.primary,
              size: 22,
            ),
          ),
          title: const Text(
            'Перевірити оновлення',
            style: TextStyle(color: SignalColors.textPrimary),
          ),
          subtitle: Text(
            _updateStatus.isNotEmpty
                ? _updateStatus
                : 'Версія $_appVersion${_patchNumber != null ? " (patch $_patchNumber)" : ""}',
            style: TextStyle(
              color: _updateStatus.startsWith('✅')
                  ? SignalColors.online
                  : _updateStatus.startsWith('❌')
                  ? SignalColors.danger
                  : SignalColors.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: _checkingUpdate
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SignalColors.primary,
                  ),
                )
              : const Icon(
                  Icons.chevron_right,
                  color: SignalColors.textSecondary,
                ),
          onTap: _checkingUpdate ? null : _checkForUpdate,
        ),
        _Tile(
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

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Допоміжні компоненти ─────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: SignalColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: SignalColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: SignalColors.textSecondary, size: 20),
    ),
    title: Text(title, style: const TextStyle(color: SignalColors.textPrimary)),
    subtitle: subtitle != null
        ? Text(
            subtitle!,
            style: const TextStyle(
              color: SignalColors.textSecondary,
              fontSize: 13,
            ),
          )
        : null,
    trailing: const Icon(
      Icons.chevron_right,
      color: SignalColors.textSecondary,
    ),
    onTap: onTap,
  );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: SignalColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: SignalColors.textSecondary, size: 20),
    ),
    title: Text(title, style: const TextStyle(color: SignalColors.textPrimary)),
    subtitle: subtitle != null
        ? Text(
            subtitle!,
            style: const TextStyle(
              color: SignalColors.textSecondary,
              fontSize: 13,
            ),
          )
        : null,
    trailing: Switch(
      value: value,
      onChanged: onChanged,
      activeColor: SignalColors.primary,
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
    color: SignalColors.divider,
    height: 1,
    indent: 16,
    endIndent: 0,
  );
}

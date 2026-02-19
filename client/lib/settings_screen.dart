import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() => _isDarkMode = value);
    // Тут в реальному додатку треба сповістити main.dart про зміну теми (через Provider або ValueNotifier)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Перезапустіть додаток для зміни теми (або використайте Provider)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Налаштування")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Темна тема"),
            secondary: const Icon(Icons.dark_mode),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            activeColor: AppTheme.primaryColor,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Мова"),
            subtitle: const Text("Українська"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("Messenger Y"),
            subtitle: const Text("Версія 2.1.11"),
          ),
        ],
      ),
    );
  }
}

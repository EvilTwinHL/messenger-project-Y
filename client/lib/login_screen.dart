import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'services/auth_service.dart';

// ══════════════════════════════════════════════════════════
// 🚪 LoginScreen — обгортка з двома вкладками
// ══════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignalColors.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Logo
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: SignalColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Messenger Y',
              style: TextStyle(
                color: SignalColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Приватні повідомлення',
              style: TextStyle(color: SignalColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              height: 44,
              decoration: BoxDecoration(
                color: SignalColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: SignalColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: SignalColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Увійти'),
                  Tab(text: 'Зареєструватись'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _LoginTab(
                    onSwitchToRegister: () => _tabController.animateTo(1),
                  ),
                  _RegisterTab(
                    onSwitchToLogin: () => _tabController.animateTo(0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 🔑 Вкладка ВХІД
// ══════════════════════════════════════════════════════════
class _LoginTab extends StatefulWidget {
  final VoidCallback onSwitchToRegister;
  const _LoginTab({required this.onSwitchToRegister});

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _snack('Введіть логін та пароль');
      return;
    }

    final loginRegex = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!loginRegex.hasMatch(username)) {
      _snack(
        'Логін може містити лише латинські літери, цифри та . _ -',
        error: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await AuthService.login(
        username: username,
        password: password,
      );
      final user = data['user'] as Map<String, dynamic>;
      if (!mounted) return;
      _navigateHome(
        username: username,
        displayName: user['displayName'] as String? ?? username,
        avatarUrl: user['avatarUrl'] as String?,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateHome({
    required String username,
    required String displayName,
    String? avatarUrl,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          myUsername: username,
          myDisplayName: displayName,
          myAvatarUrl: avatarUrl,
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? SignalColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            controller: _usernameCtrl,
            label: 'Логін',
            hint: 'john_doe або ivan123',
            icon: Icons.alternate_email,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _passwordCtrl,
            label: 'Пароль',
            icon: Icons.lock_outline,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: SignalColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: SignalColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: SignalColors.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'УВІЙТИ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: widget.onSwitchToRegister,
              child: const Text(
                'Немає акаунту? Зареєструватись',
                style: TextStyle(color: SignalColors.primary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: SignalColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: SignalColors.textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: SignalColors.textDisabled,
          fontSize: 13,
        ),
        filled: true,
        fillColor: SignalColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignalColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignalColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignalColors.primary, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: SignalColors.textSecondary, size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

// ══════════════════════════════════════════════════════════
// 📝 Вкладка РЕЄСТРАЦІЯ
// ══════════════════════════════════════════════════════════
class _RegisterTab extends StatefulWidget {
  final VoidCallback onSwitchToLogin;
  const _RegisterTab({required this.onSwitchToLogin});

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameCtrl.text.trim();
    final displayName = _displayNameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _snack('Заповніть обов\'язкові поля');
      return;
    }

    final loginRegex = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!loginRegex.hasMatch(username)) {
      _snack('Логін: тільки латиниця, цифри та . _ -', error: true);
      return;
    }
    if (username.length < 3) {
      _snack('Логін мінімум 3 символи', error: true);
      return;
    }
    if (password.length < 8) {
      _snack('Пароль мінімум 8 символів', error: true);
      return;
    }
    if (password != confirm) {
      _snack('Паролі не збігаються', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = await AuthService.login(
        username: username,
        password: password,
        displayName: displayName.isNotEmpty ? displayName : null,
      );
      final user = data['user'] as Map<String, dynamic>;
      if (data['status'] == 'found') {
        _snack('Цей логін вже зайнятий', error: true);
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            myUsername: username,
            myDisplayName: user['displayName'] as String? ?? username,
            myAvatarUrl: user['avatarUrl'] as String?,
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? SignalColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Логін
          _field(
            controller: _usernameCtrl,
            label: 'Логін *',
            hint: 'ivan123',
            icon: Icons.alternate_email,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 4, bottom: 8),
            child: Text(
              'Тільки a-z, 0-9, . _ -  •  Для входу та пошуку',
              style: TextStyle(color: SignalColors.textSecondary, fontSize: 11),
            ),
          ),

          // Псевдонім
          _field(
            controller: _displayNameCtrl,
            label: 'Псевдонім (необов\'язково)',
            hint: 'Іван або Михайло 😊',
            icon: Icons.badge_outlined,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 4, bottom: 8),
            child: Text(
              'Будь-яка мова, кирилиця  •  Відображається як ім\'я',
              style: TextStyle(color: SignalColors.textSecondary, fontSize: 11),
            ),
          ),

          // Пароль
          _field(
            controller: _passwordCtrl,
            label: 'Пароль * (мін. 8 символів)',
            icon: Icons.lock_outline,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: SignalColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),

          // Підтвердження пароля
          _field(
            controller: _confirmCtrl,
            label: 'Підтвердіть пароль *',
            icon: Icons.lock_outline,
            obscure: _obscureConfirm,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: SignalColors.textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            onSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: SignalColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: SignalColors.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'ЗАРЕЄСТРУВАТИСЬ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: widget.onSwitchToLogin,
              child: const Text(
                'Вже є акаунт? Увійти',
                style: TextStyle(color: SignalColors.primary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: SignalColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: SignalColors.textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: SignalColors.textDisabled,
          fontSize: 13,
        ),
        filled: true,
        fillColor: SignalColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignalColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignalColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SignalColors.primary, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: SignalColors.textSecondary, size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

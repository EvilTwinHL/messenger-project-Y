import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'services/auth_service.dart';

// ══════════════════════════════════════════════════════════
// 🚪 LoginScreen — обгортка з двома вкладками
// ══════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  /// Акаунти знайдені по телефону на попередньому запуску.
  /// Якщо список не порожній — при відкритті показуємо вибір.
  final List<Map<String, dynamic>> suggestedAccounts;

  const LoginScreen({super.key, this.suggestedAccounts = const []});

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
    // Якщо є акаунти по телефону — показуємо вибір після build
    if (widget.suggestedAccounts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAccountPicker();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Вибір акаунту по телефону ─────────────────────────
  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SignalColors.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AccountPickerSheet(
        accounts: widget.suggestedAccounts,
        onSelect: (username, displayName) {
          Navigator.pop(ctx);
          // Переключаємось на вкладку "Увійти" і заповнюємо логін
          _tabController.animateTo(0);
          // Передаємо вибраний username в _LoginTab через навігацію
          // (найпростіше — показати діалог ще раз через GlobalKey або setState)
          // Використовуємо PreFilledLoginData щоб передати в дочірній віджет
          setState(() => _preFilledUsername = username);
        },
      ),
    );
  }

  String? _preFilledUsername;

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
                    preFilledUsername: _preFilledUsername,
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
  final String? preFilledUsername;
  const _LoginTab({required this.onSwitchToRegister, this.preFilledUsername});

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.preFilledUsername != null) {
      _usernameCtrl.text = widget.preFilledUsername!;
    }
  }

  @override
  void didUpdateWidget(covariant _LoginTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preFilledUsername != null &&
        widget.preFilledUsername != oldWidget.preFilledUsername) {
      _usernameCtrl.text = widget.preFilledUsername!;
    }
  }

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

// ══════════════════════════════════════════════════════════
// 📱 AccountPickerSheet — вибір акаунту по телефону
// ══════════════════════════════════════════════════════════
class _AccountPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final void Function(String username, String displayName) onSelect;

  const _AccountPickerSheet({required this.accounts, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SignalColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  color: SignalColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Знайдено акаунти',
                      style: TextStyle(
                        color: SignalColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Оберіть акаунт для входу',
                      style: TextStyle(
                        color: SignalColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Список акаунтів
          ...accounts.map((acc) {
            final username = acc['username'] as String? ?? '';
            final displayName = acc['displayName'] as String? ?? username;
            final avatarUrl = acc['avatarUrl'] as String?;
            final colors = _avatarColors(username);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onSelect(username, displayName),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: SignalColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors[0],
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: colors[1],
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: SignalColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                color: SignalColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: SignalColors.textSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // Кнопка — увійти з іншим акаунтом
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Увійти з іншим акаунтом',
                style: TextStyle(
                  color: SignalColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Той самий алгоритм кольорів що і в SignalColors.avatarColorsFor
  List<Color> _avatarColors(String username) {
    const palettes = [
      [Color(0xFF1A73E8), Color(0xFFFFFFFF)],
      [Color(0xFF0F9D58), Color(0xFFFFFFFF)],
      [Color(0xFFE53935), Color(0xFFFFFFFF)],
      [Color(0xFF8E24AA), Color(0xFFFFFFFF)],
      [Color(0xFFF57C00), Color(0xFFFFFFFF)],
      [Color(0xFF00838F), Color(0xFFFFFFFF)],
    ];
    final idx = username.isEmpty
        ? 0
        : username.codeUnits.fold(0, (a, b) => a + b) % palettes.length;
    return palettes[idx].cast<Color>();
  }
}

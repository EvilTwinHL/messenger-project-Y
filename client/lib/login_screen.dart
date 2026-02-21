import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http_mp;
import 'package:image_picker/image_picker.dart';
import 'home_screen.dart';
import 'theme.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _avatarFile;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) setState(() => _avatarFile = File(image.path));
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введіть нікнейм та пароль')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Спочатку завантажуємо аватар якщо є
      String? uploadedAvatarUrl;
      if (_avatarFile != null) {
        // Завантаження без JWT (аватар при реєстрації — окремий випадок)
        // Тимчасово використовуємо http напряму для upload під час реєстрації
        final token = await AuthService.getToken();
        if (token != null) {
          // Якщо вже є токен — завантажуємо з ним
          uploadedAvatarUrl = await _uploadAvatar(token);
        }
        // Якщо токена немає (перша реєстрація) — аватар завантажимо після входу
      }

      final data = await AuthService.login(
        username: username,
        password: password,
        avatarUrl: uploadedAvatarUrl,
      );

      // Якщо аватар не завантажено до входу — завантажуємо тепер з токеном
      if (_avatarFile != null && uploadedAvatarUrl == null) {
        final token = await AuthService.getToken();
        if (token != null) {
          uploadedAvatarUrl = await _uploadAvatar(token);
          // Оновлюємо локально
          await AuthService.saveUser(
            username: username,
            avatarUrl: uploadedAvatarUrl,
          );
        }
      }

      final finalAvatarUrl = uploadedAvatarUrl ?? data['user']['avatarUrl'];

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HomeScreen(myUsername: username, myAvatarUrl: finalAvatarUrl),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: SignalColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadAvatar(String token) async {
    try {
      final request = http_mp.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.serverUrl}/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http_mp.MultipartFile.fromPath('image', _avatarFile!.path),
      );
      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body);
        return json['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignalColors.appBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: SignalColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Messenger Y',
                style: TextStyle(
                  color: SignalColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Приватні повідомлення',
                style: TextStyle(
                  color: SignalColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Avatar picker
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: SignalColors.surface,
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : null,
                      child: _avatarFile == null
                          ? const Icon(
                              Icons.person_outline,
                              size: 40,
                              color: SignalColors.textSecondary,
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: SignalColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Додати фото (необов\'язково)',
                style: TextStyle(
                  color: SignalColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 28),

              // Username field
              _buildTextField(
                controller: _usernameController,
                label: 'Нікнейм (3–20 символів, тільки a-z, 0-9)',
                icon: Icons.person_outline,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 16),

              // Password field
              _buildTextField(
                controller: _passwordController,
                label: 'Пароль (мінімум 8 символів)',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: SignalColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 12),

              // Підказка
              const Text(
                'Якщо акаунту немає — він буде створений автоматично',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SignalColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SignalColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: SignalColors.primary.withOpacity(
                      0.5,
                    ),
                    elevation: 0,
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
                          'УВІЙТИ / ЗАРЕЄСТРУВАТИСЬ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: SignalColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: SignalColors.textSecondary,
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
        prefixIcon: Icon(icon, color: SignalColors.textSecondary),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

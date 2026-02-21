import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _refreshTokenKey = 'jwt_refresh_token';
  static const _usernameKey = 'username';
  static const _avatarUrlKey = 'avatarUrl';

  // ─── Збереження ───────────────────────────────────────
  static Future<void> saveTokens({
    required String token,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  static Future<void> saveUser({
    required String username,
    String? avatarUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    if (avatarUrl != null) await prefs.setString(_avatarUrlKey, avatarUrl);
  }

  // ─── Читання ──────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getSavedAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarUrlKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Логін / Реєстрація ───────────────────────────────
  /// Повертає Map з ключами: token, refreshToken, user, status
  /// або кидає Exception з текстом помилки
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String? avatarUrl,
  }) async {
    final url = Uri.parse('${AppConfig.serverUrl}/auth');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Зберігаємо токени та юзера локально
      await saveTokens(
        token: data['token'],
        refreshToken: data['refreshToken'],
      );
      await saveUser(
        username: data['user']['username'],
        avatarUrl: data['user']['avatarUrl'],
      );
      return data;
    } else {
      throw Exception(data['error'] ?? 'Помилка входу');
    }
  }

  // ─── Оновлення токена ─────────────────────────────────
  static Future<String?> refreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final url = Uri.parse('${AppConfig.serverUrl}/refresh');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['token'] as String;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, newToken);

        return newToken;
      }
    } catch (_) {}
    return null;
  }

  // ─── Вихід ────────────────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_avatarUrlKey);
  }
}

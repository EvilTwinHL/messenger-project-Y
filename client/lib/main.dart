import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui'; // 🔥 Потрібно для ефекту скла (ImageFilter)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для налаштування статус бару
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ==========================================
// 🎨 НАЛАШТУВАННЯ КОЛЬОРІВ ТА СЕРВЕРА
// ==========================================
const String serverUrl = 'https://pproject-y.onrender.com';

class AppColors {
  // 🔥 ГОЛОВНИЙ КОЛІР (Змінюйте цей для кнопок та своїх повідомлень)
  static const Color mainColor = Color(0xFF3A76F0); // Signal Blue

  // 🌑 ГРАДІЄНТ ФОНУ (Від верху до низу)
  static const Color bgGradientTop = Color(0xFF1b1e28); // Темний
  static const Color bgGradientMid = Color(0xFF1b1e28); // Середній
  static const Color bgGradientBot = Color(0xFF1b1e28); // Світліший низ

  // 💬 КОЛЬОРИ ПОВІДОМЛЕНЬ
  static const Color bubbleMeStart =
      mainColor; // Градієнт моїх повідомлень (початок)
  static const Color bubbleMeEnd = Color(
    0xCC2C61D6,
  ); // Градієнт моїх повідомлень (кінець)
  static const Color bubbleOther =
      Colors.white; // Колір чужих (основа для скла)

  // ⚪ ІНШЕ
  static const Color white = Colors.white;
  static const Color whiteGlass = Colors.white10; // Прозорість скла
}
// ==========================================

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🌙 Фонове повідомлення: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Робимо статус бар прозорим для ефекту на весь екран
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      print("✅ Firebase Mobile Init OK");
    } catch (e) {
      print("❌ Firebase Init Error: $e");
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final savedUsername = prefs.getString('username');
  final savedAvatar = prefs.getString('avatarUrl');

  runApp(
    MyApp(
      initialScreen: savedUsername != null
          ? ChatScreen(username: savedUsername, avatarUrl: savedAvatar)
          : const LoginScreen(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Glass Messenger',
      // Темна тема за замовчуванням для кращого ефекту скла
      theme: ThemeData.dark().copyWith(
        primaryColor: AppColors.mainColor,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.mainColor,
          secondary: Colors.blueAccent,
        ),
        useMaterial3: true,
      ),
      home: initialScreen,
    );
  }
}

// =======================
// 💎 WIDGET: GLASS CONTAINER (Ефект скла)
// =======================
class GlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Border? border;

  const GlassBox({
    super.key,
    required this.child,
    this.borderRadius = 0,
    this.blur = 10.0,
    this.opacity = 0.1, // Більш прозоре за замовчуванням
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border:
                border ??
                Border.all(color: Colors.white.withOpacity(0.1), width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }
}

// =======================
// 🔐 ЕКРАН ВХОДУ
// =======================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  File? _avatarFile;
  String? _uploadedAvatarUrl;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      if (_avatarFile != null) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$serverUrl/upload'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('image', _avatarFile!.path),
        );
        var response = await request.send();
        if (response.statusCode == 200) {
          var json = jsonDecode(await response.stream.bytesToString());
          _uploadedAvatarUrl = json['url'];
        }
      }

      final response = await http.post(
        Uri.parse('$serverUrl/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'avatarUrl': _uploadedAvatarUrl,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final user = responseData['user'];
        final finalAvatarUrl = user['avatarUrl'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        if (finalAvatarUrl != null) {
          await prefs.setString('avatarUrl', finalAvatarUrl);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatScreen(username: username, avatarUrl: finalAvatarUrl),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Помилка входу')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgGradientTop,
              AppColors.bgGradientMid,
              AppColors.bgGradientBot,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassBox(
              borderRadius: 24,
              opacity: 0.15,
              blur: 15,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.mainColor.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : null,
                          child: _avatarFile == null
                              ? const Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.white70,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Додати фото",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Ваш нікнейм",
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.black12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 10,
                          shadowColor: AppColors.mainColor.withOpacity(0.5),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "УВІЙТИ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================
// 💬 ЕКРАН ЧАТУ (GLASS + SIGNAL STYLE)
// =======================
class ChatScreen extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  const ChatScreen({super.key, required this.username, this.avatarUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> messages = [];
  final TextEditingController textController = TextEditingController();
  late IO.Socket socket;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final _updater = ShorebirdUpdater();
  bool _isUpdateAvailable = false;
  int? _currentPatch;

  late String myName;
  bool _isTyping = false;
  String _typingUser = '';
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    myName = widget.username;
    initSocket();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Future.delayed(const Duration(seconds: 2), setupPushNotifications);
    }
    _checkShorebirdSilent();
  }

  // --- ЛОГІКА (БЕЗ ЗМІН) ---
  Future<void> _checkShorebirdSilent() async {
    try {
      if (!_updater.isAvailable) return;
      final patch = await _updater.readCurrentPatch();
      final status = await _updater.checkForUpdate();
      setState(() {
        _currentPatch = patch?.number;
        _isUpdateAvailable = status == UpdateStatus.outdated;
      });
    } catch (e) {
      _logToServer("Shorebird error: $e");
    }
  }

  Future<void> _manualCheckForUpdate() async {
    if (!Platform.isAndroid) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Перевірка оновлень...")));
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        if (!mounted) return;
        _showUpdateDialog();
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Версія актуальна!")));
      }
    } catch (e) {
      _logToServer("Update error: $e");
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text("Оновлення", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Новий патч доступний. Завантажити?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Ні"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mainColor,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _runUpdateProcess();
            },
            child: const Text("Так", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _runUpdateProcess() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF202020),
        title: Text("Завантаження...", style: TextStyle(color: Colors.white)),
        content: LinearProgressIndicator(color: AppColors.mainColor),
      ),
    );
    try {
      await _updater.update();
      if (mounted) Navigator.pop(context);
      if (mounted) exit(0);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _logToServer("Err update: $e");
    }
  }

  void _logToServer(String msg) {
    print("LOG: $msg");
    if (socket.connected) socket.emit('debug_log', "User $myName: $msg");
  }

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission();
      String? token = await messaging.getToken();
      if (token != null)
        socket.emit('register_token', {
          'token': token,
          'username': widget.username,
        });
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (mounted && message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${message.notification!.title}: ${message.notification!.body}",
              ),
              backgroundColor: AppColors.mainColor,
            ),
          );
        }
      });
    } catch (e) {
      _logToServer("Push Error: $e");
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void initSocket() {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket.connect();

    socket.on('load_history', (data) {
      if (data != null) {
        setState(() {
          messages.clear();
          for (var msg in data) messages.add(msg);
        });
        _scrollToBottom();
        bool hasOtherMessages = messages.any((msg) => msg['sender'] != myName);
        if (hasOtherMessages) socket.emit('mark_read', {'reader': myName});
      }
    });

    socket.on('receive_message', (data) {
      setState(() => messages.add(data));
      _scrollToBottom();
      if (data['sender'] != myName)
        socket.emit('mark_read', {'reader': myName});
    });

    socket.on('message_read_update', (data) {
      if (mounted) {
        setState(() {
          for (var msg in messages) {
            if (msg['sender'] == myName) msg['read'] = true;
          }
        });
      }
    });

    socket.on('display_typing', (data) {
      if (mounted) {
        setState(() {
          _isTyping = true;
          _typingUser = data['username'];
        });
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });

    socket.on('message_deleted', (messageId) {
      if (mounted && messageId != null) {
        setState(() => messages.removeWhere((msg) => msg['id'] == messageId));
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var json = jsonDecode(await response.stream.bytesToString());
        sendMessage(imageUrl: json['url'], type: 'image');
      }
    } catch (e) {
      print(e);
    }
  }

  void sendMessage({String? imageUrl, String type = 'text'}) {
    String text = textController.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    socket.emit('send_message', {
      'text': imageUrl ?? text,
      'sender': myName,
      'senderAvatar': widget.avatarUrl,
      'type': type,
    });
    textController.clear();
  }

  void _showDeleteConfirmDialog(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text("Видалити?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Це незворотно.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Ні"),
          ),
          TextButton(
            onPressed: () {
              socket.emit('delete_message', messageId);
              Navigator.pop(ctx);
            },
            child: const Text(
              "Видалити",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for dates
  DateTime _parseDate(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    try {
      if (timestamp is String) return DateTime.parse(timestamp);
      if (timestamp is Map && timestamp['_seconds'] != null)
        return DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
    } catch (e) {}
    return DateTime.now();
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(date.year, date.month, date.day) == today) return "Сьогодні";
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    socket.dispose();
    textController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: GlassBox(
          borderRadius: 0,
          blur: 15,
          opacity: 0.1,
          child: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            elevation: 0,
            centerTitle: true,
            title: Text(
              "Chat",
              style: TextStyle(fontSize: 17, color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.system_update,
                  color: _isUpdateAvailable
                      ? AppColors.mainColor
                      : Colors.white70,
                ),
                onPressed: _manualCheckForUpdate,
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgGradientTop,
              AppColors.bgGradientMid,
              AppColors.bgGradientBot,
            ],
          ),
        ),
        child: Stack(
          // 🔥 Використовуємо Stack, щоб панель плавала зверху
          children: [
            // 1. СПИСОК ПОВІДОМЛЕНЬ
            Positioned.fill(
              child: ListView.builder(
                controller: _scrollController,
                // Додаємо відступ знизу, щоб повідомлення не ховалися ПІД панеллю в самому кінці
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 100,
                  bottom: 100 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  // ... (Ваш існуючий itemBuilder для MessageBubble) ...
                  final msg = messages[index];
                  final isMe = msg['sender'] == myName;
                  return MessageBubble(
                    text: msg['type'] == 'image' ? '' : (msg['text'] ?? ''),
                    imageUrl: msg['type'] == 'image' ? msg['text'] : null,
                    sender: msg['sender'] ?? 'Anon',
                    isMe: isMe,
                    timestamp: msg['timestamp'],
                    isRead: msg['read'] == true,
                  );
                },
              ),
            ),

            // 2. ПЛАВАЮЧА ПАНЕЛЬ ВВОДУ (Positioned знизу)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                // Робимо легке розмиття фону під кнопками для кращої читабельності
                padding: EdgeInsets.fromLTRB(
                  10,
                  20,
                  10,
                  10 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.bgGradientBot.withOpacity(
                        0.8,
                      ), // М'яке затінення фону
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Кнопка +
                    _buildFloatingButton(
                      icon: Icons.add,
                      onPressed: _pickAndUploadImage,
                    ),
                    const SizedBox(width: 8),
                    // Овальне поле
                    Expanded(
                      child: GlassBox(
                        borderRadius: 30,
                        opacity: 0.15,
                        blur: 20,
                        border: Border.all(color: Colors.white12),
                        child: TextField(
                          controller: textController,
                          onChanged: (text) {
                            if (text.isNotEmpty)
                              socket.emit('typing', {'username': myName});
                          },
                          style: const TextStyle(color: Colors.white),
                          maxLines: 5,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: "Повідомлення...",
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Кнопка стрілка
                    _buildFloatingButton(
                      icon: Icons.arrow_upward,
                      onPressed: sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Допоміжний метод для круглих кнопок
  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.mainColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

// 🔥 BUBBLE З НОВИМИ КОЛЬОРАМИ
class MessageBubble extends StatelessWidget {
  final String text;
  final String sender;
  final String? imageUrl;
  final bool isMe;
  final dynamic timestamp;
  final String? avatarUrl;
  final bool isRead;

  const MessageBubble({
    super.key,
    required this.text,
    required this.sender,
    required this.isMe,
    this.imageUrl,
    this.timestamp,
    this.avatarUrl,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          // 🔥 ЯКЩО Я: Градієнт з AppColors
          gradient: isMe
              ? const LinearGradient(
                  colors: [AppColors.bubbleMeStart, AppColors.bubbleMeEnd],
                )
              : null,
          color: isMe ? null : AppColors.bubbleOther.withOpacity(0.1),

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          border: isMe
              ? null
              : Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: isMe
              ? [
                  BoxShadow(
                    color: AppColors.mainColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    sender,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainColor.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ),

              if (imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl!, fit: BoxFit.cover),
                  ),
                ),

              if (text.isNotEmpty)
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),

              const SizedBox(height: 4),

              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 5),
                    Icon(
                      isRead ? Icons.done_all : Icons.check,
                      size: 14,
                      color: isRead
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) {
      final now = DateTime.now();
      return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else if (timestamp is Map && timestamp['_seconds'] != null) {
        date = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else {
        return '';
      }
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }
}

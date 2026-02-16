import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'animated_widgets.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';

// ==========================================
// 🎨 НАЛАШТУВАННЯ КОЛЬОРІВ ТА СЕРВЕРА
// ==========================================
const String serverUrl = 'https://pproject-y.onrender.com';

class AppColors {
  static const Color mainColor = Color(0xFF3A76F0);
  static const Color bgGradientTop = Color(0xFF1b1e28);
  static const Color bgGradientMid = Color(0xFF1b1e28);
  static const Color bgGradientBot = Color(0xFF1b1e28);
  static const Color bubbleMeStart = mainColor;
  static const Color bubbleMeEnd = Color(0xCC2C61D6);
  static const Color bubbleOther = Colors.white;
  static const Color white = Colors.white;
  static const Color whiteGlass = Colors.white10;
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🌙 Фонове повідомлення: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    this.opacity = 0.1,
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
                Border.all(color: Colors.white.withOpacity(0.1), width: 0.3),
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
      setState(() => _avatarFile = File(image.path));
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
                          elevation: 0,
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
// 💬 ЕКРАН ЧАТУ З REPLY
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
  // int? _currentPatch; // 🔥 ВИДАЛЕНО: не використовується

  late String myName;
  bool _isTyping = false;
  String? _typingUser;
  Timer? _typingTimer;

  List<String> _onlineUsers = [];

  // 🔥 НОВИЙ КОД: Reply змінні
  String? _replyToMessageId;
  String? _replyToText;
  String? _replyToSender;

  // 🔥 НОВИЙ КОД: Edit змінні
  String? _editingMessageId;
  String? _editingOriginalText;
  bool _isEditing = false;

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

  Future<void> _checkShorebirdSilent() async {
    try {
      if (!_updater.isAvailable) return;
      // final patch = await _updater.readCurrentPatch(); // 🔥 ВИДАЛЕНО
      final status = await _updater.checkForUpdate();
      setState(() {
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Версія актуальна!")));
        }
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
      if (token != null) {
        socket.emit('register_token', {
          'token': token,
          'username': widget.username,
        });
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("📱 Push received: ${message.notification?.title}");
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

    socket.onConnect((_) {
      print('✅ Connected to server');
      socket.emit('user_online', myName);
    });

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
      if (mounted && data['username'] != myName) {
        setState(() {
          _isTyping = true;
          _typingUser = data['username'];
        });
        _scrollToBottom();
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

    socket.on('online_users', (data) {
      if (mounted) {
        setState(() {
          _onlineUsers = List<String>.from(data);
        });
      }
    });

    // 🔥 НОВИЙ КОД: Слухаємо оновлення реакцій
    socket.on('reaction_updated', (data) {
      if (mounted) {
        setState(() {
          final messageIndex = messages.indexWhere(
            (msg) => msg['id'] == data['messageId'],
          );
          if (messageIndex != -1) {
            messages[messageIndex]['reactions'] = data['reactions'];
          }
        });
      }
    });

    // 🔥 НОВИЙ КОД: Слухач для відредагованих повідомлень
    socket.on('message_edited', (data) {
      if (mounted) {
        setState(() {
          final messageIndex = messages.indexWhere(
            (msg) => msg['id'] == data['messageId'],
          );
          if (messageIndex != -1) {
            messages[messageIndex]['text'] = data['newText'];
            messages[messageIndex]['edited'] = true;
          }
        });
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

  // 🔥 НОВИЙ КОД: Reply функції
  void _setReplyTo(Map message) {
    setState(() {
      _replyToMessageId = message['id'];
      _replyToText = message['type'] == 'image' ? '📷 Фото' : message['text'];
      _replyToSender = message['sender'];
    });
    // Прокручуємо до reply preview
    _scrollToBottom();
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToText = null;
      _replyToSender = null;
    });
  }

  // 🔥 НОВИЙ КОД: Функції для редагування
  void _startEditingMessage(Map message) {
    setState(() {
      _editingMessageId = message['id'];
      _editingOriginalText = message['text'];
      _isEditing = true;
      textController.text = message['text'];
    });
    // Прокручуємо вниз і фокусуємо поле
    _scrollToBottom();
  }

  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
      _isEditing = false;
      textController.clear();
    });
  }

  void _saveEditedMessage() {
    final newText = textController.text.trim();
    if (newText.isEmpty || newText == _editingOriginalText) {
      _cancelEditing();
      return;
    }

    socket.emit('edit_message', {
      'messageId': _editingMessageId,
      'newText': newText,
      'username': myName,
    });

    _cancelEditing();
  }

  // 🔥 НОВИЙ КОД: Функція для додавання реакції
  void _addReaction(String messageId, String emoji) {
    socket.emit('add_reaction', {
      'messageId': messageId,
      'emoji': emoji,
      'username': myName,
    });
  }

  void sendMessage({String? imageUrl, String type = 'text'}) {
    String text = textController.text.trim();
    if (text.isEmpty && imageUrl == null) return;

    // 🔥 НОВИЙ КОД: Якщо редагуємо - зберігаємо зміни
    if (_isEditing) {
      _saveEditedMessage();
      return;
    }

    // 🔥 ВИПРАВЛЕНО: Додаємо всі поля одразу при ініціалізації
    final messageData = {
      'text': imageUrl ?? text,
      'sender': myName,
      'senderAvatar': widget.avatarUrl,
      'type': type,
      // Додаємо replyTo відразу (буде null якщо немає reply)
      if (_replyToMessageId != null)
        'replyTo': {
          'id': _replyToMessageId,
          'text': _replyToText,
          'sender': _replyToSender,
        },
    };

    socket.emit('send_message', messageData);
    textController.clear();

    // Скидаємо reply
    _cancelReply();
  }

  // 🔥 НОВИЙ КОД: Reply preview widget
  Widget _buildReplyPreview() {
    if (_replyToMessageId == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.mainColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyToSender ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mainColor,
                    fontWeight: FontWeight.bold, //FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _replyToText ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  // 🔥 НОВИЙ КОД: Editing header widget
  Widget _buildEditingHeader() {
    if (!_isEditing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.mainColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mainColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, color: AppColors.mainColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Редагування повідомлення',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mainColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _editingOriginalText ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: _cancelEditing,
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Map message) {
    final isMe = message['sender'] == myName;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2a2d38),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 НОВИЙ КОД: Панель реакцій зверху
            Padding(
              padding: const EdgeInsets.all(16),
              child: ReactionPicker(
                onReactionSelected: (emoji) {
                  _addReaction(message['id'], emoji);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.more_horiz, color: Colors.white70),
                  const SizedBox(width: 12),
                  Text(
                    'Дії з повідомленням',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text(
                'Копіювати',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message['text'] ?? ''));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Скопійовано'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            // 🔥 НОВИЙ КОД: Кнопка відповісти
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white70),
              title: const Text(
                'Відповісти',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _setReplyTo(message);
              },
            ),

            ListTile(
              leading: const Icon(Icons.forward, color: Colors.white70),
              title: const Text(
                'Переслати',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Функція в розробці'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            if (isMe) ...[
              const Divider(color: Colors.white12, height: 1),
              // 🔥 НОВИЙ КОД: Кнопка редагувати (тільки для текстових повідомлень)
              if (message['type'] != 'image')
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white70),
                  title: const Text(
                    'Редагувати',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEditingMessage(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Видалити',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(message['id']);
                },
              ),
            ],

            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
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

  DateTime _parseDate(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    try {
      if (timestamp is String) return DateTime.parse(timestamp);
      if (timestamp is Map && timestamp['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      }
    } catch (e) {}
    return DateTime.now();
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return "Сьогодні";
    if (messageDate == yesterday) return "Вчора";

    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
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
          blur: 15,
          opacity: 0.1,
          child: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            elevation: 0,
            centerTitle: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Chat",
                  style: TextStyle(fontSize: 17, color: Colors.white),
                ),
                Text(
                  '${_onlineUsers.length} онлайн',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
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
          children: [
            Positioned.fill(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 100,
                  bottom: 100 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount:
                    messages.length +
                    (_isTyping && _typingUser != null ? 1 : 0) +
                    (_replyToMessageId != null ? 1 : 0) + // reply preview
                    (_isEditing ? 1 : 0), // 🔥 НОВИЙ: editing preview
                itemBuilder: (context, index) {
                  // 🔥 НОВИЙ КОД: Reply/Edit Preview як останній елемент
                  final totalMessages = messages.length;
                  final hasTyping = _isTyping && _typingUser != null;
                  final hasReply = _replyToMessageId != null;
                  final hasEditing = _isEditing;

                  // Показуємо editing preview (якщо є) - останнім
                  if (hasEditing &&
                      index ==
                          totalMessages +
                              (hasTyping ? 1 : 0) +
                              (hasReply ? 1 : 0)) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        left: 10,
                        right: 10,
                      ),
                      child: _buildEditingHeader(),
                    );
                  }

                  // Показуємо reply preview (якщо є)
                  if (hasReply &&
                      index == totalMessages + (hasTyping ? 1 : 0)) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        left: 10,
                        right: 10,
                      ),
                      child: _buildReplyPreview(),
                    );
                  }

                  // Показуємо typing indicator
                  if (hasTyping && index == totalMessages) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TypingIndicator(username: _typingUser!),
                    );
                  }

                  final msg = messages[index];
                  final isMe = msg['sender'] == myName;

                  bool showDateSeparator = false;
                  if (index == 0) {
                    showDateSeparator = true;
                  } else {
                    final currentDate = _parseDate(msg['timestamp']);
                    final prevDate = _parseDate(
                      messages[index - 1]['timestamp'],
                    );
                    showDateSeparator = !_isSameDay(currentDate, prevDate);
                  }
                  final dateLabel = _getDateLabel(_parseDate(msg['timestamp']));

                  return Column(
                    children: [
                      if (showDateSeparator) DateSeparator(date: dateLabel),

                      // 🔥 SWIPE-TO-REPLY: Потягніть вправо для відповіді
                      SwipeToReply(
                        onReply: () => _setReplyTo(msg),
                        replyIconColor: isMe
                            ? Colors
                                  .white // Для своїх
                            : Colors.white, // Для чужих
                        child: GestureDetector(
                          onLongPress: () => _showContextMenu(context, msg),
                          child: AnimatedMessageBubble(
                            isMe: isMe,
                            child: MessageBubble(
                              text: msg['type'] == 'image'
                                  ? ''
                                  : (msg['text'] ?? ''),
                              imageUrl: msg['type'] == 'image'
                                  ? msg['text']
                                  : null,
                              sender: msg['sender'] ?? 'Anon',
                              isMe: isMe,
                              timestamp: msg['timestamp'],
                              isRead: msg['read'] == true,
                              replyTo: msg['replyTo'],
                              reactions: msg['reactions'],
                              messageId: msg['id'],
                              currentUsername: myName,
                              onReactionTap: _addReaction,
                              edited: msg['edited'] == true, // 🔥 НОВИЙ
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
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
                      AppColors.bgGradientBot.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildFloatingButton(
                      icon: Icons.add,
                      onPressed: _pickAndUploadImage,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GlassBox(
                        borderRadius: 30,
                        opacity: 0.15,
                        blur: 20,
                        border: Border.all(color: Colors.white12),
                        child: TextField(
                          controller: textController,
                          onChanged: (text) {
                            if (text.isNotEmpty) {
                              socket.emit('typing', {
                                'username': myName,
                                'roomId': 'general',
                              });
                            }
                          },
                          style: const TextStyle(color: Colors.white),
                          maxLines: 6,
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
                    _buildFloatingButton(
                      // 🔥 НОВИЙ КОД: Різні іконки для відправки і редагування
                      icon: _isEditing ? Icons.check : Icons.arrow_upward,
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

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mainColor,
        shape: BoxShape.circle,
        // 🔥 ВИДАЛЕНО boxShadow
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

// =======================
// 🔥 НОВИЙ КОД: ReplyPreview Widget
// =======================
class ReplyPreview extends StatelessWidget {
  final Map? replyTo;
  final VoidCallback? onTap;
  final bool isMe; // 🔥 НОВИЙ: для вибору кольору лінії

  const ReplyPreview({
    super.key,
    this.replyTo,
    this.onTap,
    this.isMe = false, // 🔥 НОВИЙ
  });

  @override
  Widget build(BuildContext context) {
    if (replyTo == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            // 🔥 ЗМІНЕНО: біла лінія для своїх, синя для чужих (як в Signal)
            left: BorderSide(
              color: isMe ? Colors.white : AppColors.mainColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replyTo!['sender'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white, //mainColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              replyTo!['text'] ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================
// 💬 MessageBubble з Reply
// =======================
class MessageBubble extends StatelessWidget {
  final String text;
  final String sender;
  final String? imageUrl;
  final bool isMe;
  final dynamic timestamp;
  final String? avatarUrl;
  final bool isRead;
  final Map? replyTo;
  final Map<String, dynamic>? reactions;
  final String messageId;
  final String currentUsername;
  final Function(String messageId, String emoji)? onReactionTap;
  final bool edited; // 🔥 НОВИЙ

  const MessageBubble({
    super.key,
    required this.text,
    required this.sender,
    required this.isMe,
    this.imageUrl,
    this.timestamp,
    this.avatarUrl,
    this.isRead = false,
    this.replyTo,
    this.reactions,
    required this.messageId,
    required this.currentUsername,
    this.onReactionTap,
    this.edited = false, // 🔥 НОВИЙ
  });

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(timestamp);

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Саме повідомлення
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
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
              // 🔥 ВИДАЛЕНО boxShadow
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

                  // 🔥 НОВИЙ КОД: Показуємо reply preview
                  if (replyTo != null)
                    ReplyPreview(
                      replyTo: replyTo,
                      isMe: isMe, // 🔥 ПЕРЕДАЄМО isMe
                      onTap: () {
                        print('Scroll to message: ${replyTo!['id']}');
                      },
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
                      // 🔥 НОВИЙ КОД: Показуємо "edited" якщо повідомлення відредаговано
                      if (edited) ...[
                        Text(
                          'edited.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
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
        ),

        // 🔥 НОВИЙ КОД: Реакції під повідомленням
        if (reactions != null && reactions!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: -13,
              left: 8,
              right: 8,
            ), // 🔥 12→8, 4→2 компактніше
            child: ReactionsDisplay(
              reactions: reactions,
              currentUsername: currentUsername,
              onReactionTap: (emoji) {
                if (onReactionTap != null) {
                  onReactionTap!(messageId, emoji);
                }
              },
            ),
          ),
      ],
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

//---------+++++-------+++++++++--------++++++++--------++++++++------++++++++++++
// =======================
// ❤️ REACTION PICKER WIDGET
// =======================
class ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;

  const ReactionPicker({super.key, required this.onReactionSelected});

  static const reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏', '🔥', '👏'];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: reactions.map((emoji) {
            return GestureDetector(
              onTap: () => onReactionSelected(emoji),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4), // 🔥 6 → 4
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24), // 🔥 28 → 24
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// =======================
// 💬 REACTIONS DISPLAY WIDGET
// =======================
class ReactionsDisplay extends StatelessWidget {
  final Map<String, dynamic>? reactions;
  final String currentUsername;
  final Function(String) onReactionTap;

  const ReactionsDisplay({
    super.key,
    this.reactions,
    required this.currentUsername,
    required this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions == null || reactions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 0), // 🔥 4 → 2 ближче до повідомлення
      child: Wrap(
        spacing: 2, // 🔥 6 → 3 компактніше
        runSpacing: 3,
        children: reactions!.entries.map((entry) {
          final emoji = entry.key;
          final users = List<String>.from(entry.value);
          final hasMyReaction = users.contains(currentUsername);

          return GestureDetector(
            onTap: () => onReactionTap(emoji),
            child: Container(
              // 🔥 КОМПАКТНИЙ ДИЗАЙН як в Signal
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ), // 🔥 10×6 → 6×3
              decoration: BoxDecoration(
                color: hasMyReaction
                    ? Colors.grey[900]?.withOpacity(0.7)
                    : Colors.grey[900]?.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                // 🔥 20 → 12 менш круглий
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 14), // 🔥 18 → 14 менше
                  ),
                  if (users.length > 1) ...[
                    const SizedBox(width: 3), // 🔥 4 → 3
                    Text(
                      '${users.length}',
                      style: const TextStyle(
                        fontSize: 11, // 🔥 13 → 11 менше
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =======================
// 🎯 SWIPE-TO-REPLY WIDGET
// =======================
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final Color? replyIconColor;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.replyIconColor,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconOpacityAnimation;

  double _dragExtent = 0;
  bool _dragUnderway = false;

  static const double _kReplyThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _iconScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _iconOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragUnderway = true;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragUnderway) return;

    final delta = details.primaryDelta!;

    if (delta > 0) {
      setState(() {
        _dragExtent = (_dragExtent + delta).clamp(0.0, _kReplyThreshold * 1.5);
        _controller.value = (_dragExtent / _kReplyThreshold).clamp(0.0, 1.0);
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragUnderway) return;
    _dragUnderway = false;

    if (_dragExtent >= _kReplyThreshold) {
      // Додайте вібрацію
      Vibration.vibrate(duration: 50); // 🔥 НОВИЙ КОД
      widget.onReply();
    }

    if (_dragExtent >= _kReplyThreshold) {
      SystemSound.play(SystemSoundType.click); // 🔥 НОВИЙ КОД
      widget.onReply();
    }

    if (_dragExtent >= _kReplyThreshold) {
      widget.onReply();
    }

    setState(() {
      _dragExtent = 0;
    });
    _controller.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: Opacity(
                    opacity: _iconOpacityAnimation.value,
                    child: Transform.scale(
                      scale: _iconScaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (widget.replyIconColor ?? AppColors.mainColor)
                              .withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply,
                          color: widget.replyIconColor ?? AppColors.mainColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_dragExtent, 0),
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

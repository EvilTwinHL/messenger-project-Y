import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Для перевірки kIsWeb
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 Для пам'яті
// 🔥 FIREBASE
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// --- НАЛАШТУВАННЯ ---
const String serverUrl = 'https://pproject-y.onrender.com';

// 🔥 ФОНОВИЙ ОБРОБНИК
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🌙 Фонове повідомлення: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Ініціалізація Firebase (ТІЛЬКИ для Android/iOS)
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

  // 2. Перевірка входу (Оригінальна логіка)
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
      title: 'Мій Месенджер',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: initialScreen,
    );
  }
}

// =======================
// 🔐 ЕКРАН ВХОДУ (ОРИГІНАЛ)
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
      backgroundColor: Colors.indigo,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _avatarFile != null
                        ? FileImage(_avatarFile!)
                        : null,
                    child: _avatarFile == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: Colors.indigo,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Торкніться для фото",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: "Ваш нікнейм",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("УВІЙТИ"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================
// 💬 ЕКРАН ЧАТУ (ЗБЕРЕЖЕНО ОРИГІНАЛЬНУ ЛОГІКУ)
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

  // --- 🔥 SHOREBIRD UPDATER ---
  final _updater = ShorebirdUpdater();
  bool _isUpdateAvailable = false;
  int? _currentPatch;

  late String myName;

  @override
  void initState() {
    super.initState();
    myName = widget.username;
    initSocket();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Future.delayed(const Duration(seconds: 2), setupPushNotifications);
    }

    // 🔥 Перевірка оновлень при старті
    _checkShorebirdSilent();
  }

  // --- 🔥 ЛОГІКА SHOREBIRD (НОВИЙ API) ---

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
      _logToServer("Shorebird silent check error: $e");
    }
  }

  Future<void> _manualCheckForUpdate() async {
    if (!Platform.isAndroid) return;

    // Показуємо Snackbar, що почалася перевірка
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Перевірка оновлень..."),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Оновлення!"),
            content: Text(
              "Доступний новий патч. Поточна версія: #${_currentPatch ?? 'Base'}.\nЗавантажити нову версію?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Ні"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _runUpdateProcess();
                },
                child: const Text("Так"),
              ),
            ],
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("У вас найновіша версія!")),
          );
        }
      }
    } catch (e) {
      _logToServer("Manual update error: $e");
    }
  }

  Future<void> _runUpdateProcess() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text("Завантаження..."),
        content: LinearProgressIndicator(),
      ),
    );

    try {
      await _updater.update();
      if (mounted) Navigator.pop(context); // Закрити LinearProgress

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Готово!"),
            content: const Text(
              "Перезапустіть додаток, щоб зміни вступили в силу.",
            ),
            actions: [
              TextButton(
                onPressed: () => exit(0),
                child: const Text("Вийти зараз"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Пізніше"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _logToServer("Update download error: $e");
    }
  }

  // 🔥 ОРИГІНАЛЬНА ФУНКЦІЯ ДЛЯ ДІАГНОСТИКИ
  void _logToServer(String msg) {
    print("LOG: $msg");
    if (socket.connected) {
      socket.emit('debug_log', "User $myName: $msg");
    }
  }

  // --- 🔔 ЛОГІКА ПУШІВ (ЗБЕРЕЖЕНО) ---
  Future<void> setupPushNotifications() async {
    _logToServer("🚀 Починаю налаштування пушів...");
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _logToServer("👮 Статус дозволу: ${settings.authorizationStatus}");
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token;
        try {
          token = await messaging.getToken();
        } catch (e) {
          _logToServer("⚠️ Помилка 1-ї спроби: $e. Чекаю 5 сек...");
          await Future.delayed(const Duration(seconds: 5));
          try {
            token = await messaging.getToken();
          } catch (e2) {
            _logToServer("❌ Помилка 2-ї спроби: $e2");
          }
        }
        if (token != null) {
          _logToServer("🔑 Токен отримано!");
          socket.emit('register_token', {
            'token': token,
            'username': widget.username,
          });
        }
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logToServer("🔔 Прийшло повідомлення: ${message.notification?.title}");
        if (mounted && message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${message.notification!.title}: ${message.notification!.body}",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    } catch (e) {
      _logToServer("❌ КРИТИЧНА ПОМИЛКА ПУШІВ: $e");
    }
  }

  // --- Вихід (Logout) ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // --- Socket.IO (ЗБЕРЕЖЕНО) ---
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
      print('✅ Підключено до сервера');
      _logToServer("✅ Сокет підключився успішно");
    });
    socket.on('load_history', (data) {
      if (data != null) {
        setState(() {
          messages.clear();
          for (var msg in data) {
            messages.add(msg);
          }
        });
        _scrollToBottom();
      }
    });
    socket.on('receive_message', (data) {
      setState(() => messages.add(data));
      _scrollToBottom();
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

  @override
  void dispose() {
    socket.dispose();
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.avatarUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(widget.avatarUrl!),
                radius: 16,
              ),
            const SizedBox(width: 10),
            Text("Чат ($myName)"),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // 🔥 Оновлена кнопка Shorebird з індикацією
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.system_update,
                  color: _isUpdateAvailable ? Colors.greenAccent : Colors.white,
                ),
                onPressed: _manualCheckForUpdate,
              ),
              if (_isUpdateAvailable)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.exit_to_app), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          // --- 🔥 ТУТ ЗМІНЕНО: Використовуємо MessageBubble ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['sender'] == myName;
                final isImage = msg['type'] == 'image';
                final String content = msg['text'] ?? '';
                final String? avatar = msg['senderAvatar'];
                final dynamic timestamp = msg['timestamp']; // Отримуємо час

                return MessageBubble(
                  text: isImage ? '' : content,
                  imageUrl: isImage ? content : null,
                  sender: msg['sender'] ?? 'Anon',
                  isMe: isMe,
                  avatarUrl: avatar,
                  timestamp: timestamp,
                );
              },
            ),
          ),
          // ----------------------------------------------------
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.indigo),
                  onPressed: _pickAndUploadImage,
                ),
                Expanded(
                  child: TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: "Повідомлення...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//--------NEW BUBBLE MESSEAG
class MessageBubble extends StatelessWidget {
  final String text;
  final String sender;
  final String? imageUrl;
  final bool isMe;
  final dynamic timestamp; // Час з Firebase
  final String? avatarUrl;

  const MessageBubble({
    super.key,
    required this.text,
    required this.sender,
    required this.isMe,
    this.imageUrl,
    this.timestamp,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Форматування часу (потрібно додати intl package або просту функцію)
    final timeText = _formatTime(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Аватарка (тільки для співрозмовника)
          if (!isMe) ...[
            CircleAvatar(
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              radius: 16,
              child: avatarUrl == null
                  ? Text(
                      sender.isNotEmpty ? sender[0].toUpperCase() : "?",
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          // Сама бульбашка
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.indigo[100]
                    : Colors.grey[200], // Кольори як у Telegram
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(0), // "Хвостик" зліва
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(16), // "Хвостик" справа
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Ім'я автора (тільки в групах, якщо не я)
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        sender,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[800],
                          fontSize: 12,
                        ),
                      ),
                    ),

                  // Картинка (якщо є)
                  if (imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          imageUrl!,
                          height: 200, // Обмежуємо висоту
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // Текст повідомлення
                  if (text.isNotEmpty)
                    Text(text, style: const TextStyle(fontSize: 16)),

                  const SizedBox(height: 4),

                  // Час та галочки
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeText,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        // 🔥 ВИПРАВЛЕННЯ: Показуємо "Надіслано" (одна галочка), а не "Прочитано"
                        const Icon(
                          Icons.check, // Була Icons.done_all
                          size: 12,
                          color: Colors.grey, // Був Colors.blue
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Проста функція для часу
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

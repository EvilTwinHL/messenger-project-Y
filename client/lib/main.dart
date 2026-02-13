import 'dart:convert';
import 'dart:io'; // Для перевірки платформи
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shorebird_code_push/shorebird_code_push.dart'; // 📦 Бібліотека оновлень
// 🔥 БІБЛІОТЕКИ ДЛЯ ПУШІВ (тільки для Android/iOS)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// --- НАЛАШТУВАННЯ ---
const String serverUrl = 'https://pproject-y.onrender.com';

// 🔥 ФОНОВИЙ ОБРОБНИК (Має бути поза класом MyApp!)
// Працює, коли додаток закритий або згорнутий
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🌙 Фонове повідомлення: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Ініціалізація Firebase ТІЛЬКИ для Android/iOS
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();

      // Налаштування фонового обробника
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      print("✅ Firebase ініціалізовано для ${Platform.operatingSystem}");
    } catch (e) {
      print("❌ Помилка ініціалізації Firebase: $e");
    }
  } else {
    print(
      "ℹ️ Firebase пропущено для ${Platform.operatingSystem} (не підтримується)",
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Мій Крос-Месенджер',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // --- Змінні чату ---
  List<Map<String, dynamic>> messages = [];
  final TextEditingController textController = TextEditingController();
  late IO.Socket socket;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final String myName = Platform.isAndroid ? 'Android' : 'Windows';

  // --- Інструмент оновлення (Shorebird) ---
  final _updater = ShorebirdUpdater();
  bool _isCheckingForUpdate = false;

  @override
  void initState() {
    super.initState();
    initSocket();

    // ✅ Запускаємо налаштування пушів ТІЛЬКИ на Android/iOS
    if (Platform.isAndroid || Platform.isIOS) {
      setupPushNotifications();
    }

    // Виводимо версію патчу (для контролю)
    _updater.readCurrentPatch().then((currentPatch) {
      print('Поточний номер патчу: ${currentPatch?.number ?? "Немає (База)"}');
    });
  }

  // --- 🔔 ЛОГІКА ПУШІВ (Push Notifications) 🔔 ---
  // ✅ Цей метод викликається ТІЛЬКИ на Android/iOS
  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Питаємо дозвіл (важливо для Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Дозвіл на сповіщення отримано');

      // 2. Отримуємо унікальний токен цього телефону
      String? token = await messaging.getToken();
      print("🔑 МІЙ FCM TOKEN: $token");

      // 3. Відправляємо токен на сервер (якщо сокет вже підключений)
      if (token != null && socket.connected) {
        socket.emit('register_token', token);
      }

      // Якщо токен зміниться (наприклад, перевстановили додаток)
      messaging.onTokenRefresh.listen((newToken) {
        socket.emit('register_token', newToken);
      });
    } else {
      print('❌ Користувач заборонив сповіщення');
    }

    // 4. Слухаємо повідомлення, коли додаток ВІДКРИТИЙ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Пуш при відкритому додатку: ${message.notification?.title}');

      // Показуємо красиву плашку
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${message.notification!.title}: ${message.notification!.body}",
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }
  // -----------------------------------------------

  // --- ЛОГІКА ОНОВЛЕННЯ (SHOREBIRD) ---
  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Авто-оновлення працює тільки на Android"),
        ),
      );
      return;
    }

    setState(() => _isCheckingForUpdate = true);

    try {
      final status = await _updater.checkForUpdate();

      if (!mounted) return;
      setState(() => _isCheckingForUpdate = false);

      if (status == UpdateStatus.outdated) {
        _showUpdateDialog();
      } else if (status == UpdateStatus.upToDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("У вас найсвіжіша версія! ✅")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Оновлень не знайдено.")));
      }
    } catch (e) {
      setState(() => _isCheckingForUpdate = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Помилка: $e")));
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Доступне оновлення! 🚀"),
          content: const Text("Знайдено нову версію. Завантажити?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Пізніше"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _downloadAndApplyUpdate();
              },
              child: const Text("Завантажити"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndApplyUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Завантаження оновлення... ⏳")),
    );

    try {
      await _updater.update();

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Готово! 🎉"),
          content: const Text("Оновлення встановлено. Перезапустіть додаток."),
          actions: [
            ElevatedButton(
              onPressed: () => exit(0),
              child: const Text("Перезапустити"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Помилка: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- ЛОГІКА ЧАТУ (SOCKET.IO) ---
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

      // ✅ При підключенні відправляємо токен знову ТІЛЬКИ для Android/iOS
      if (Platform.isAndroid || Platform.isIOS) {
        FirebaseMessaging.instance
            .getToken()
            .then((token) {
              if (token != null) {
                socket.emit('register_token', token);
                print('🔑 Токен відправлено на сервер');
              }
            })
            .catchError((error) {
              print('❌ Помилка отримання токена: $error');
            });
      }
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
      setState(() {
        messages.add(data);
      });
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Завантаження фото...")));

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        String imageUrl = json['url'];
        socket.emit('send_message', {
          'text': imageUrl,
          'sender': myName,
          'type': 'image',
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Помилка: $e")));
    }
  }

  void sendMessage() {
    String text = textController.text.trim();
    if (text.isNotEmpty) {
      socket.emit('send_message', {
        'text': text,
        'sender': myName,
        'type': 'text',
      });
      textController.clear();
    }
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
        title: Text("Чат ($myName)"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          _isCheckingForUpdate
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.system_update),
                  tooltip: "Перевірити оновлення",
                  onPressed: _checkForUpdate,
                ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['sender'] == myName;
                final isImage = msg['type'] == 'image';
                final String content = msg['text'] ?? '';

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 10,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender'],
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        isImage
                            ? SizedBox(
                                width: 200,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    content.startsWith('http')
                                        ? content
                                        : '$serverUrl/$content',
                                    errorBuilder: (c, e, s) =>
                                        const Icon(Icons.broken_image),
                                  ),
                                ),
                              )
                            : Text(
                                content,
                                style: const TextStyle(fontSize: 16),
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
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
                      hintText: "Напишіть повідомлення...",
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
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

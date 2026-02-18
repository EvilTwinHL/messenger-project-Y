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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'animated_widgets.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'audio_player_widget.dart';
import 'home_screen.dart';

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
          ? HomeScreen(myUsername: savedUsername, myAvatarUrl: savedAvatar)
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
                Border.all(
                  color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.1),
                  width: 0.3,
                ),
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
                HomeScreen(myUsername: username, myAvatarUrl: finalAvatarUrl),
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
// 💬 ЕКРАН ЧАТУ (Оновлений на StreamBuilder)
// =======================
class ChatScreen extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final String chatId; // 🔥 ID Кімнати
  final String otherUsername; // 🔥 Ім'я співрозмовника

  const ChatScreen({
    super.key,
    required this.username,
    required this.chatId,
    required this.otherUsername,
    this.avatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController textController = TextEditingController();
  late IO.Socket socket;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final _updater = ShorebirdUpdater();
  bool _isUpdateAvailable = false;

  late String myName;
  bool _isTyping = false;
  String? _typingUser;
  Timer? _typingTimer;

  // Reply змінні
  String? _replyToMessageId;
  String? _replyToText;
  String? _replyToSender;

  // Edit змінні
  String? _editingMessageId;
  String? _editingOriginalText;
  bool _isEditing = false;

  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _showVoiceConfirm = false;
  String? _recordedFilePath;
  int _recordedDuration = 0;
  Timer? _recordingTimer;

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    myName = widget.username;
    initSocket();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Future.delayed(const Duration(seconds: 2), setupPushNotifications);
    }
    _checkShorebirdSilent();
    textController.addListener(() {
      final hasText = textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  Future<void> _checkShorebirdSilent() async {
    try {
      if (!_updater.isAvailable) return;
      final status = await _updater.checkForUpdate();
      if (mounted) {
        setState(() {
          _isUpdateAvailable = status == UpdateStatus.outdated;
        });
      }
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
      if (token != null && socket.connected) {
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
      // 🔥 ВХІД В КІМНАТУ
      socket.emit('join_chat', widget.chatId);
    });

    socket.on('display_typing', (data) {
      if (mounted && data['username'] != myName) {
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

  void _setReplyTo(Map message) {
    setState(() {
      _replyToMessageId = message['id'];
      _replyToText = message['type'] == 'image' ? '📷 Фото' : message['text'];
      _replyToSender = message['sender'];
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToText = null;
      _replyToSender = null;
    });
  }

  void _startEditingMessage(Map message) {
    setState(() {
      _editingMessageId = message['id'];
      _editingOriginalText = message['text'];
      _isEditing = true;
      textController.text = message['text'];
    });
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

    if (socket.connected) {
      socket.emit('edit_message', {
        'messageId': _editingMessageId,
        'newText': newText,
        'username': myName,
        'chatId': widget.chatId,
      });
    }

    _cancelEditing();
  }

  Future<void> _onMicPressStart() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Потрібен доступ до мікрофону')),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _recordedFilePath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
      _recordedDuration = 0;

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordedFilePath!,
      );

      if (mounted) {
        setState(() => _isRecording = true);
      }

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _recordedDuration++);
      });
    } catch (e) {
      print('Помилка запису: $e');
    }
  }

  Future<void> _onMicPressEnd() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();

    if (mounted) {
      setState(() {
        _isRecording = false;
        if (_recordedDuration >= 1 && path != null) {
          _recordedFilePath = path;
          _showVoiceConfirm = true;
        } else {
          if (path != null) {
            try {
              File(path).deleteSync();
            } catch (_) {}
          }
          _recordedFilePath = null;
        }
      });
    }
  }

  Future<void> _confirmSendVoice() async {
    if (_recordedFilePath == null) return;
    final path = _recordedFilePath!;
    final duration = _recordedDuration;
    setState(() {
      _showVoiceConfirm = false;
      _recordedFilePath = null;
    });

    try {
      final file = File(path);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/upload-audio'),
      );
      request.files.add(await http.MultipartFile.fromPath('audio', file.path));
      final response = await request.send();
      final json = jsonDecode(await response.stream.bytesToString());

      if (json['url'] != null) {
        sendMessage(
          audioUrl: json['url'],
          audioDuration: duration,
          type: 'voice',
        );
      }
      await file.delete();
    } catch (e) {
      print('Помилка відправки голосового: $e');
    }
  }

  void _cancelVoice() {
    if (_recordedFilePath != null) {
      try {
        File(_recordedFilePath!).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _showVoiceConfirm = false;
      _recordedFilePath = null;
      _recordedDuration = 0;
    });
  }

  void _addReaction(String messageId, String emoji) {
    if (socket.connected) {
      socket.emit('add_reaction', {
        'messageId': messageId,
        'emoji': emoji,
        'username': myName,
        'chatId': widget.chatId,
      });
    }
  }

  void sendMessage({
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
    String type = 'text',
  }) {
    String text = textController.text.trim();
    if (text.isEmpty && imageUrl == null && audioUrl == null) return;

    if (_isEditing) {
      _saveEditedMessage();
      return;
    }

    final messageData = {
      'chatId': widget.chatId, // 🔥 ОБОВ'ЯЗКОВО
      'text': imageUrl ?? audioUrl ?? text,
      'sender': myName,
      'senderAvatar': widget.avatarUrl,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (audioDuration != null) 'audioDuration': audioDuration,
      if (_replyToMessageId != null)
        'replyTo': {
          'id': _replyToMessageId,
          'text': _replyToText,
          'sender': _replyToSender,
        },
    };

    if (socket.connected) {
      socket.emit('send_message', messageData);
    }
    textController.clear();
    _cancelReply();
  }

  Widget _buildReplyPreview() {
    if (_replyToMessageId == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 40, 40, 40).withOpacity(1.0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mainColor,
                    fontWeight: FontWeight.bold,
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

  Widget _buildEditingHeader() {
    if (!_isEditing) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 40, 40, 40).withOpacity(1.0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, color: AppColors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Редагування повідомлення',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mainColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _editingOriginalText ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
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
    final isText = message['type'] != 'image' && message['type'] != 'voice';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2d3a),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...['❤️', '👍', '👎', '😂', '😮', '😢'].map(
                        (emoji) => GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _addReaction(message['id'], emoji);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF2a2d3a),
                              content: ReactionPicker(
                                onReactionSelected: (emoji) {
                                  Navigator.of(context).pop();
                                  _addReaction(message['id'], emoji);
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_horiz,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2d3a),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuItem(
                        ctx,
                        icon: Icons.reply_outlined,
                        label: 'Відповісти',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _setReplyTo(message);
                        },
                      ),
                      _menuDivider(),
                      if (isText) ...[
                        _menuItem(
                          ctx,
                          icon: Icons.copy_outlined,
                          label: 'Копіювати',
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: message['text'] ?? ''),
                            );
                            Navigator.of(ctx).pop();
                          },
                        ),
                        _menuDivider(),
                      ],
                      if (isMe && isText) ...[
                        _menuItem(
                          ctx,
                          icon: Icons.edit_outlined,
                          label: 'Редагувати',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _startEditingMessage(message);
                          },
                        ),
                        _menuDivider(),
                      ],
                      _menuItem(
                        ctx,
                        icon: Icons.delete_outline,
                        label: 'Видалити',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showDeleteConfirmDialog(message['id']);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _menuDivider() =>
      const Divider(color: Colors.white10, height: 1, indent: 58);

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
              if (socket.connected) {
                socket.emit('delete_message', {
                  'messageId': messageId,
                  'chatId': widget.chatId,
                });
              }
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
      if (timestamp is Timestamp) return timestamp.toDate();
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
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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
          opacity: 1.0,
          child: AppBar(
            backgroundColor: const Color.fromARGB(
              255,
              36,
              36,
              36,
            ).withValues(alpha: 1.0),
            elevation: 0,
            centerTitle: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.otherUsername,
                  style: const TextStyle(fontSize: 17, color: Colors.white),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(50) // 🔥 ВАЖЛИВО: Ліміт, щоб не зависало
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  final messages = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return data;
                  }).toList();

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 100,
                      bottom:
                          160 +
                          MediaQuery.of(context).padding.bottom +
                          (_replyToMessageId != null ? 60 : 0) +
                          (_isEditing ? 60 : 0) +
                          (_isRecording ? 55 : 0) +
                          (_showVoiceConfirm ? 70 : 0),
                    ),
                    itemCount:
                        messages.length +
                        (_isTyping && _typingUser != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      final hasTyping = _isTyping && _typingUser != null;

                      if (hasTyping && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TypingIndicator(username: _typingUser!),
                        );
                      }

                      final msgIndex = hasTyping ? index - 1 : index;
                      final msg = messages[msgIndex];
                      final isMe = msg['sender'] == myName;

                      bool showDateSeparator = false;
                      if (msgIndex == messages.length - 1) {
                        showDateSeparator = true;
                      } else {
                        final currentDate = _parseDate(msg['timestamp']);
                        final prevDate = _parseDate(
                          messages[msgIndex + 1]['timestamp'],
                        );
                        showDateSeparator = !_isSameDay(currentDate, prevDate);
                      }
                      final dateLabel = _getDateLabel(
                        _parseDate(msg['timestamp']),
                      );

                      return Column(
                        children: [
                          if (showDateSeparator) DateSeparator(date: dateLabel),
                          SwipeToReply(
                            onReply: () => _setReplyTo(msg),
                            replyIconColor: Colors.white,
                            child: GestureDetector(
                              onLongPress: () => _showContextMenu(context, msg),
                              child: AnimatedMessageBubble(
                                isMe: isMe,
                                child: MessageBubble(
                                  text:
                                      msg['type'] == 'image' ||
                                          msg['type'] == 'voice'
                                      ? ''
                                      : (msg['text'] ?? ''),
                                  imageUrl: msg['type'] == 'image'
                                      ? msg['text']
                                      : null,
                                  audioUrl: msg['audioUrl'],
                                  audioDuration: msg['audioDuration'],
                                  sender: msg['sender'] ?? 'Anon',
                                  isMe: isMe,
                                  timestamp: msg['timestamp'],
                                  isRead: msg['read'] == true,
                                  replyTo: msg['replyTo'],
                                  reactions: msg['reactions'],
                                  messageId: msg['id'],
                                  currentUsername: myName,
                                  onReactionTap: _addReaction,
                                  edited: msg['edited'] == true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomArea() {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final hasPanel =
        _replyToMessageId != null ||
        _isEditing ||
        _isRecording ||
        _showVoiceConfirm;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.bgGradientBot.withOpacity(0.95),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPanel)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyToMessageId != null) _buildReplyPreview(),
                  if (_isEditing) _buildEditingHeader(),
                  if (_isRecording) _buildActiveRecordingPanel(),
                  if (_showVoiceConfirm) _buildVoiceConfirmPanel(),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 6, 10, 8 + safeBottom),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLeftAnimatedButton(),
                const SizedBox(width: 6),
                Expanded(child: _buildTextFieldWithIcons()),
                const SizedBox(width: 6),
                _buildRightAnimatedButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRecordingPanel() {
    String _fmt(int s) =>
        '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Colors.red, size: 12),
          const SizedBox(width: 10),
          const Text(
            'Запис...',
            style: TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _fmt(_recordedDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const Text(
            'Відпустіть для надсилання',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceConfirmPanel() {
    String _fmt(int s) =>
        '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.mainColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mainColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: AppColors.mainColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Голосове повідомлення',
                  style: TextStyle(
                    color: AppColors.mainColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _fmt(_recordedDuration),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelVoice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Видалити',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _confirmSendVoice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.mainColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Надіслати',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithIcons() {
    return GlassBox(
      borderRadius: 24,
      opacity: 0.15,
      blur: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              onChanged: (text) {
                if (text.isNotEmpty && socket.connected) {
                  socket.emit('typing', {
                    'username': myName,
                    'chatId': widget.chatId,
                  });
                }
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 5,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: "Повідомлення...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _hasText
                  ? _buildInlineIcon(
                      key: const ValueKey('plus'),
                      icon: Icons.add_circle_outline,
                      onTap: _pickAndUploadImage,
                      color: Colors.white54,
                    )
                  : Row(
                      key: const ValueKey('mic-video'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onLongPressStart: (_) => _onMicPressStart(),
                          onLongPressEnd: (_) => _onMicPressEnd(),
                          child: _buildInlineIconRaw(
                            icon: Icons.mic,
                            color: _isRecording ? Colors.red : Colors.white54,
                          ),
                        ),
                        _buildInlineIconRaw(
                          icon: Icons.videocam_outlined,
                          color: Colors.white38,
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Відео — незабаром!'),
                                  duration: Duration(seconds: 1),
                                ),
                              ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineIconRaw({
    required IconData icon,
    Color color = Colors.white54,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildInlineIcon({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white54,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildRightAnimatedButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: _hasText || _isEditing
          ? _buildCircleButton(
              key: const ValueKey('send'),
              icon: _isEditing ? Icons.check : Icons.arrow_upward,
              onPressed: sendMessage,
              color: AppColors.mainColor,
              size: 32,
            )
          : _buildCircleButton(
              key: const ValueKey('attach'),
              icon: Icons.attach_file,
              onPressed: _pickAndUploadImage,
              color: AppColors.mainColor,
              size: 32,
            ),
    );
  }

  Widget _buildLeftAnimatedButton() => const SizedBox.shrink();

  Widget _buildCircleButton({
    required Key key,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    double size = 36,
  }) {
    return Container(
      key: key,
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        iconSize: size * 0.55,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

// =======================
// 🔥 ReplyPreview Widget
// =======================
class ReplyPreview extends StatelessWidget {
  final Map? replyTo;
  final VoidCallback? onTap;
  final bool isMe;

  const ReplyPreview({super.key, this.replyTo, this.onTap, this.isMe = false});

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
                color: AppColors.white,
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
  final String? audioUrl;
  final int? audioDuration;
  final bool isMe;
  final dynamic timestamp;
  final String? avatarUrl;
  final bool isRead;
  final Map? replyTo;
  final Map<String, dynamic>? reactions;
  final String messageId;
  final String currentUsername;
  final Function(String messageId, String emoji)? onReactionTap;
  final bool edited;

  const MessageBubble({
    super.key,
    required this.text,
    required this.sender,
    required this.isMe,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    this.timestamp,
    this.avatarUrl,
    this.isRead = false,
    this.replyTo,
    this.reactions,
    required this.messageId,
    required this.currentUsername,
    this.onReactionTap,
    this.edited = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(timestamp);
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
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
                  if (replyTo != null)
                    ReplyPreview(replyTo: replyTo, isMe: isMe, onTap: () {}),
                  if (imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(imageUrl!, fit: BoxFit.cover),
                      ),
                    ),
                  if (audioUrl != null)
                    AudioMessagePlayer(
                      audioUrl: audioUrl!,
                      duration: audioDuration,
                      isMe: isMe,
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
                      if (edited) ...[
                        Text(
                          'ред.',
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
        if (reactions != null && reactions!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: -13, left: 8, right: 8),
            child: ReactionsDisplay(
              reactions: reactions,
              currentUsername: currentUsername,
              onReactionTap: (emoji) {
                if (onReactionTap != null) onReactionTap!(messageId, emoji);
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
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp).toLocal();
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

// =======================
// ❤️ REACTION PICKER & DISPLAY
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
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
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
          children: reactions
              .map(
                (emoji) => GestureDetector(
                  onTap: () => onReactionSelected(emoji),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

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
    if (reactions == null || reactions!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 0),
      child: Wrap(
        spacing: 2,
        runSpacing: 3,
        children: reactions!.entries.map((entry) {
          final emoji = entry.key;
          final users = List<String>.from(entry.value);
          // final hasMyReaction = users.contains(currentUsername); // Можна використати для підсвітки
          return GestureDetector(
            onTap: () => onReactionTap(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${users.length}',
                      style: const TextStyle(
                        fontSize: 11,
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
    // 🔥 ВИПРАВЛЕНО: Прибрали if (delta > 0), щоб можна було повертати назад
    setState(() {
      _dragExtent = (_dragExtent + delta).clamp(0.0, _kReplyThreshold * 1.5);
      _controller.value = (_dragExtent / _kReplyThreshold).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragUnderway) return;
    _dragUnderway = false;
    if (_dragExtent >= _kReplyThreshold) {
      Vibration.vibrate(duration: 50);
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
              builder: (context, child) => Container(
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
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: child,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

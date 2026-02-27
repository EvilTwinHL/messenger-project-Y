import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'services/socket_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'audio_player_widget.dart';
import 'home_screen.dart';
import 'signal_context_menu.dart';
import 'theme.dart';
import 'login_screen.dart'; // ← цей рядок вже є або додай
import 'widgets/message_bubble.dart';
import 'widgets/swipe_to_reply.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/date_separator.dart';
import 'widgets/reaction_widgets.dart';
import 'widgets/reply_preview.dart';
import 'utils/date_utils.dart' as AppDate;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

// Глобальний флаг доступності Firebase (false на Windows без firebase_options.dart)
//bool firebaseAvailable = false;

class AppColors {
  static const Color mainColor = SignalColors.primary;
  // Зворотна сумісність
  static const Color bgGradientTop = SignalColors.appBackground;
  static const Color bgGradientMid = SignalColors.appBackground;
  static const Color bgGradientBot = SignalColors.appBackground;
  static const Color bubbleMeStart = SignalColors.outgoing;
  static const Color bubbleMeEnd = SignalColors.outgoing;
  static const Color bubbleOther = Colors.white;
  static const Color white = Colors.white;
  static const Color whiteGlass = Colors.white10;
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🌙 Фонове повідомлення: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ Стало — з fallback:
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env не знайдено — AppConfig використає hardcode fallback
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  if (!kIsWeb && !Platform.isWindows) {
    // ⚠️ cloud_firestore не підтримує Windows нативно, тому пропускаємо Firebase на Windows.
    // На Windows месенджер використовує Socket.IO для отримання повідомлень.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (Platform.isAndroid || Platform.isIOS) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      }
      AppConfig.firebaseAvailable = true;
      print("✅ Firebase Init OK");
    } catch (e) {
      AppConfig.firebaseAvailable = false;
      print("❌ Firebase Init Error: $e");
      print(
        "💡 Запустіть: flutterfire configure --platforms=windows,android,ios",
      );
    }
  }

  final savedUsername = await AuthService.getSavedUsername();
  final savedDisplayName = await AuthService.getSavedDisplayName();
  final savedAvatar = await AuthService.getSavedAvatarUrl();

  Widget initialScreen;

  if (savedUsername != null) {
    // Вже залогінений — одразу на головний екран
    initialScreen = HomeScreen(
      myUsername: savedUsername,
      myDisplayName: savedDisplayName ?? savedUsername,
      myAvatarUrl: savedAvatar,
    );
  } else {
    // Не залогінений — перевіряємо чи є збережений телефон
    // Якщо є → шукаємо прив'язані акаунти на сервері
    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('phone');
    List<Map<String, dynamic>> suggestedAccounts = [];

    if (savedPhone != null && savedPhone.isNotEmpty) {
      try {
        final res = await http
            .get(
              Uri.parse(
                '\${AppConfig.serverUrl}/accounts_by_phone?phone=\${Uri.encodeComponent(savedPhone)}',
              ),
            )
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          suggestedAccounts = (jsonDecode(res.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {
        // Немає з'єднання — просто показуємо звичайний логін
      }
    }

    initialScreen = LoginScreen(suggestedAccounts: suggestedAccounts);
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(true),
      home: initialScreen,
    );
  }
}

// GlassBox замінено SolidBox — без BackdropFilter
class GlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur; // kept for API compat, ignored
  final double opacity; // kept for API compat, ignored
  final Border? border;

  const GlassBox({
    super.key,
    required this.child,
    this.borderRadius = 0,
    this.blur = 0,
    this.opacity = 0,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          color: SignalColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

// =======================
// 🔐 ЕКРАН ВХОДУ
// =======================

// delete dublicate login screen

// =======================
// 💬 ЕКРАН ЧАТУ (Оновлений на StreamBuilder)
// =======================
class ChatScreen extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final String chatId;
  final String
  otherUsername; // DM: username співрозмовника / Group: назва групи
  final bool isGroup;
  final String? groupName;
  final List<String>? groupParticipants;
  final List<String>? groupAdmins;

  const ChatScreen({
    super.key,
    required this.username,
    required this.chatId,
    required this.otherUsername,
    this.avatarUrl,
    this.isGroup = false,
    this.groupName,
    this.groupParticipants,
    this.groupAdmins,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController textController = TextEditingController();
  final _socketSvc = SocketService();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final _updater = ShorebirdUpdater();
  bool _isUpdateAvailable = false;

  late String myName;

  bool get _isAdmin =>
      widget.isGroup && (widget.groupAdmins ?? []).contains(myName);
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

  // Signal Context Menu — GlobalKeys per message
  final Map<String, GlobalKey> _messageKeys = {};

  // 🖥️ Локальний список повідомлень для Windows (де Firestore недоступний)
  // На Android/iOS використовується Firestore StreamBuilder
  final List<Map<String, dynamic>> _localMessages = [];
  final List<Map<String, dynamic>> _olderMessages = [];
  DocumentSnapshot? _lastDocument; // для Firebase пагінації
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  // Локальний кеш статусів — перекриває дані з Firestore/localMessages
  // Оновлюється через socket 'message_status_update' в реалтаймі
  final Map<String, String> _messageStatuses = {};

  @override
  void initState() {
    super.initState();
    myName = widget.username;
    initSocket();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Future.delayed(const Duration(seconds: 2), setupPushNotifications);
    }
    _checkShorebirdSilent();
    // Scroll listener для date overlay
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        _loadMoreMessages();
      }
    });
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

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    setState(() => _isLoadingMore = true);

    try {
      if (AppConfig.firebaseAvailable) {
        if (_lastDocument == null) return;
        final snap = await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .startAfterDocument(_lastDocument!)
            .limit(50)
            .get();

        if (snap.docs.isEmpty) {
          setState(() => _hasMoreMessages = false);
          return;
        }
        _lastDocument = snap.docs.last;
        final older = snap.docs.map((doc) {
          final d = doc.data();
          d['id'] = doc.id;
          return d;
        }).toList();
        setState(() => _olderMessages.addAll(older));
      } else {
        // Windows: просимо сервер
        if (_localMessages.isEmpty) return;
        final oldest = _localMessages.last['timestamp'];
        _socketSvc.socket.emit('request_history_more', {
          'chatId': widget.chatId,
          'before': oldest,
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // 🔄 _manualCheckForUpdate та _showUpdateDialog перенесено в SettingsScreen
  // Тут залишається лише тихий фоновий check (_checkShorebirdSilent)

  void _logToServer(String msg) {
    print("LOG: $msg");
    if (_socketSvc.isConnected)
      _socketSvc.socket.emit('debug_log', "User $myName: $msg");
  }

  Future<void> setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission();
      String? token = await messaging.getToken();
      if (token != null && _socketSvc.isConnected) {
        _socketSvc.registerToken(token, widget.username);
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("📱 Push received: ${message.notification?.title}");
      });
    } catch (e) {
      _logToServer("Push Error: $e");
    }
  }

  Future<void> initSocket() async {
    final token = await AuthService.getToken();
    _socketSvc.init(token: token ?? '');
    _socketSvc.connect();

    _socketSvc.onConnect((_) {
      print('✅ Connected to server');
      _socketSvc.joinChat(widget.chatId);
      if (!AppConfig.firebaseAvailable) {
        _socketSvc.requestHistory(widget.chatId);
      }
      // Позначаємо повідомлення від співрозмовника як прочитані
      _socketSvc.socket.emit('mark_read', {
        'chatId': widget.chatId,
        'readerUsername': myName,
      });
    });

    _socketSvc.on('receive_message', (data) {
      if (!mounted) return;
      final msg = Map<String, dynamic>.from(data as Map);
      // Одразу кешуємо статус нового повідомлення
      final newId = msg['id'] as String?;
      final newStatus = msg['status'] as String?;
      if (newId != null) {
        _messageStatuses[newId] = newStatus ?? 'sent';
      }

      // Якщо повідомлення від іншого — одразу mark_read
      // (чат відкритий, значить ми його вже "прочитали")
      final msgSender = msg['sender'] as String?;
      if (msgSender != null && msgSender != myName) {
        _socketSvc.socket.emit('mark_read', {
          'chatId': widget.chatId,
          'readerUsername': myName,
        });
      }

      if (!AppConfig.firebaseAvailable) {
        // Windows: додаємо повідомлення в локальний список
        setState(() => _localMessages.insert(0, msg));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // 🖥️ Завантаження історії для Windows
    _socketSvc.on('load_history', (data) {
      if (!AppConfig.firebaseAvailable && mounted) {
        final list = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _localMessages.clear();
          _localMessages.addAll(list.reversed);
          // Заповнюємо кеш статусів з історії
          for (final msg in list) {
            final id = msg['id'] as String?;
            final status = msg['status'] as String?;
            if (id != null && status != null) {
              _messageStatuses[id] = status;
            }
          }
        });
      }
    });

    _socketSvc.on('load_history_more', (data) {
      if (!AppConfig.firebaseAvailable && mounted) {
        final list = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (list.isEmpty) {
          setState(() => _hasMoreMessages = false);
          return;
        }
        setState(() => _localMessages.addAll(list.reversed));
      }
    });

    // 🖥️ Видалення повідомлення (Windows)
    _socketSvc.on('message_deleted', (messageId) {
      if (!AppConfig.firebaseAvailable && mounted) {
        setState(() => _localMessages.removeWhere((m) => m['id'] == messageId));
      }
    });

    // 🖥️ Редагування повідомлення (Windows)
    _socketSvc.on('message_edited', (data) {
      if (!AppConfig.firebaseAvailable && mounted) {
        final d = Map<String, dynamic>.from(data as Map);
        setState(() {
          final idx = _localMessages.indexWhere(
            (m) => m['id'] == d['messageId'],
          );
          if (idx != -1) {
            _localMessages[idx] = {
              ..._localMessages[idx],
              'text': d['newText'],
              'edited': true,
            };
          }
        });
      }
    });

    // 🖥️ Оновлення реакцій (Windows) — без цього реакції видно тільки після перезавантаження
    _socketSvc.on('reaction_updated', (data) {
      if (!AppConfig.firebaseAvailable && mounted) {
        final d = Map<String, dynamic>.from(data as Map);
        final msgId = d['messageId'] as String?;
        final reactions = d['reactions'];
        if (msgId == null) return;
        setState(() {
          final idx = _localMessages.indexWhere((m) => m['id'] == msgId);
          if (idx != -1) {
            _localMessages[idx] = {
              ..._localMessages[idx],
              'reactions': reactions != null
                  ? Map<String, dynamic>.from(reactions as Map)
                  : null,
            };
          }
        });
      }
    });

    // ✓✓ Оновлення статусу повідомлень (sent → delivered → read)
    _socketSvc.on('message_status_update', (data) {
      if (!mounted) return;
      final d = Map<String, dynamic>.from(data as Map);
      final msgId = d['messageId'] as String?;
      final newStatus = d['status'] as String?;
      if (msgId == null || newStatus == null) return;

      // Оновлюємо локальний кеш статусів для ОБОХ режимів (Firebase і Windows)
      // Це дає миттєве оновлення без очікування Firestore stream
      setState(() {
        _messageStatuses[msgId] = newStatus;
        // Windows: також оновлюємо в _localMessages
        if (!AppConfig.firebaseAvailable) {
          final idx = _localMessages.indexWhere((m) => m['id'] == msgId);
          if (idx != -1) {
            _localMessages[idx] = {..._localMessages[idx], 'status': newStatus};
          }
        }
      });
    });

    _socketSvc.on('display_typing', (data) {
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
      final token = await AuthService.getToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.serverUrl}/upload'),
      );
      request.headers['Authorization'] = 'Bearer ${token ?? ''}';
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

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SignalColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _attachOption(Icons.image, 'Фото', _pickAndUploadImage),
              _attachOption(Icons.picture_as_pdf, 'PDF', _pickAndUploadFile),
              _attachOption(Icons.description, 'Документ', _pickAndUploadFile),
              _attachOption(Icons.folder_zip, 'ZIP', _pickAndUploadFile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SignalColors.elevated,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SignalColors.primary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: SignalColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'zip', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final token = await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.serverUrl}/upload-file');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${token ?? ''}'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ),
      );

    final response = await request.send();
    if (response.statusCode != 200) return;

    final body = jsonDecode(await response.stream.bytesToString());
    final fileUrl = body['url'] as String;
    final fileName = body['fileName'] as String;
    final fileSize = body['fileSize'] as int;

    _socketSvc.socket.emit('send_message', {
      'chatId': widget.chatId,
      'text': '',
      'type': 'file',
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
    });
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

    if (_socketSvc.isConnected) {
      _socketSvc.editMessage(
        _editingMessageId!,
        newText,
        myName,
        widget.chatId,
      );
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
      final token = await AuthService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.serverUrl}/upload-audio'),
      );
      request.headers['Authorization'] = 'Bearer ${token ?? ''}';
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
    if (_socketSvc.isConnected) {
      _socketSvc.addReaction(messageId, emoji, myName, widget.chatId);
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

    if (_socketSvc.isConnected) {
      _socketSvc.sendMessage(messageData);
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
    final msgId = message['id'] as String? ?? '';
    final key = _messageKeys[msgId];

    if (key != null && key.currentContext != null) {
      final messageCopy = MessageBubble(
        text: message['type'] == 'image' || message['type'] == 'voice'
            ? ''
            : (message['text'] ?? ''),
        imageUrl: message['type'] == 'image' ? message['text'] : null,
        audioUrl: message['audioUrl'],
        audioDuration: message['audioDuration'],
        sender: message['sender'] ?? 'Anon',
        isMe: isMe,
        timestamp: message['timestamp'],
        status: _messageStatuses[msgId] ?? message['status'] as String?,
        replyTo: message['replyTo'],
        reactions: message['reactions'],
        messageId: msgId,
        currentUsername: myName,
        onReactionTap: _addReaction,
        edited: message['edited'] == true,
        fileUrl: message['fileUrl'] as String?, // ✅
        fileName: message['fileName'] as String?, // ✅
        fileSize: message['fileSize'] as int?, // ✅
      );

      SignalContextMenu.show(
        context,
        messageKey: key,
        messageChild: messageCopy,
        isMe: isMe,
        onReactionTap: (emoji) => _addReaction(msgId, emoji),
        onActionTap: (action) {
          switch (action) {
            case 'reply':
              _setReplyTo(message);
              break;
            case 'copy':
              Clipboard.setData(ClipboardData(text: message['text'] ?? ''));
              break;
            case 'edit':
              if (isMe) _startEditingMessage(message);
              break;
            case 'delete':
              // Адмін може видаляти будь-яке повідомлення в групі
              if (isMe || _isAdmin) _showDeleteConfirmDialog(msgId);
              break;
          }
        },
      );
      return;
    }

    // Fallback if key not ready
    final isText = message['type'] != 'image' && message['type'] != 'voice';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DefaultTextStyle(
        // ← Скидаємо успадкований TextDecoration.underline з теми
        style: const TextStyle(
          decoration: TextDecoration.none,
          color: Colors.white,
          fontFamily: 'Roboto',
        ),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
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
                      color: SignalColors.elevated,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['❤️', '👍', '👎', '😂', '😮', '😢']
                          .map(
                            (emoji) => GestureDetector(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                _addReaction(msgId, emoji);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    decoration: TextDecoration
                                        .none, // ← фікс жовтого підкреслення
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: SignalColors.elevated,
                      borderRadius: BorderRadius.circular(16),
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
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted) _setReplyTo(message);
                              },
                            );
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
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  if (mounted) _startEditingMessage(message);
                                },
                              );
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
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted && (isMe || _isAdmin))
                                  _showDeleteConfirmDialog(msgId);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ), // SafeArea
        ), // Material
      ), // DefaultTextStyle
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
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
        backgroundColor: SignalColors.elevated,
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
              if (_socketSvc.isConnected) {
                _socketSvc.deleteMessage(messageId, widget.chatId);
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

  // ───────────────────────────────────────────────────────────
  Color _avatarColor(String username) {
    const colors = [
      Color(0xFF1B6EC2),
      Color(0xFF1E8A44),
      Color(0xFF8B2FC9),
      Color(0xFFB5372B),
      Color(0xFF1A7B74),
      Color(0xFFB85C00),
      Color(0xFF4A4A8A),
      Color(0xFF6B3A2A),
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  // Scroll date overlay
  String? _scrollDateLabel;
  Timer? _scrollDateTimer;

  void _updateScrollDateLabel(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return;
    // reverse list = index 0 — найновіше. При скролі догори — показуємо дату
    final offset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;
    if (maxOffset <= 0) return;
    final ratio = (offset / maxOffset).clamp(0.0, 1.0);
    final idx = (ratio * (messages.length - 1)).round();
    final label = AppDate.ChatDateUtils.dateLabel(
      AppDate.ChatDateUtils.parseDate(messages[idx]["timestamp"]),
    );
    setState(() => _scrollDateLabel = label);
    _scrollDateTimer?.cancel();
    _scrollDateTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _scrollDateLabel = null);
    });
  }

  // ──────────────────────────────────────────────────────
  // 👥 ІНФО ГРУПИ (bottom sheet)
  // ──────────────────────────────────────────────────────
  void _showGroupInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SignalColors.elevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SignalColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Аватар і назва групи
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _avatarColor(widget.groupName ?? ''),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 10),
            Text(
              widget.groupName ?? '',
              style: const TextStyle(
                color: SignalColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${widget.groupParticipants?.length ?? 0} учасників',
              style: const TextStyle(
                color: SignalColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: SignalColors.divider, height: 1),
            // Список учасників
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: widget.groupParticipants?.length ?? 0,
                itemBuilder: (_, i) {
                  final uname = widget.groupParticipants![i];
                  final isMe = uname == myName;
                  final colors = SignalColors.avatarColorsFor(uname);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors[0],
                      child: Text(
                        uname[0].toUpperCase(),
                        style: TextStyle(
                          color: colors[1],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      isMe ? '$uname (ви)' : uname,
                      style: const TextStyle(color: SignalColors.textPrimary),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socketSvc.dispose();
    textController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _scrollDateTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: SignalColors.surface,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SignalColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: widget.isGroup ? _showGroupInfoSheet : null,
          child: Row(
            children: [
              // Аватар
              widget.isGroup
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _avatarColor(
                          widget.groupName ?? widget.otherUsername,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.group,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: _avatarColor(widget.otherUsername),
                      child: Text(
                        widget.otherUsername.isNotEmpty
                            ? widget.otherUsername[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isGroup
                        ? (widget.groupName ?? widget.otherUsername)
                        : widget.otherUsername,
                    style: const TextStyle(
                      fontSize: 16,
                      color: SignalColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  widget.isGroup
                      ? Text(
                          '${widget.groupParticipants?.length ?? 0} учасників',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SignalColors.textSecondary,
                          ),
                        )
                      : const Text(
                          'онлайн',
                          style: TextStyle(
                            fontSize: 12,
                            color: SignalColors.primary,
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // 📹 Відеодзвінок
          IconButton(
            icon: const Icon(
              Icons.videocam_outlined,
              color: SignalColors.textSecondary,
            ),
            tooltip: 'Відеодзвінок',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Відеодзвінки — незабаром 🎥'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          // 📞 Аудіодзвінок
          IconButton(
            icon: const Icon(
              Icons.call_outlined,
              color: SignalColors.textSecondary,
            ),
            tooltip: 'Аудіодзвінок',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Аудіодзвінки — незабаром 📞'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          // ⋮ Більше (три крапки)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: SignalColors.textSecondary,
            ),
            color: SignalColors.surface,
            onSelected: (v) {
              if (v == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupSettingsScreen(
                      chatId: widget.chatId,
                      groupName: widget.groupName ?? widget.otherUsername,
                      groupParticipants: List<String>.from(
                        widget.groupParticipants ?? [],
                      ),
                      groupAdmins: List<String>.from(widget.groupAdmins ?? []),
                      myUsername: myName,
                      myAvatarUrl: widget.avatarUrl,
                    ),
                  ),
                );
              } else if (v == 'search') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пошук по чату — незабаром')),
                );
              } else if (v == 'mute') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Сповіщення вимкнено')),
                );
              } else if (v == 'clear') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Очистити чат — незабаром')),
                );
              }
            },
            itemBuilder: (_) => [
              if (widget.isGroup)
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: SignalColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Налаштування групи',
                        style: TextStyle(color: SignalColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: SignalColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Пошук',
                      style: TextStyle(color: SignalColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      color: SignalColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Без звуку',
                      style: TextStyle(color: SignalColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: SignalColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Очистити чат',
                      style: TextStyle(color: SignalColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: SignalColors.appBackground,
        child: Stack(
          children: [
            Positioned.fill(
              child: StreamBuilder<QuerySnapshot>(
                stream: AppConfig.firebaseAvailable
                    ? FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .limit(50)
                          .snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  // 🖥️ Windows: показуємо повідомлення з локального списку (Socket.IO)
                  if (!AppConfig.firebaseAvailable) {
                    return _buildMessagesList(_localMessages);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isNotEmpty && _lastDocument == null) {
                    _lastDocument = docs.last;
                  }
                  final messages = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return data;
                  }).toList();

                  final combined = [...messages, ..._olderMessages];
                  return _buildMessagesList(combined);
                  ;
                },
              ),
            ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomArea()),
          ],
        ),
      ),
    );
  }

  // 💬 Будує список повідомлень — використовується і Firestore (мобільні),
  // і локальним Socket.IO списком (Windows).
  Widget _buildMessagesList(List<Map<String, dynamic>> messages) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          _updateScrollDateLabel(messages);
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.builder(
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
                (_isTyping && _typingUser != null ? 1 : 0) +
                (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              final hasTyping = _isTyping && _typingUser != null;

              if (hasTyping && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // DM — без аватара, тільки бульбашка
                  child: TypingIndicator(
                    username: _typingUser!,
                    isDM: !widget.isGroup,
                  ),
                );
              }

              if (_isLoadingMore &&
                  index == messages.length + (hasTyping ? 1 : 0)) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: SignalColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final msgIndex = hasTyping ? index - 1 : index;
              final msg = messages[msgIndex];
              final isMe = msg['sender'] == myName;
              // В груповому чаті показуємо ім'я відправника над бульбашкою
              final showSenderName = widget.isGroup && !isMe;

              bool showDateSeparator = false;
              if (msgIndex == messages.length - 1) {
                showDateSeparator = true;
              } else {
                final currentDate = AppDate.ChatDateUtils.parseDate(
                  msg['timestamp'],
                );
                final prevDate = AppDate.ChatDateUtils.parseDate(
                  messages[msgIndex + 1]['timestamp'],
                );
                showDateSeparator = !AppDate.ChatDateUtils.isSameDay(
                  currentDate,
                  prevDate,
                );
              }
              final dateLabel = AppDate.ChatDateUtils.dateLabel(
                AppDate.ChatDateUtils.parseDate(msg['timestamp']),
              );

              return Column(
                children: [
                  if (showDateSeparator) DateSeparator(date: dateLabel),
                  SwipeToReply(
                    onReply: () => _setReplyTo(msg),
                    replyIconColor: Colors.white,
                    child: Builder(
                      builder: (ctx) {
                        final msgId = msg['id'] as String? ?? '';
                        final key = _messageKeys.putIfAbsent(
                          msgId,
                          () => GlobalKey(),
                        );
                        return GestureDetector(
                          onLongPress: () => _showContextMenu(context, msg),
                          child: Container(
                            key: key,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ім'я відправника в груповому чаті
                                if (showSenderName)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 14,
                                      bottom: 2,
                                    ),
                                    child: Text(
                                      msg['sender'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: SignalColors.avatarColorsFor(
                                          msg['sender'] ?? '',
                                        )[0],
                                      ),
                                    ),
                                  ),
                                MessageBubble(
                                  text:
                                      msg['type'] == 'image' ||
                                          msg['type'] == 'voice' ||
                                          msg['type'] == 'file'
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
                                  status:
                                      _messageStatuses[msgId] ??
                                      msg['status'] as String?,
                                  replyTo: msg['replyTo'],
                                  reactions: msg['reactions'],
                                  messageId: msgId,
                                  currentUsername: myName,
                                  onReactionTap: _addReaction,
                                  edited: msg['edited'] == true,
                                  fileUrl: msg['fileUrl'] as String?,
                                  fileName: msg['fileName'] as String?,
                                  fileSize: msg['fileSize'] as int?,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          // ── Scroll Date Overlay ──────────────────────────────
          if (_scrollDateLabel != null)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _scrollDateLabel != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SignalColors.elevated.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _scrollDateLabel!,
                      style: const TextStyle(
                        color: SignalColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      color: SignalColors.surface,
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
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
      decoration: BoxDecoration(
        color: SignalColors.inputField,
        borderRadius: BorderRadius.circular(AppSizes.inputBorderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              onChanged: (text) {
                if (text.isNotEmpty && _socketSvc.isConnected) {
                  _socketSvc.emitTyping(myName, widget.chatId);
                }
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppSizes.inputFontSize,
              ),
              maxLines: 5,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Повідомлення...',
                hintStyle: TextStyle(
                  color: SignalColors.textSecondary,
                  fontSize: AppSizes.inputHintFontSize,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                isDense: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: _hasText
                  ? _buildInlineIcon(
                      key: const ValueKey('plus'),
                      icon: Icons.add_circle_outline,
                      onTap: _pickAndUploadImage,
                      color: SignalColors.textSecondary,
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
                            color: _isRecording
                                ? SignalColors.danger
                                : SignalColors.textSecondary,
                          ),
                        ),
                        _buildInlineIconRaw(
                          icon: Icons.videocam_outlined,
                          color: SignalColors.textSecondary,
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(icon, color: color, size: AppSizes.inlineIconSize),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(icon, color: color, size: AppSizes.inlineIconSize),
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
              color: SignalColors.primary,
            )
          : _buildCircleButton(
              key: const ValueKey('attach'),
              icon: Icons.attach_file,
              onPressed: _showAttachMenu,
              color: SignalColors.primary,
            ),
    );
  }

  Widget _buildLeftAnimatedButton() => const SizedBox.shrink();

  Widget _buildCircleButton({
    required Key key,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    double size = AppSizes.actionButtonSize,
  }) {
    return Container(
      key: key,
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        iconSize: AppSizes.actionIconSize,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ⚙️ НАЛАШТУВАННЯ ГРУПИ
// ══════════════════════════════════════════════════════════
class GroupSettingsScreen extends StatefulWidget {
  final String chatId;
  final String groupName;
  final List<String> groupParticipants;
  final List<String> groupAdmins;
  final String myUsername;
  final String? myAvatarUrl;

  const GroupSettingsScreen({
    super.key,
    required this.chatId,
    required this.groupName,
    required this.groupParticipants,
    required this.groupAdmins,
    required this.myUsername,
    this.myAvatarUrl,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late String _groupName;
  late List<String> _participants;
  late List<String> _admins;
  String? _groupAvatarUrl;
  bool _saving = false;

  bool get _isAdmin => _admins.contains(widget.myUsername);

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    _participants = List.from(widget.groupParticipants);
    _admins = List.from(widget.groupAdmins);
    // Завантажуємо актуальні дані з Firestore
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    if (!AppConfig.firebaseAvailable) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      setState(() {
        _groupName = (data['name'] as String?) ?? _groupName;
        _participants = List<String>.from(
          data['participants'] ?? _participants,
        );
        _admins = List<String>.from(data['admins'] ?? _admins);
        _groupAvatarUrl = data['avatarUrl'] as String?;
      });
    } catch (_) {}
  }

  // ── Змінити аватар групи ──────────────────────────────
  Future<void> _pickAndUploadGroupAvatar() async {
    if (!_isAdmin) return;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;
    setState(() => _saving = true);
    try {
      final token = await AuthService.getToken();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.serverUrl}/upload'),
      );
      req.headers['Authorization'] = 'Bearer ${token ?? ''}';
      req.files.add(await http.MultipartFile.fromPath('image', image.path));
      final resp = await req.send();
      if (resp.statusCode == 200) {
        final body = await resp.stream.bytesToString();
        final url = (jsonDecode(body) as Map)['url'] as String?;
        if (url != null) {
          await _serverUpdate({'avatarUrl': url});
          setState(() => _groupAvatarUrl = url);
        }
      }
    } catch (e) {
      _showSnack('Помилка: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Перейменувати групу ───────────────────────────────
  void _showRenameSheet() {
    if (!_isAdmin) return;
    final ctrl = TextEditingController(text: _groupName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SignalColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Назва групи',
              style: TextStyle(
                color: SignalColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: SignalColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Введіть назву...',
                hintStyle: const TextStyle(color: SignalColors.textSecondary),
                filled: true,
                fillColor: SignalColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: SignalColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  await _serverUpdate({'name': name});
                  setState(() => _groupName = name);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SignalColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Зберегти',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Додати учасника ──────────────────────────────────
  void _showAddMemberSheet() {
    if (!_isAdmin) return;
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SignalColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SignalColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Додати учасника',
                  style: TextStyle(
                    color: SignalColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: SignalColors.textPrimary),
                  onChanged: (q) async {
                    if (q.isEmpty) {
                      setS(() => results = []);
                      return;
                    }
                    setS(() => searching = true);
                    try {
                      final token = await AuthService.getToken();
                      final res = await http.get(
                        Uri.parse(
                          '${AppConfig.serverUrl}/search_users?q=${Uri.encodeComponent(q)}&myUsername=${widget.myUsername}',
                        ),
                        headers: {'Authorization': 'Bearer ${token ?? ''}'},
                      );
                      if (res.statusCode == 200) {
                        final all = (jsonDecode(res.body) as List)
                            .map((e) => Map<String, dynamic>.from(e as Map))
                            .where(
                              (u) => !_participants.contains(u['username']),
                            )
                            .toList();
                        setS(() => results = all);
                      }
                    } catch (_) {
                    } finally {
                      setS(() => searching = false);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Пошук...',
                    hintStyle: const TextStyle(
                      color: SignalColors.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: SignalColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: SignalColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: searching
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: SignalColors.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final u = results[i];
                          final uname = u['username'] as String;
                          final dname = (u['displayName'] as String?) ?? uname;
                          final colors = SignalColors.avatarColorsFor(uname);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colors[0],
                              child: Text(
                                dname[0].toUpperCase(),
                                style: TextStyle(
                                  color: colors[1],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              dname,
                              style: const TextStyle(
                                color: SignalColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '@$uname',
                              style: const TextStyle(
                                color: SignalColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.person_add_outlined,
                              color: SignalColors.primary,
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _addMember(uname);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMember(String username) async {
    setState(() => _saving = true);
    try {
      final token = await AuthService.getToken();
      final res = await http.post(
        Uri.parse('${AppConfig.serverUrl}/group_add_member'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: jsonEncode({'chatId': widget.chatId, 'newMember': username}),
      );
      if (res.statusCode == 200) {
        setState(() => _participants.add(username));
        _showSnack('$username доданий до групи');
      } else {
        _showSnack('Помилка: ${jsonDecode(res.body)['error']}');
      }
    } catch (e) {
      _showSnack('Помилка: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Видалити учасника ─────────────────────────────────
  Future<void> _removeMember(String username) async {
    final isSelf = username == widget.myUsername;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SignalColors.elevated,
        title: Text(
          isSelf ? 'Вийти з групи?' : 'Видалити $username?',
          style: const TextStyle(color: SignalColors.textPrimary),
        ),
        content: Text(
          isSelf
              ? 'Ви більше не матимете доступу до цього чату.'
              : 'Учасник буде видалений з групи.',
          style: const TextStyle(color: SignalColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isSelf ? 'Вийти' : 'Видалити',
              style: const TextStyle(color: SignalColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final token = await AuthService.getToken();
      final res = await http.post(
        Uri.parse('${AppConfig.serverUrl}/group_remove_member'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: jsonEncode({'chatId': widget.chatId, 'member': username}),
      );
      if (res.statusCode == 200) {
        if (isSelf) {
          // Виходимо з усіх екранів групи
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          setState(() {
            _participants.remove(username);
            _admins.remove(username);
          });
          _showSnack('$username видалений');
        }
      } else {
        _showSnack('Помилка: ${jsonDecode(res.body)['error']}');
      }
    } catch (e) {
      _showSnack('Помилка: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Призначити / зняти адміна ─────────────────────────
  Future<void> _toggleAdmin(String username) async {
    if (!_isAdmin || username == widget.myUsername) return;
    final isCurrentAdmin = _admins.contains(username);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SignalColors.elevated,
        title: Text(
          isCurrentAdmin ? 'Зняти права адміна?' : 'Призначити адміном?',
          style: const TextStyle(color: SignalColors.textPrimary),
        ),
        content: Text(
          isCurrentAdmin
              ? '$username більше не буде адміністратором групи.'
              : '$username зможе додавати/видаляти учасників та редагувати групу.',
          style: const TextStyle(color: SignalColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SignalColors.primary,
            ),
            child: Text(
              isCurrentAdmin ? 'Зняти' : 'Призначити',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Оновлюємо Firestore напряму (через окремий ендпоінт або update_profile)
    setState(() => _saving = true);
    try {
      if (!AppConfig.firebaseAvailable) return;
      final newAdmins = List<String>.from(_admins);
      if (isCurrentAdmin) {
        newAdmins.remove(username);
      } else {
        newAdmins.add(username);
      }
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'admins': newAdmins});
      setState(() => _admins = newAdmins);
      _showSnack(
        isCurrentAdmin ? 'Права адміна знято' : '$username тепер адміністратор',
      );
    } catch (e) {
      _showSnack('Помилка: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _serverUpdate(Map<String, dynamic> fields) async {
    try {
      final token = await AuthService.getToken();
      await http.post(
        Uri.parse('${AppConfig.serverUrl}/group_update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: jsonEncode({'chatId': widget.chatId, ...fields}),
      );
    } catch (_) {}
  }

  void _showSnack(String msg) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignalColors.appBackground,
      appBar: AppBar(
        backgroundColor: SignalColors.surface,
        elevation: 0,
        leadingWidth: 90,
        leading: TextButton.icon(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: SignalColors.primary,
            size: 16,
          ),
          label: const Text(
            'Назад',
            style: TextStyle(color: SignalColors.primary, fontSize: 15),
          ),
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
        ),
        title: const Text(
          'Налаштування групи',
          style: TextStyle(
            color: SignalColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SignalColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          // ── Аватар + назва ──────────────────────────────
          Container(
            color: SignalColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
            child: Column(
              children: [
                // Аватар групи
                GestureDetector(
                  onTap: _isAdmin ? _pickAndUploadGroupAvatar : null,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: SignalColors.avatarColorsFor(
                          _groupName,
                        )[0],
                        backgroundImage: _groupAvatarUrl != null
                            ? NetworkImage(_groupAvatarUrl!)
                            : null,
                        child: _groupAvatarUrl == null
                            ? const Icon(
                                Icons.group,
                                color: Colors.white,
                                size: 42,
                              )
                            : null,
                      ),
                      if (_isAdmin)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: SignalColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: SignalColors.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Назва групи
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _groupName,
                        style: const TextStyle(
                          color: SignalColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showRenameSheet,
                        child: const Icon(
                          Icons.edit_outlined,
                          color: SignalColors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_participants.length} учасників',
                  style: const TextStyle(
                    color: SignalColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Кнопки дій (тільки для адмінів) ───────────
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _actionBtn(
                    icon: Icons.camera_alt_outlined,
                    label: 'Фото',
                    onTap: _pickAndUploadGroupAvatar,
                  ),
                  const SizedBox(width: 10),
                  _actionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Назва',
                    onTap: _showRenameSheet,
                  ),
                  const SizedBox(width: 10),
                  _actionBtn(
                    icon: Icons.person_add_outlined,
                    label: 'Додати',
                    onTap: _showAddMemberSheet,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ── Список учасників ───────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: SignalColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'УЧАСНИКИ',
                    style: TextStyle(
                      color: SignalColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ..._participants.asMap().entries.map((entry) {
                  final i = entry.key;
                  final uname = entry.value;
                  final isMe = uname == widget.myUsername;
                  final isThisAdmin = _admins.contains(uname);
                  final colors = SignalColors.avatarColorsFor(uname);

                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(
                          color: SignalColors.divider,
                          height: 1,
                          indent: 56,
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colors[0],
                          child: Text(
                            uname[0].toUpperCase(),
                            style: TextStyle(
                              color: colors[1],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              isMe ? '$uname (ви)' : uname,
                              style: const TextStyle(
                                color: SignalColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            if (isThisAdmin) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.workspace_premium,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          isThisAdmin ? 'адміністратор' : 'учасник',
                          style: TextStyle(
                            color: isThisAdmin
                                ? Colors.amber.withOpacity(0.8)
                                : SignalColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        // Дії для адміна (крім себе)
                        trailing: _isAdmin && !isMe
                            ? PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: SignalColors.textSecondary,
                                  size: 20,
                                ),
                                color: SignalColors.elevated,
                                onSelected: (v) {
                                  if (v == 'admin') _toggleAdmin(uname);
                                  if (v == 'remove') _removeMember(uname);
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'admin',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isThisAdmin
                                              ? Icons.remove_moderator_outlined
                                              : Icons.workspace_premium,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          isThisAdmin
                                              ? 'Зняти права адміна'
                                              : 'Призначити адміном',
                                          style: const TextStyle(
                                            color: SignalColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.person_remove_outlined,
                                          color: SignalColors.danger,
                                          size: 18,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Видалити з групи',
                                          style: TextStyle(
                                            color: SignalColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Небезпечна зона ────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: SignalColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.exit_to_app,
                color: SignalColors.danger,
              ),
              title: const Text(
                'Вийти з групи',
                style: TextStyle(color: SignalColors.danger),
              ),
              onTap: () => _removeMember(widget.myUsername),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: SignalColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: SignalColors.primary, size: 22),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: SignalColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

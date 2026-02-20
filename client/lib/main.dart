import 'dart:convert';
import 'dart:io';
import 'dart:async';
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

const String serverUrl = 'https://pproject-y.onrender.com';

// Глобальний флаг доступності Firebase (false на Windows без firebase_options.dart)
bool firebaseAvailable = false;

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
      firebaseAvailable = true;
      print("✅ Firebase Init OK");
    } catch (e) {
      firebaseAvailable = false;
      print("❌ Firebase Init Error: $e");
      print(
        "💡 Запустіть: flutterfire configure --platforms=windows,android,ios",
      );
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

  // Signal Context Menu — GlobalKeys per message
  final Map<String, GlobalKey> _messageKeys = {};

  // 🖥️ Локальний список повідомлень для Windows (де Firestore недоступний)
  // На Android/iOS використовується Firestore StreamBuilder
  final List<Map<String, dynamic>> _localMessages = [];

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
      // Викличеться з buildMessagesList через захоплений messages список
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

  // 🔄 _manualCheckForUpdate та _showUpdateDialog перенесено в SettingsScreen
  // Тут залишається лише тихий фоновий check (_checkShorebirdSilent)

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
      // 🖥️ Для Windows завантажуємо історію через Socket.IO (Firestore недоступний)
      if (!firebaseAvailable) {
        socket.emit('request_history', widget.chatId);
      }
    });

    // 🖥️ Отримання повідомлень через Socket.IO (головним чином для Windows)
    // На Android/iOS Firestore StreamBuilder оновлюється автоматично.
    // Але слухаємо і на мобільних — як fallback для моментального відображення.
    socket.on('receive_message', (data) {
      if (!mounted) return;
      final msg = Map<String, dynamic>.from(data as Map);

      if (!firebaseAvailable) {
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
    socket.on('load_history', (data) {
      if (!firebaseAvailable && mounted) {
        final list = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _localMessages.clear();
          // Реверс: ListView reverse:true, тому новіші першими (index 0)
          _localMessages.addAll(list.reversed);
        });
      }
    });

    // 🖥️ Видалення повідомлення (Windows)
    socket.on('message_deleted', (messageId) {
      if (!firebaseAvailable && mounted) {
        setState(() => _localMessages.removeWhere((m) => m['id'] == messageId));
      }
    });

    // 🖥️ Редагування повідомлення (Windows)
    socket.on('message_edited', (data) {
      if (!firebaseAvailable && mounted) {
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
    socket.on('reaction_updated', (data) {
      if (!firebaseAvailable && mounted) {
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
        isRead: message['read'] == true,
        replyTo: message['replyTo'],
        reactions: message['reactions'],
        messageId: msgId,
        currentUsername: myName,
        onReactionTap: _addReaction,
        edited: message['edited'] == true,
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
              _showDeleteConfirmDialog(msgId);
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
                            // Future.delayed надійніше за addPostFrameCallback після анімації закриття
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted) _showDeleteConfirmDialog(msgId);
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

  // ───────────────────────────────────────────────────────────
  // 🎨 Колір аватара з нікнейму (як у Signal)
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
    final label = _getDateLabel(_parseDate(messages[idx]["timestamp"]));
    setState(() => _scrollDateLabel = label);
    _scrollDateTimer?.cancel();
    _scrollDateTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _scrollDateLabel = null);
    });
  }

  @override
  void dispose() {
    socket.dispose();
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
        title: Row(
          children: [
            // Аватар співрозмовника
            CircleAvatar(
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
                  widget.otherUsername,
                  style: const TextStyle(
                    fontSize: 16,
                    color: SignalColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Онлайн-статус (заглушка, буде real-time у Фазі 2)
                const Text(
                  'онлайн',
                  style: TextStyle(fontSize: 12, color: SignalColors.primary),
                ),
              ],
            ),
          ],
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
              if (v == 'search') {
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
                stream: firebaseAvailable
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
                  if (!firebaseAvailable) {
                    return _buildMessagesList(_localMessages);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  final messages = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return data;
                  }).toList();

                  return _buildMessagesList(messages);
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
                messages.length + (_isTyping && _typingUser != null ? 1 : 0),
            itemBuilder: (context, index) {
              final hasTyping = _isTyping && _typingUser != null;

              if (hasTyping && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // DM — без аватара, тільки бульбашка
                  child: TypingIndicator(username: _typingUser!, isDM: true),
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
              final dateLabel = _getDateLabel(_parseDate(msg['timestamp']));

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
                              messageId: msgId,
                              currentUsername: myName,
                              onReactionTap: _addReaction,
                              edited: msg['edited'] == true,
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
              top: 80,
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
                if (text.isNotEmpty && socket.connected) {
                  socket.emit('typing', {
                    'username': myName,
                    'chatId': widget.chatId,
                  });
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
              onPressed: _pickAndUploadImage,
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
              maxWidth:
                  MediaQuery.of(context).size.width *
                  AppSizes.bubbleMaxWidthRatio,
            ),
            decoration: BoxDecoration(
              color: isMe ? SignalColors.outgoing : SignalColors.incoming,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppSizes.bubbleRadius),
                topRight: const Radius.circular(AppSizes.bubbleRadius),
                bottomLeft: isMe
                    ? const Radius.circular(AppSizes.bubbleRadius)
                    : const Radius.circular(4),
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(AppSizes.bubbleRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.bubblePadding),
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
                        fontSize: AppSizes.bubbleFontSize,
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
                            fontSize: AppSizes.bubbleTimeFontSize,
                            color: Colors.white.withOpacity(0.4),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: AppSizes.bubbleTimeFontSize,
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
          Transform.translate(
            offset: const Offset(0, -10),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: ReactionsDisplay(
                reactions: reactions,
                currentUsername: currentUsername,
                onReactionTap: (emoji) {
                  if (onReactionTap != null) onReactionTap!(messageId, emoji);
                },
              ),
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
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 24,
                        decoration: TextDecoration.none,
                      ),
                    ),
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
                  Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (users.length > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${users.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
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

// =======================
// 🗓️ DATE SEPARATOR (Added)
// =======================
class DateSeparator extends StatelessWidget {
  final String date;
  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: SignalColors.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            date,
            style: const TextStyle(
              color: SignalColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// =======================
// ⌨️ TYPING INDICATOR (Added)
// =======================
// ═══════════════════════════════════════════════════════════════
// ⌨️ TYPING INDICATOR  (збільшений, без аватара для DM)
// ═══════════════════════════════════════════════════════════════
class TypingIndicator extends StatefulWidget {
  final String username;

  /// isDM: true — приватний чат (аватар прибрано).
  /// false — груповий чат (аватар відображається).
  final bool isDM;
  const TypingIndicator({super.key, required this.username, this.isDM = true});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  // Три анімації з зміщенням фаз
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dot1 = _staggeredAnim(0.0, 0.33);
    _dot2 = _staggeredAnim(0.2, 0.53);
    _dot3 = _staggeredAnim(0.4, 0.73);
  }

  Animation<double> _staggeredAnim(double begin, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween(0.3), weight: 20),
    ]).animate(
      CurvedAnimation(
        parent: _dotController,
        curve: Interval(begin, end, curve: Curves.linear),
      ),
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Аватар — тільки для групових чатів
          if (!widget.isDM) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.mainColor,
              child: Text(
                widget.username.isNotEmpty
                    ? widget.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Бульбашка з точками
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: SignalColors.incoming,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(_dot1),
                const SizedBox(width: 5),
                _buildDot(_dot2),
                const SizedBox(width: 5),
                _buildDot(_dot3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, -4 * (anim.value - 0.3)),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

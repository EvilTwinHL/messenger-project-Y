# build_windows_final.ps1
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Windows Build (повна заміна)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Крок 1: Backup файлів
Write-Host "[1/6] Створення backup файлів..." -ForegroundColor Yellow
Copy-Item pubspec.yaml pubspec.yaml.backup -Force
Copy-Item lib\main.dart lib\main.dart.backup -Force

# Крок 2: Створення main.dart без Firebase
Write-Host "[2/6] Створення main.dart без Firebase..." -ForegroundColor Yellow

$mainContent = @'
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shorebird_code_push/shorebird_code_push.dart';

const String serverUrl = 'https://pproject-y.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("ℹ️ Windows Build - Firebase вимкнено");
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
  List<Map<String, dynamic>> messages = [];
  final TextEditingController textController = TextEditingController();
  late IO.Socket socket;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final String myName = 'Мій PC';

  final _updater = ShorebirdUpdater();
  bool _isCheckingForUpdate = false;

  @override
  void initState() {
    super.initState();
    initSocket();

    _updater.readCurrentPatch().then((currentPatch) {
      print('Поточний номер патчу: ${currentPatch?.number ?? "Немає (База)"}');
    });
  }

  Future<void> _checkForUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Авто-оновлення працює тільки на Android"),
      ),
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
      print('✅ Підключено до сервера');
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Завантаження фото..."))
    );

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$serverUrl/upload'));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Помилка: $e"))
      );
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
          IconButton(
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
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
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
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        isImage
                            ? SizedBox(
                                width: 200,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    content.startsWith('http') ? content : '$serverUrl/$content',
                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                  ),
                                ),
                              )
                            : Text(content, style: const TextStyle(fontSize: 16)),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
'@

Set-Content lib\main.dart $mainContent -Encoding UTF8
Write-Host "  ✅ main.dart без Firebase створено" -ForegroundColor Green

# Крок 3: Видалення Firebase з pubspec.yaml
Write-Host "[3/6] Видалення Firebase з pubspec.yaml..." -ForegroundColor Yellow
$content = Get-Content pubspec.yaml
$newContent = $content | Where-Object { 
    $_ -notmatch "firebase_core" -and 
    $_ -notmatch "firebase_messaging" 
}
$newContent | Set-Content pubspec.yaml
Write-Host "  ✅ Firebase видалено з pubspec.yaml" -ForegroundColor Green

# Крок 4: Очистка і отримання залежностей
Write-Host "[4/6] Очищення і отримання залежностей..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Крок 5: Збірка
Write-Host "[5/6] Збірка Windows додатку..." -ForegroundColor Yellow
Write-Host ""

flutter pub run msix:create

$buildSuccess = $LASTEXITCODE -eq 0

# Крок 6: Відновлення файлів
Write-Host ""
Write-Host "[6/6] Відновлення оригінальних файлів..." -ForegroundColor Yellow
Copy-Item pubspec.yaml.backup pubspec.yaml -Force
Copy-Item lib\main.dart.backup lib\main.dart -Force
Remove-Item pubspec.yaml.backup
Remove-Item lib\main.dart.backup
flutter pub get > $null 2>&1

Write-Host "  ✅ Файли відновлено" -ForegroundColor Green

# Результат
Write-Host ""
if ($buildSuccess) {
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "  ✅ ЗБІРКА УСПІШНА!" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Виконувані файли:" -ForegroundColor Cyan
    Write-Host "build\windows\x64\runner\Release\my_messenger_app.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "Запустити:" -ForegroundColor Cyan
    Write-Host ".\build\windows\x64\runner\Release\my_messenger_app.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Оригінальні файли з Firebase відновлено для Android/iOS" -ForegroundColor Yellow
} else {
    Write-Host "=====================================" -ForegroundColor Red
    Write-Host "  ❌ ЗБІРКА НЕ ВДАЛАСЯ" -ForegroundColor Red
    Write-Host "=====================================" -ForegroundColor Red
}
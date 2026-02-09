import 'dart:convert';
import 'dart:io'; // Додано для визначення Windows/Android
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// --- НАЛАШТУВАННЯ ---
// Впишіть сюди IP вашого ноутбука (з команди ipconfig)!
const String serverUrl =
    'https://josphine-separatory-zoie.ngrok-free.dev'; // <--- ЗМІНІТЬ ЦЕ НА ВАШУ IP
//const int serverPort = 3000;
//const String serverUrl = 'http://$serverIp:$serverPort';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Прибираємо стрічку "Debug"
      title: 'Мій Крос-Месенджер',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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

  // Визначаємо ім'я цього пристрою при старті
  // Якщо це Android - буде "Мій Телефон", якщо Windows - "Мій PC"
  final String myName = Platform.isAndroid ? 'Мій Телефон' : 'Мій PC';

  @override
  void initState() {
    super.initState();
    initSocket();
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

    socket.onConnect((_) => print('✅ Підключено до сервера як $myName'));

    socket.on('load_history', (data) {
      if (data != null) {
        setState(() {
          messages.clear();
          for (var msg in data) {
            messages.add({
              'text': msg['text'],
              'sender': msg['sender'],
              'type': msg['type'] ?? 'text',
            });
          }
        });
        _scrollToBottom();
      }
    });

    socket.on('receive_message', (data) {
      setState(() {
        messages.add({
          'text': data['text'],
          'sender': data['sender'],
          'type': data['type'] ?? 'text',
        });
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

    print("📸 Фото обрано: ${image.path}");

    var request = http.MultipartRequest('POST', Uri.parse('$serverUrl/upload'));
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        String imageUrl = json['url'];

        // Відправляємо повідомлення з типом image
        socket.emit('send_message', {
          'text': imageUrl,
          'sender': myName, // Використовуємо авто-ім'я
          'type': 'image',
        });
      }
    } catch (e) {
      print("❌ Помилка завантаження: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Помилка з'єднання з сервером: $e")),
      );
    }
  }

  void sendMessage() {
    String text = textController.text.trim();
    if (text.isNotEmpty) {
      socket.emit('send_message', {
        'text': text,
        'sender': myName, // Використовуємо авто-ім'я
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
        title: Text("Чат ($myName)"), // У заголовку буде видно, хто ви
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                // Перевіряємо: чи я відправив це повідомлення?
                final isMe = msg['sender'] == myName;
                final isImage = msg['type'] == 'image';

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
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: isMe
                            ? const Radius.circular(15)
                            : Radius.zero,
                        bottomRight: isMe
                            ? Radius.zero
                            : const Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isMe ? Colors.blue[800] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 5),

                        isImage
                            ? SizedBox(
                                width: 200,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    '$serverUrl/${msg['text']}',
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            height: 100,
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Column(
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            color: Colors.red,
                                          ),
                                          Text(
                                            "Помилка фото",
                                            style: TextStyle(fontSize: 10),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              )
                            : Text(
                                msg['text'],
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
                    onSubmitted: (_) => sendMessage(), // Відправка по Enter
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

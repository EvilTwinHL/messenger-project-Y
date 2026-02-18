import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_screen.dart';
import 'main.dart'; // Для ChatScreen та AppColors

class HomeScreen extends StatefulWidget {
  final String myUsername;
  final String? myAvatarUrl;

  const HomeScreen({super.key, required this.myUsername, this.myAvatarUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // 🔥 ВИПРАВЛЕНО: Приймає dynamic, щоб обробляти і String, і Timestamp
  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime date;

    try {
      if (timestamp is Timestamp) {
        // Якщо це формат Firestore
        date = timestamp.toDate();
      } else if (timestamp is String) {
        // Якщо це текстовий рядок (від Node.js)
        date = DateTime.parse(timestamp).toLocal();
      } else if (timestamp is int) {
        // Якщо це мілісекунди
        date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }

    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Повідомлення",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.mainColor,
        child: const Icon(Icons.edit, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SearchUserScreen(myUsername: widget.myUsername),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 Слухаємо колекцію chats
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: widget.myUsername)
            .orderBy('lastMessage.timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Обробка помилок
          if (snapshot.hasError) {
            // Якщо помилка індексу - показуємо інструкцію
            if (snapshot.error.toString().contains("index") ||
                snapshot.error.toString().contains("FAILED_PRECONDITION")) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🔥 ВИПРАВЛЕНО іконку
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Потрібен індекс Firestore!",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Відкрийте Debug Console на комп'ютері та натисніть на посилання для створення індексу.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: Text(
                "Помилка: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 60,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Немає чатів",
                    style: TextStyle(color: Colors.white54),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SearchUserScreen(myUsername: widget.myUsername),
                        ),
                      );
                    },
                    child: const Text("Почати спілкування"),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              // 🔥 Обгортаємо в try-catch, щоб один битий чат не ламав весь список
              try {
                final chat = chats[index].data() as Map<String, dynamic>;
                final chatId = chats[index].id;

                final List participants = chat['participants'] ?? [];
                String otherUser = "Unknown";
                if (participants.isNotEmpty) {
                  otherUser = participants.firstWhere(
                    (u) => u != widget.myUsername,
                    orElse: () => "Unknown",
                  );
                }

                final lastMsg = chat['lastMessage'] ?? {};
                final lastMsgText = lastMsg['text'] ?? '';
                // 🔥 Беремо як dynamic, щоб не було TypeError
                final dynamic lastMsgTime = lastMsg['timestamp'];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.mainColor,
                    child: Text(
                      otherUser.isNotEmpty ? otherUser[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  title: Text(
                    otherUser,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    lastMsgText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Text(
                    _formatTime(lastMsgTime), // 🔥 Тепер ця функція безпечна
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          username: widget.myUsername,
                          chatId: chatId,
                          otherUsername: otherUser,
                          avatarUrl: widget.myAvatarUrl,
                        ),
                      ),
                    );
                  },
                );
              } catch (e) {
                print("Error displaying chat item: $e");
                return const SizedBox.shrink();
              }
            },
          );
        },
      ),
    );
  }
}

// NEW FUNCTION 19.06.2026

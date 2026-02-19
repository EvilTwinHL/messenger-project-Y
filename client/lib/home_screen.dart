import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'main.dart'; // Для ChatScreen та AppColors

class HomeScreen extends StatefulWidget {
  final String myUsername;
  final String? myAvatarUrl;

  const HomeScreen({super.key, required this.myUsername, this.myAvatarUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 🖥️ Для Windows (де Firestore недоступний) — завантажуємо чати через HTTP
  List<Map<String, dynamic>> _windowsChats = [];
  bool _windowsChatsLoading = false;

  @override
  void initState() {
    super.initState();
    if (!firebaseAvailable) {
      _loadWindowsChats();
    }
  }

  // 🖥️ Завантажуємо список чатів через REST API (для Windows)
  Future<void> _loadWindowsChats() async {
    setState(() => _windowsChatsLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/get_user_chats?username=${widget.myUsername}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _windowsChats = data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (e) {
      print('Помилка завантаження чатів (Windows): $e');
    } finally {
      setState(() => _windowsChatsLoading = false);
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    try {
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp).toLocal();
      } else if (timestamp is int) {
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
      // ── DRAWER ──────────────────────────────────────────────────────
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1b1e28), Color(0xFF2a2d3a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.mainColor,
                      backgroundImage: widget.myAvatarUrl != null
                          ? NetworkImage(widget.myAvatarUrl!)
                          : null,
                      child: widget.myAvatarUrl == null
                          ? Text(
                              widget.myUsername.isNotEmpty
                                  ? widget.myUsername[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.myUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // New Chat
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white70),
                title: const Text(
                  'Новий чат',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchUserScreen(myUsername: widget.myUsername),
                    ),
                  );
                },
              ),
              // Settings
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white70),
                title: const Text(
                  'Налаштування',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const Divider(color: Colors.white12),
              const Spacer(),
              // Logout
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                title: const Text(
                  'Вийти',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Повідомлення",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        // Drawer burger icon is auto-added by Scaffold
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchUserScreen(myUsername: widget.myUsername),
              ),
            ),
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
      body: firebaseAvailable
          ? _buildFirestoreChatList()
          : _buildWindowsChatList(),
    );
  }

  // 📱 Android/iOS: список чатів через Firestore (real-time)
  Widget _buildFirestoreChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.myUsername)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains("index") ||
              snapshot.error.toString().contains("FAILED_PRECONDITION")) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      "Відкрийте Debug Console та натисніть на посилання для створення індексу.",
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
          return _buildEmptyChatsView();
        }

        final chats = snapshot.data!.docs;
        final sortedChats = [...chats]
          ..sort((a, b) {
            try {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTs =
                  (aData['lastMessage'] as Map<String, dynamic>?)?['timestamp'];
              final bTs =
                  (bData['lastMessage'] as Map<String, dynamic>?)?['timestamp'];
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              // timestamp може бути Firestore Timestamp АБО ISO рядком (якщо збережено сервером)
              int aTime = 0, bTime = 0;
              if (aTs is Timestamp) {
                aTime = aTs.millisecondsSinceEpoch;
              } else if (aTs is String) {
                aTime = DateTime.tryParse(aTs)?.millisecondsSinceEpoch ?? 0;
              }
              if (bTs is Timestamp) {
                bTime = bTs.millisecondsSinceEpoch;
              } else if (bTs is String) {
                bTime = DateTime.tryParse(bTs)?.millisecondsSinceEpoch ?? 0;
              }
              return bTime.compareTo(aTime);
            } catch (_) {
              return 0;
            }
          });

        return ListView.builder(
          itemCount: sortedChats.length,
          itemBuilder: (context, index) {
            try {
              final chat = sortedChats[index].data() as Map<String, dynamic>;
              final chatId = sortedChats[index].id;
              final List participants = chat['participants'] ?? [];
              String otherUser = participants.firstWhere(
                (u) => u != widget.myUsername,
                orElse: () => "Користувач",
              );
              final lastMsg = chat['lastMessage'] ?? {};
              final lastMsgText = lastMsg['text'] ?? '';
              final dynamic lastMsgTime = lastMsg['timestamp'];
              return _buildChatTile(
                chatId,
                otherUser,
                lastMsgText,
                lastMsgTime,
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  // 🖥️ Windows: список чатів через HTTP API
  Widget _buildWindowsChatList() {
    if (_windowsChatsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_windowsChats.isEmpty) {
      return _buildEmptyChatsView();
    }
    return RefreshIndicator(
      onRefresh: _loadWindowsChats,
      child: ListView.builder(
        itemCount: _windowsChats.length,
        itemBuilder: (context, index) {
          final chat = _windowsChats[index];
          final chatId = chat['id'] as String? ?? '';
          final List participants = (chat['participants'] as List?) ?? [];
          String otherUser = participants.firstWhere(
            (u) => u != widget.myUsername,
            orElse: () => "Користувач",
          );
          final lastMsg = chat['lastMessage'] ?? {};
          final lastMsgText = (lastMsg is Map) ? (lastMsg['text'] ?? '') : '';
          final dynamic lastMsgTime = (lastMsg is Map)
              ? lastMsg['timestamp']
              : null;
          return _buildChatTile(chatId, otherUser, lastMsgText, lastMsgTime);
        },
      ),
    );
  }

  Widget _buildEmptyChatsView() {
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
          const Text("Немає чатів", style: TextStyle(color: Colors.white54)),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SearchUserScreen(myUsername: widget.myUsername),
              ),
            ),
            child: const Text("Почати спілкування"),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(
    String chatId,
    String otherUser,
    String lastMsgText,
    dynamic lastMsgTime,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        _formatTime(lastMsgTime),
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
        ).then((_) {
          // Оновлюємо список після повернення з чату (Windows)
          if (!firebaseAvailable) _loadWindowsChats();
        });
      },
    );
  }
}

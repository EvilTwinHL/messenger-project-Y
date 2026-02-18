import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Для ChatScreen та serverUrl

class SearchUserScreen extends StatefulWidget {
  final String myUsername;
  const SearchUserScreen({super.key, required this.myUsername});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  // 1. Пошук користувачів через твоє нове API
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '$serverUrl/search_users?q=$query&myUsername=${widget.myUsername}',
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error searching: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. Створення або відкриття діалогу
  Future<void> _startChat(String otherUsername, String? avatarUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/get_or_create_dm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'myUsername': widget.myUsername,
          'otherUsername': otherUsername,
        }),
      );

      if (response.statusCode == 200) {
        final chatData = jsonDecode(response.body);
        final chatId = chatData['id'];

        if (!mounted) return;

        // Переходимо в чат
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              username: widget.myUsername,
              chatId: chatId, // 🔥 Передаємо ID
              otherUsername: otherUsername, // 🔥 Ім'я співрозмовника
              avatarUrl: null, // Своя аватарка (можна дістати з prefs)
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Помилка створення чату: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Пошук користувачів...",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onSubmitted: _searchUsers,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _searchUsers(_searchController.text),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['avatarUrl'] != null
                        ? NetworkImage(user['avatarUrl'])
                        : null,
                    child: user['avatarUrl'] == null
                        ? Text(user['username'][0].toUpperCase())
                        : null,
                  ),
                  title: Text(
                    user['username'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => _startChat(user['username'], user['avatarUrl']),
                );
              },
            ),
    );
  }
}

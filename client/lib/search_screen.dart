import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'theme.dart';
import 'config/app_config.dart';

class SearchUserScreen extends StatefulWidget {
  final String myUsername;
  const SearchUserScreen({super.key, required this.myUsername});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          '${AppConfig.serverUrl}/search_users?q=$query&myUsername=${widget.myUsername}',
        ),
      );
      if (response.statusCode == 200) {
        setState(() => _results = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(String otherUsername) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/get_or_create_dm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'myUsername': widget.myUsername,
          'otherUsername': otherUsername,
        }),
      );
      if (response.statusCode == 200) {
        final chatId = jsonDecode(response.body)['id'] as String;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              username: widget.myUsername,
              chatId: chatId,
              otherUsername: otherUsername,
              avatarUrl: null,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignalColors.appBackground,
      appBar: AppBar(
        backgroundColor: SignalColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SignalColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: SignalColors.textPrimary, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Пошук користувачів...',
            hintStyle: TextStyle(color: SignalColors.textSecondary),
            border: InputBorder.none,
            isDense: true,
          ),
          onSubmitted: _searchUsers,
          onChanged: (val) {
            if (val.length >= 2) _searchUsers(val);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: SignalColors.textPrimary),
            onPressed: () => _searchUsers(_searchController.text),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: SignalColors.primary),
            )
          : _results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.search,
                    size: 56,
                    color: SignalColors.textDisabled,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Почніть вводити нікнейм',
                    style: TextStyle(
                      color: SignalColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final user = _results[i];
                final username = user['username'] as String;
                final avatarUrl = user['avatarUrl'] as String?;
                final colors = SignalColors.avatarColorsFor(username);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: colors[0],
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: colors[1],
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(
                      color: SignalColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: SignalColors.textDisabled,
                  ),
                  onTap: () => _startChat(username),
                );
              },
            ),
    );
  }
}

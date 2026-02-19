import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart';
import 'home_screen.dart';

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
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
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
        if (finalAvatarUrl != null)
          await prefs.setString('avatarUrl', finalAvatarUrl);

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white10,
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
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Ваш нікнейм",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "УВІЙТИ",
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
      ),
    );
  }
}

//---BackUp

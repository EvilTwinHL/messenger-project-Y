import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'main.dart';
import 'theme.dart';
import 'login_screen.dart';
import 'utils/date_utils.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final String myUsername;
  final String myDisplayName;
  final String? myAvatarUrl;

  const HomeScreen({
    super.key,
    required this.myUsername,
    required this.myDisplayName,
    this.myAvatarUrl,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  // Мутабельний профіль
  late String _displayName;
  late String? _avatarUrl;
  String? _phone;
  String? _birthday;
  bool _birthdayVisible = false;
  bool _onlineVisible = true;

  List<Map<String, dynamic>> _windowsChats = [];
  bool _windowsChatsLoading = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.myDisplayName;
    _avatarUrl = widget.myAvatarUrl;
    _loadProfileExtras();
    if (!AppConfig.firebaseAvailable) _loadWindowsChats();
  }

  Future<void> _loadProfileExtras() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phone = prefs.getString('phone');
      _birthday = prefs.getString('birthday');
      _birthdayVisible = prefs.getBool('birthdayVisible') ?? false;
      _onlineVisible = prefs.getBool('onlineVisible') ?? true;
    });
  }

  Future<void> _loadWindowsChats() async {
    setState(() => _windowsChatsLoading = true);
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse(
          '${AppConfig.serverUrl}/get_user_chats?username=${widget.myUsername}',
        ),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (res.statusCode == 200) {
        setState(() {
          _windowsChats = (jsonDecode(res.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Помилка завантаження чатів: $e');
    } finally {
      setState(() => _windowsChatsLoading = false);
    }
  }

  Future<void> _pushProfileToServer(Map<String, dynamic> fields) async {
    try {
      final token = await AuthService.getToken();
      await http.post(
        Uri.parse('${AppConfig.serverUrl}/update_profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: jsonEncode(fields),
      );
    } catch (_) {}
  }

  void _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;
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
          setState(() => _avatarUrl = url);
          await AuthService.saveUser(
            username: widget.myUsername,
            displayName: _displayName,
            avatarUrl: url,
          );
          await _pushProfileToServer({'avatarUrl': url});
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
    }
  }

  // ──────────────────────────────────────────────────────
  // 👥 СТВОРЕННЯ ГРУПИ
  // ──────────────────────────────────────────────────────
  void _showCreateGroupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SignalColors.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateGroupSheet(
        myUsername: widget.myUsername,
        myDisplayName: _displayName,
        onCreated: (chatId, groupName, participants, admins) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                username: widget.myUsername,
                chatId: chatId,
                otherUsername: groupName,
                avatarUrl: _avatarUrl,
                isGroup: true,
                groupName: groupName,
                groupParticipants: participants,
                groupAdmins: admins,
              ),
            ),
          ).then((_) {
            if (!AppConfig.firebaseAvailable) _loadWindowsChats();
          });
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final safePad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: SignalColors.appBackground,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom:
                  AppSizes.navBarHeight +
                  AppSizes.navBarPaddingBottom +
                  safePad +
                  8,
            ),
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildChatsTab(),
                _buildContactsTab(),
                SettingsScreen(
                  username: widget.myUsername,
                  avatarUrl: _avatarUrl,
                ),
                _buildAccountTab(),
              ],
            ),
          ),

          // FAB для нового чату / групи
          if (_currentTab == 0)
            Positioned(
              right: 20,
              bottom:
                  AppSizes.navBarHeight +
                  AppSizes.navBarPaddingBottom +
                  safePad +
                  16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // FAB нова група
                  FloatingActionButton.small(
                    heroTag: 'fab_group',
                    backgroundColor: SignalColors.elevated,
                    elevation: 4,
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: SignalColors.primary,
                      size: 22,
                    ),
                    onPressed: _showCreateGroupSheet,
                  ),
                  const SizedBox(height: 10),
                  // FAB новий DM
                  FloatingActionButton(
                    heroTag: 'fab_dm',
                    backgroundColor: SignalColors.primary,
                    elevation: 4,
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SearchUserScreen(myUsername: widget.myUsername),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Nav bar
          Positioned(
            left: AppSizes.navBarPaddingH,
            right: AppSizes.navBarPaddingH,
            bottom: AppSizes.navBarPaddingBottom + safePad,
            child: _OvalNavBar(
              currentIndex: _currentTab,
              onTap: (i) => setState(() => _currentTab = i),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_currentTab == 3) {
      return AppBar(
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
            'Чати',
            style: TextStyle(color: SignalColors.primary, fontSize: 15),
          ),
          onPressed: () => setState(() => _currentTab = 0),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
        ),
        title: const Text(
          'Акаунт',
          style: TextStyle(
            color: SignalColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: SignalColors.textPrimary),
            tooltip: 'QR-код',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('QR-код — незабаром'),
                duration: Duration(seconds: 1),
              ),
            ),
          ),
        ],
      );
    }

    const titles = ['Повідомлення', 'Контакти', 'Налаштування', 'Акаунт'];
    return AppBar(
      backgroundColor: SignalColors.surface,
      elevation: 0,
      title: Text(
        titles[_currentTab],
        style: const TextStyle(
          color: SignalColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: AppSizes.appBarTitleSize,
        ),
      ),
      actions: [
        if (_currentTab == 0)
          IconButton(
            icon: const Icon(Icons.search, color: SignalColors.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SearchUserScreen(myUsername: widget.myUsername),
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // 👤 ACCOUNT TAB
  // ══════════════════════════════════════════════════════
  Widget _buildAccountTab() {
    final colors = SignalColors.avatarColorsFor(widget.myUsername);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: SignalColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: colors[0],
                      backgroundImage: _avatarUrl != null
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null
                          ? Text(
                              _displayName.isNotEmpty
                                  ? _displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: colors[1],
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
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
              Text(
                _displayName,
                style: const TextStyle(
                  color: SignalColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showOnlineStatusDialog,
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _onlineVisible
                                ? SignalColors.online
                                : SignalColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _onlineVisible ? 'онлайн' : 'невидимий',
                          style: TextStyle(
                            color: _onlineVisible
                                ? SignalColors.online
                                : SignalColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'натисни щоб керувати статусом',
                      style: TextStyle(
                        color: SignalColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _actionBtn(
                icon: Icons.add_a_photo_outlined,
                label: 'Фото',
                onTap: _pickAndUploadAvatar,
              ),
              const SizedBox(width: 10),
              _actionBtn(
                icon: Icons.edit_outlined,
                label: 'Редагувати',
                onTap: _showEditInfoSheet,
              ),
              const SizedBox(width: 10),
              _actionBtn(
                icon: Icons.settings_outlined,
                label: 'Налаштування',
                onTap: () => setState(() => _currentTab = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: SignalColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _infoRow(
                icon: Icons.phone_outlined,
                value: _phone ?? 'Додати номер',
                label: 'Мобільний',
                isEmpty: _phone == null,
                onTap: _showPhoneDialog,
              ),
              _cardDivider(),
              _infoRow(
                icon: Icons.alternate_email,
                value: '@${widget.myUsername}',
                label: 'Логін (натисни щоб скопіювати)',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.myUsername));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Логін скопійовано'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _cardDivider(),
              _infoRow(
                icon: Icons.cake_outlined,
                value: _birthdayText(),
                label: _birthday == null
                    ? 'День народження'
                    : _birthdayVisible
                    ? 'День народження · видно іншим'
                    : 'День народження · приховано',
                isEmpty: _birthday == null,
                onTap: _showBirthdayPicker,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: SignalColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: const Icon(Icons.exit_to_app, color: SignalColors.danger),
            title: const Text(
              'Вийти',
              style: TextStyle(color: SignalColors.danger),
            ),
            onTap: _confirmLogout,
          ),
        ),
        const SizedBox(height: 40),
      ],
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

  Widget _infoRow({
    required IconData icon,
    required String value,
    required String label,
    required VoidCallback onTap,
    bool isEmpty = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isEmpty
                  ? SignalColors.textSecondary
                  : SignalColors.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: isEmpty
                          ? SignalColors.primary
                          : SignalColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: SignalColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isEmpty ? Icons.add : Icons.chevron_right,
              color: SignalColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardDivider() =>
      const Divider(color: SignalColors.divider, height: 1, indent: 54);

  String _birthdayText() {
    if (_birthday == null) return 'Додати';
    try {
      final dt = DateTime.parse(_birthday!);
      const m = [
        '',
        'січ',
        'лют',
        'бер',
        'кві',
        'тра',
        'чер',
        'лип',
        'сер',
        'вер',
        'жов',
        'лис',
        'гру',
      ];
      return '${dt.day} ${m[dt.month]} ${dt.year}';
    } catch (_) {
      return _birthday!;
    }
  }

  // ══════════════════════════════════════════════════════
  // 📝 ДІАЛОГИ
  // ══════════════════════════════════════════════════════
  void _showEditInfoSheet() {
    final ctrl = TextEditingController(text: _displayName);
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
              'Редагування профілю',
              style: TextStyle(
                color: SignalColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: SignalColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Псевдонім',
                labelStyle: const TextStyle(color: SignalColors.textSecondary),
                filled: true,
                fillColor: SignalColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: SignalColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: SignalColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: SignalColors.primary,
                    width: 1.5,
                  ),
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
                  setState(() => _displayName = name);
                  await AuthService.saveUser(
                    username: widget.myUsername,
                    displayName: name,
                    avatarUrl: _avatarUrl,
                  );
                  await _pushProfileToServer({'displayName': name});
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

  void _showOnlineStatusDialog() {
    bool temp = _onlineVisible;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: SignalColors.elevated,
          title: const Text(
            'Статус онлайн',
            style: TextStyle(color: SignalColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Коли вимкнено — інші не бачать коли ти онлайн.',
                style: TextStyle(
                  color: SignalColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Показувати статус',
                    style: TextStyle(color: SignalColors.textPrimary),
                  ),
                  Switch(
                    value: temp,
                    onChanged: (v) => setS(() => temp = v),
                    activeColor: SignalColors.primary,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _onlineVisible = temp);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onlineVisible', temp);
                await _pushProfileToServer({'onlineVisible': temp});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SignalColors.primary,
              ),
              child: const Text(
                'Зберегти',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhoneDialog() {
    final ctrl = TextEditingController(text: _phone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SignalColors.elevated,
        title: const Text(
          'Номер телефону',
          style: TextStyle(color: SignalColors.textPrimary),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: SignalColors.textPrimary),
          decoration: InputDecoration(
            hintText: '+380 XX XXX XX XX',
            hintStyle: const TextStyle(color: SignalColors.textSecondary),
            filled: true,
            fillColor: SignalColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: SignalColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: SignalColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: SignalColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = ctrl.text.trim();
              Navigator.pop(ctx);
              final saved = phone.isNotEmpty ? phone : null;
              setState(() => _phone = saved);
              final prefs = await SharedPreferences.getInstance();
              if (saved != null) {
                await prefs.setString('phone', saved);
              } else {
                await prefs.remove('phone');
              }
              await _pushProfileToServer({'phone': saved});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: SignalColors.primary,
            ),
            child: const Text(
              'Зберегти',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBirthdayPicker() async {
    DateTime initial = DateTime(1990);
    if (_birthday != null) {
      try {
        initial = DateTime.parse(_birthday!);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Оберіть день народження',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: SignalColors.primary,
            surface: SignalColors.elevated,
            onSurface: SignalColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final dateStr = picked.toIso8601String().split('T')[0];
    final visible = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SignalColors.elevated,
        title: const Text(
          'Видимість',
          style: TextStyle(color: SignalColors.textPrimary),
        ),
        content: const Text(
          'Показувати день народження іншим користувачам?',
          style: TextStyle(color: SignalColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Приховати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SignalColors.primary,
            ),
            child: const Text(
              'Показувати',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final vis = visible ?? false;
    setState(() {
      _birthday = dateStr;
      _birthdayVisible = vis;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('birthday', dateStr);
    await prefs.setBool('birthdayVisible', vis);
    await _pushProfileToServer({'birthday': dateStr, 'birthdayVisible': vis});
  }

  void _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SignalColors.elevated,
        title: const Text(
          'Вийти?',
          style: TextStyle(color: SignalColors.textPrimary),
        ),
        content: const Text(
          'Ви впевнені що хочете вийти з акаунту?',
          style: TextStyle(color: SignalColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Вийти',
              style: TextStyle(color: SignalColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) _logout();
  }

  // ══════════════════════════════════════════════════════
  // 💬 CHATS TAB
  // ══════════════════════════════════════════════════════
  Widget _buildChatsTab() => AppConfig.firebaseAvailable
      ? _buildFirestoreChatList()
      : _buildWindowsChatList();

  Widget _buildFirestoreChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: widget.myUsername)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          final e = snap.error.toString();
          if (e.contains('index') || e.contains('FAILED_PRECONDITION'))
            return _indexErrorWidget();
          return Center(
            child: Text(
              'Помилка: ${snap.error}',
              style: const TextStyle(color: SignalColors.danger),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: SignalColors.primary),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) return _emptyChats();

        final chats = [...snap.data!.docs]
          ..sort((a, b) {
            try {
              final at = (a.data() as Map)['lastMessage']?['timestamp'];
              final bt = (b.data() as Map)['lastMessage']?['timestamp'];
              return _tsMs(bt).compareTo(_tsMs(at));
            } catch (_) {
              return 0;
            }
          });

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (_, i) {
            try {
              final chat = chats[i].data() as Map<String, dynamic>;
              final chatId = chats[i].id;
              final isGroup = chat['type'] == 'group';
              final participants = (chat['participants'] as List?) ?? [];
              final names =
                  (chat['participantNames'] as Map?)?.cast<String, String>() ??
                  {};
              final lm = chat['lastMessage'] ?? {};
              final unreadCounts =
                  (chat['unreadCounts'] as Map?)?.cast<String, dynamic>() ?? {};
              final unread = (unreadCounts[widget.myUsername] ?? 0) as int;

              if (isGroup) {
                final groupName = (chat['name'] as String?) ?? 'Група';
                final memberCount = participants.length;
                final admins = (chat['admins'] as List?)?.cast<String>() ?? [];
                return _groupChatTile(
                  chatId: chatId,
                  groupName: groupName,
                  memberCount: memberCount,
                  lastText: (lm['text'] ?? '') as String,
                  lastTs: lm['timestamp'],
                  lastSender: lm['sender'] as String?,
                  unreadCount: unread,
                  participants: participants.cast<String>(),
                  admins: admins,
                );
              } else {
                final otherUsername =
                    participants.firstWhere(
                          (u) => u != widget.myUsername,
                          orElse: () => 'Користувач',
                        )
                        as String;
                final otherDisplay = names[otherUsername] ?? otherUsername;
                return _chatTile(
                  chatId,
                  otherUsername,
                  otherDisplay,
                  (lm['text'] ?? '') as String,
                  lm['timestamp'],
                  unreadCount: unread,
                );
              }
            } catch (_) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  int _tsMs(dynamic ts) {
    if (ts == null) return 0;
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    if (ts is String) return DateTime.tryParse(ts)?.millisecondsSinceEpoch ?? 0;
    return 0;
  }

  Widget _buildWindowsChatList() {
    if (_windowsChatsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: SignalColors.primary),
      );
    }
    if (_windowsChats.isEmpty) return _emptyChats();
    return RefreshIndicator(
      color: SignalColors.primary,
      onRefresh: _loadWindowsChats,
      child: ListView.builder(
        itemCount: _windowsChats.length,
        itemBuilder: (_, i) {
          final chat = _windowsChats[i];
          final chatId = chat['id'] as String? ?? '';
          final isGroup = chat['type'] == 'group';
          final participants = (chat['participants'] as List?) ?? [];
          final lm = chat['lastMessage'];
          final text = (lm is Map) ? (lm['text'] ?? '') as String : '';
          final ts = (lm is Map) ? lm['timestamp'] : null;

          if (isGroup) {
            final admins = (chat['admins'] as List?)?.cast<String>() ?? [];
            return _groupChatTile(
              chatId: chatId,
              groupName: (chat['name'] as String?) ?? 'Група',
              memberCount: participants.length,
              lastText: text,
              lastTs: ts,
              lastSender: (lm is Map) ? lm['sender'] as String? : null,
              participants: participants.cast<String>(),
              admins: admins,
            );
          }

          final names =
              (chat['participantNames'] as Map?)?.cast<String, String>() ?? {};
          final otherUsername =
              participants.firstWhere(
                    (u) => u != widget.myUsername,
                    orElse: () => 'Користувач',
                  )
                  as String;
          final otherDisplay = names[otherUsername] ?? otherUsername;
          return _chatTile(chatId, otherUsername, otherDisplay, text, ts);
        },
      ),
    );
  }

  // ── DM тайл ──────────────────────────────────────────
  Widget _chatTile(
    String chatId,
    String otherUsername,
    String otherDisplay,
    String lastText,
    dynamic lastTs, {
    int unreadCount = 0,
  }) {
    final colors = SignalColors.avatarColorsFor(otherUsername);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: SignalColors.primary.withOpacity(0.08),
        highlightColor: Colors.transparent,
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  username: widget.myUsername,
                  chatId: chatId,
                  otherUsername: otherUsername,
                  avatarUrl: _avatarUrl,
                ),
              ),
            ).then((_) {
              if (!AppConfig.firebaseAvailable) _loadWindowsChats();
            }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.avatarRadiusMedium,
                backgroundColor: colors[0],
                child: Text(
                  otherDisplay.isNotEmpty ? otherDisplay[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: colors[1],
                    fontWeight: FontWeight.bold,
                    fontSize: AppSizes.avatarRadiusMedium * 0.66,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherDisplay,
                            style: const TextStyle(
                              color: SignalColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          ChatDateUtils.formatTime(lastTs),
                          style: const TextStyle(
                            color: SignalColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SignalColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) _unreadBadge(unreadCount),
            ],
          ),
        ),
      ),
    );
  }

  // ── Груповий тайл ─────────────────────────────────────
  Widget _groupChatTile({
    required String chatId,
    required String groupName,
    required int memberCount,
    required String lastText,
    required dynamic lastTs,
    required List<String> participants,
    List<String> admins = const [],
    String? lastSender,
    int unreadCount = 0,
  }) {
    final colors = SignalColors.avatarColorsFor(groupName);
    final preview = lastSender != null && lastText.isNotEmpty
        ? '$lastSender: $lastText'
        : lastText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: SignalColors.primary.withOpacity(0.08),
        highlightColor: Colors.transparent,
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  username: widget.myUsername,
                  chatId: chatId,
                  otherUsername: groupName,
                  avatarUrl: _avatarUrl,
                  isGroup: true,
                  groupName: groupName,
                  groupParticipants: participants,
                  groupAdmins: admins,
                ),
              ),
            ).then((_) {
              if (!AppConfig.firebaseAvailable) _loadWindowsChats();
            }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Груповий аватар — іконка людей
              Container(
                width: AppSizes.avatarRadiusMedium * 2,
                height: AppSizes.avatarRadiusMedium * 2,
                decoration: BoxDecoration(
                  color: colors[0],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group,
                  color: colors[1],
                  size: AppSizes.avatarRadiusMedium,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  groupName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: SignalColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$memberCount',
                                style: const TextStyle(
                                  color: SignalColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          ChatDateUtils.formatTime(lastTs),
                          style: const TextStyle(
                            color: SignalColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SignalColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) _unreadBadge(unreadCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unreadBadge(int count) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: SignalColors.primary,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _emptyChats() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.chat_bubble_outline,
          size: 64,
          color: SignalColors.textDisabled,
        ),
        const SizedBox(height: 12),
        const Text(
          'Немає чатів',
          style: TextStyle(color: SignalColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchUserScreen(myUsername: widget.myUsername),
            ),
          ),
          child: const Text(
            'Почати спілкування',
            style: TextStyle(color: SignalColors.primary),
          ),
        ),
      ],
    ),
  );

  Widget _indexErrorWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
          SizedBox(height: 12),
          Text(
            'Потрібен індекс Firestore!',
            style: TextStyle(
              color: SignalColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Відкрийте Debug Console та натисніть на посилання для створення індексу.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SignalColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _buildContactsTab() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.people_outline,
          size: 64,
          color: SignalColors.textDisabled,
        ),
        const SizedBox(height: 12),
        const Text(
          'Контакти',
          style: TextStyle(color: SignalColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchUserScreen(myUsername: widget.myUsername),
            ),
          ),
          child: const Text(
            'Знайти користувача',
            style: TextStyle(color: SignalColors.primary),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════
// 👥 ЕКРАН СТВОРЕННЯ ГРУПИ
// ══════════════════════════════════════════════════════════
class _CreateGroupSheet extends StatefulWidget {
  final String myUsername;
  final String myDisplayName;
  final Function(
    String chatId,
    String groupName,
    List<String> participants,
    List<String> admins,
  )
  onCreated;

  const _CreateGroupSheet({
    required this.myUsername,
    required this.myDisplayName,
    required this.onCreated,
  });

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final List<Map<String, dynamic>> _selected = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _creating = false;
  int _step = 0; // 0 = вибір учасників, 1 = назва групи

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse(
          '${AppConfig.serverUrl}/search_users?q=${Uri.encodeComponent(q)}&myUsername=${widget.myUsername}',
        ),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (res.statusCode == 200) {
        setState(
          () => _searchResults = (jsonDecode(res.body) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (_) {
    } finally {
      setState(() => _searching = false);
    }
  }

  void _toggleSelect(Map<String, dynamic> user) {
    setState(() {
      final exists = _selected.any((u) => u['username'] == user['username']);
      if (exists) {
        _selected.removeWhere((u) => u['username'] == user['username']);
      } else {
        _selected.add(user);
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selected.isEmpty) return;
    setState(() => _creating = true);

    try {
      final token = await AuthService.getToken();
      final members = _selected.map((u) => u['username'] as String).toList();
      final res = await http.post(
        Uri.parse('${AppConfig.serverUrl}/create_group'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? ''}',
        },
        body: jsonEncode({'name': name, 'members': members}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final chatId = data['id'] as String;
        final participants = (data['participants'] as List).cast<String>();
        final admins =
            (data['admins'] as List?)?.cast<String>() ?? [widget.myUsername];
        widget.onCreated(chatId, name, participants, admins);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                if (_step == 1)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: SignalColors.textPrimary,
                    ),
                    onPressed: () => setState(() => _step = 0),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                Expanded(
                  child: Text(
                    _step == 0 ? 'Додати учасників' : 'Назва групи',
                    style: const TextStyle(
                      color: SignalColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_step == 0 && _selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: const Text(
                      'Далі',
                      style: TextStyle(
                        color: SignalColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_step == 1)
                  _creating
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SignalColors.primary,
                          ),
                        )
                      : TextButton(
                          onPressed: _createGroup,
                          child: const Text(
                            'Створити',
                            style: TextStyle(
                              color: SignalColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
              ],
            ),
          ),
          const Divider(height: 1, color: SignalColors.divider),

          if (_step == 0) ...[
            // Вибрані учасники
            if (_selected.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _selected.length,
                  itemBuilder: (_, i) {
                    final u = _selected[i];
                    final name =
                        (u['displayName'] as String?) ??
                        u['username'] as String;
                    final colors = SignalColors.avatarColorsFor(
                      u['username'] as String,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _toggleSelect(u),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: colors[0],
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: colors[1],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: SignalColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Пошук
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                style: const TextStyle(color: SignalColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Пошук користувачів...',
                  hintStyle: const TextStyle(color: SignalColors.textSecondary),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: SignalColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: SignalColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Результати пошуку
            Expanded(
              child: _searching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SignalColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) {
                        final u = _searchResults[i];
                        final uname = u['username'] as String;
                        final dname = (u['displayName'] as String?) ?? uname;
                        final isSelected = _selected.any(
                          (s) => s['username'] == uname,
                        );
                        final colors = SignalColors.avatarColorsFor(uname);
                        return ListTile(
                          onTap: () => _toggleSelect(u),
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
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: SignalColors.primary,
                                )
                              : const Icon(
                                  Icons.radio_button_unchecked,
                                  color: SignalColors.textSecondary,
                                ),
                        );
                      },
                    ),
            ),
          ],

          if (_step == 1)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Учасники preview
                    Text(
                      '${_selected.length + 1} учасник${_selected.length == 0
                          ? ''
                          : _selected.length < 4
                          ? 'и'
                          : 'ів'}',
                      style: const TextStyle(
                        color: SignalColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Поле назви
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      style: const TextStyle(
                        color: SignalColors.textPrimary,
                        fontSize: 18,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Назва групи',
                        hintStyle: const TextStyle(
                          color: SignalColors.textSecondary,
                          fontSize: 18,
                        ),
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 🏷️ NAV BAR
// ══════════════════════════════════════════════════════════
class _OvalNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _OvalNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Чати',
    ),
    _NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Контакти',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Налаштування',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Акаунт',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.navBarHeight,
      decoration: BoxDecoration(
        color: SignalColors.navBarBg,
        borderRadius: BorderRadius.circular(AppSizes.navBarBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_items.length, (i) {
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? SignalColors.activeNavPill.withOpacity(0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      active ? _items[i].activeIcon : _items[i].icon,
                      size: AppSizes.navIconSize,
                      color: active
                          ? SignalColors.activeNavPill
                          : SignalColors.inactiveNav,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _items[i].label,
                    style: TextStyle(
                      fontSize: AppSizes.navLabelSize,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active
                          ? SignalColors.activeNavPill
                          : SignalColors.inactiveNav,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

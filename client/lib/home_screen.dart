import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'main.dart';
import 'theme.dart';
import 'login_screen.dart'; // ← ДОДАТИ
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
  int _currentTab = 0; // 0=Chats 1=Contacts 2=Settings 3=Account

  List<Map<String, dynamic>> _windowsChats = [];
  bool _windowsChatsLoading = false;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.firebaseAvailable) _loadWindowsChats();
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
      debugPrint('Помилка: $e');
    } finally {
      setState(() => _windowsChatsLoading = false);
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final safePad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: SignalColors.appBackground,
      appBar: _buildAppBar(),
      // Контент займає весь екран — навігація плаває зверху через Stack
      body: Stack(
        children: [
          // ── Сторінки ─────────────────────────────────────────────
          Padding(
            // відступ знизу, щоб контент не ховався за таблеткою
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
                SettingsScreen(username: widget.myUsername),
                _buildAccountTab(),
              ],
            ),
          ),

          // ── FAB ──────────────────────────────────────────────────
          if (_currentTab == 0)
            Positioned(
              right: 20,
              bottom:
                  AppSizes.navBarHeight +
                  AppSizes.navBarPaddingBottom +
                  safePad +
                  16,
              child: FloatingActionButton(
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
            ),

          // ── Плаваюча таблетка навігації ───────────────────────────
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

  // ── AppBar ────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
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

  // ── CHATS TAB ─────────────────────────────────────────────────────
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
          if (e.contains('index') || e.contains('FAILED_PRECONDITION')) {
            return _buildIndexError();
          }
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
        if (!snap.hasData || snap.data!.docs.isEmpty) return _buildEmptyChats();

        final chats = [...snap.data!.docs]
          ..sort((a, b) {
            try {
              final aTs = (a.data() as Map)['lastMessage']?['timestamp'];
              final bTs = (b.data() as Map)['lastMessage']?['timestamp'];
              return _tsToMs(bTs).compareTo(_tsToMs(aTs));
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
              final participants = chat['participants'] as List? ?? [];
              final other =
                  participants.firstWhere(
                        (u) => u != widget.myUsername,
                        orElse: () => 'Користувач',
                      )
                      as String;
              final lm = chat['lastMessage'] ?? {};
              return _buildChatTile(
                chatId,
                other,
                (lm['text'] ?? '') as String,
                lm['timestamp'],
              );
            } catch (_) {
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  int _tsToMs(dynamic ts) {
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
    if (_windowsChats.isEmpty) return _buildEmptyChats();
    return RefreshIndicator(
      color: SignalColors.primary,
      onRefresh: _loadWindowsChats,
      child: ListView.builder(
        itemCount: _windowsChats.length,
        itemBuilder: (_, i) {
          final chat = _windowsChats[i];
          final chatId = chat['id'] as String? ?? '';
          final participants = chat['participants'] as List? ?? [];
          final other =
              participants.firstWhere(
                    (u) => u != widget.myUsername,
                    orElse: () => 'Користувач',
                  )
                  as String;
          final lm = chat['lastMessage'];
          final text = (lm is Map) ? (lm['text'] ?? '') as String : '';
          final ts = (lm is Map) ? lm['timestamp'] : null;
          return _buildChatTile(chatId, other, text, ts);
        },
      ),
    );
  }

  Widget _buildChatTile(
    String chatId,
    String other,
    String lastText,
    dynamic lastTs,
  ) {
    final colors = SignalColors.avatarColorsFor(other);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: SignalColors.primary.withOpacity(0.08),
        highlightColor: Colors.transparent,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                username: widget.myUsername,
                chatId: chatId,
                otherUsername: other,
                avatarUrl: widget.myAvatarUrl,
              ),
            ),
          ).then((_) {
            if (!AppConfig.firebaseAvailable) _loadWindowsChats();
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSizes.avatarRadiusMedium,
                backgroundColor: colors[0],
                child: Text(
                  other.isNotEmpty ? other[0].toUpperCase() : '?',
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
                            other,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChats() {
    return Center(
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
  }

  Widget _buildIndexError() {
    return Center(
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
  }

  // ── CONTACTS TAB ──────────────────────────────────────────────────
  Widget _buildContactsTab() {
    return Center(
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

  // ── ACCOUNT TAB ───────────────────────────────────────────────────
  Widget _buildAccountTab() {
    final colors = SignalColors.avatarColorsFor(widget.myUsername);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: AppSizes.avatarRadiusLarge,
                backgroundColor: colors[0],
                backgroundImage: widget.myAvatarUrl != null
                    ? NetworkImage(widget.myAvatarUrl!)
                    : null,
                child: widget.myAvatarUrl == null
                    ? Text(
                        widget.myUsername.isNotEmpty
                            ? widget.myDisplayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colors[1],
                          fontSize: AppSizes.avatarRadiusLarge * 0.75,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                widget.myDisplayName,
                style: const TextStyle(
                  color: SignalColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${widget.myUsername}',
                style: const TextStyle(
                  color: SignalColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'онлайн',
                style: TextStyle(color: SignalColors.online, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: SignalColors.divider, height: 1),
        _accTile(Icons.edit_outlined, 'Редагувати профіль'),
        _accTile(Icons.notifications_outlined, 'Сповіщення'),
        _accTile(Icons.privacy_tip_outlined, 'Приватність'),
        const Divider(color: SignalColors.divider, height: 1),
        ListTile(
          leading: const Icon(Icons.exit_to_app, color: SignalColors.danger),
          title: const Text(
            'Вийти',
            style: TextStyle(color: SignalColors.danger),
          ),
          onTap: _logout,
        ),
      ],
    );
  }

  Widget _accTile(IconData icon, String label) => ListTile(
    leading: Icon(icon, color: SignalColors.textSecondary),
    title: Text(label, style: const TextStyle(color: SignalColors.textPrimary)),
    trailing: const Icon(Icons.chevron_right, color: SignalColors.textDisabled),
    onTap: () {},
  );
}

// ═══════════════════════════════════════════════════════════════════
//  🏷️  _OvalNavBar  —  плаваюча овальна навігація
// ═══════════════════════════════════════════════════════════════════
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Іконка з підсвіченим фоном
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
                    // Лейбл
                    Text(
                      _items[i].label,
                      style: TextStyle(
                        fontSize: AppSizes.navLabelSize,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: active
                            ? SignalColors.activeNavPill
                            : SignalColors.inactiveNav,
                      ),
                    ),
                  ],
                ),
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

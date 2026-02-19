import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart'; // Імпортуємо нашу тему

class SignalContextMenu {
  static void show(
    BuildContext context, {
    required GlobalKey messageKey,
    required Widget messageChild,
    required bool isMe,
    required Function(String emoji) onReactionTap,
    required Function(String action) onActionTap,
  }) {
    // 1. Отримуємо координати повідомлення
    final RenderBox? renderBox =
        messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    // Вібрація при відкритті
    HapticFeedback.mediumImpact();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (ctx, anim, secAnim) => _ContextMenuOverlay(
          messageChild: messageChild,
          position: offset,
          size: size,
          isMe: isMe,
          onReactionTap: onReactionTap,
          onActionTap: onActionTap,
        ),
      ),
    );
  }
}

class _ContextMenuOverlay extends StatefulWidget {
  final Widget messageChild;
  final Offset position;
  final Size size;
  final bool isMe;
  final Function(String) onReactionTap;
  final Function(String) onActionTap;

  const _ContextMenuOverlay({
    required this.messageChild,
    required this.position,
    required this.size,
    required this.isMe,
    required this.onReactionTap,
    required this.onActionTap,
  });

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Визначаємо, де малювати меню (зверху чи знизу від повідомлення)
    final bool showMenuBelow = widget.position.dy < screenSize.height / 2;

    // Відступи
    const double reactionBarHeight = 60;
    const double menuHeight = 250;

    // Коригуємо позицію, щоб не вилазило за екран
    double topPosition = widget.position.dy;

    return DefaultTextStyle(
      // Скидаємо будь-який успадкований TextDecoration (жовте підкреслення)
      style: const TextStyle(
        decoration: TextDecoration.none,
        color: Colors.white,
        fontFamily: 'Roboto',
      ),
      child: Stack(
        children: [
          // 1. Розмитий фон (Backdrop)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),

          // 2. Саме повідомлення (Копія)
          Positioned(
            top: topPosition,
            left: widget.position.dx,
            width: widget.size.width,
            child: Hero(
              tag: 'message_hero', // Можна додати Hero для плавності
              child: Material(
                color: Colors.transparent,
                child: widget.messageChild,
              ),
            ),
          ),

          // 3. Панель реакцій (Завжди трохи вище повідомлення)
          Positioned(
            top: topPosition - reactionBarHeight - 10,
            left: 20, // Центрувати або фіксовано
            right: 20,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _ReactionBar(
                onTap: (emoji) {
                  widget.onReactionTap(emoji);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),

          // 4. Меню дій (Знизу або зверху)
          Positioned(
            top: showMenuBelow
                ? topPosition + widget.size.height + 10
                : topPosition -
                      menuHeight -
                      80, // Якщо знизу немає місця, кидаємо наверх
            left: widget.isMe ? null : 20,
            right: widget.isMe ? 20 : null,
            width: 200,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: _ActionMenu(
                isMe: widget.isMe,
                onTap: (action) {
                  // ⚠️ Спочатку ЗАКРИВАЄМО меню, потім викликаємо дію.
                  // Якщо зробити навпаки — діалог (напр. підтвердження видалення)
                  // з'являється під route меню і зникає разом з ним.
                  Navigator.of(context).pop();
                  Future.delayed(const Duration(milliseconds: 320), () {
                    widget.onActionTap(action);
                  });
                },
              ),
            ),
          ),
        ],
      ), // Stack
    ); // DefaultTextStyle
  }
}

class _ReactionBar extends StatelessWidget {
  final Function(String) onTap;
  const _ReactionBar({required this.onTap});

  final emojis = const ['❤️', '👍', '👎', '😂', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: emojis
            .map(
              (e) => GestureDetector(
                onTap: () => onTap(e),
                child: Text(
                  e,
                  style: const TextStyle(
                    fontSize: 28,
                    decoration:
                        TextDecoration.none, // ← фікс жовтого підкреслення
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  final bool isMe;
  final Function(String) onTap;
  const _ActionMenu({required this.isMe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildItem(Icons.reply, "Відповісти", "reply"),
            _buildItem(Icons.copy, "Копіювати", "copy"),
            if (isMe) ...[
              _buildItem(Icons.edit, "Редагувати", "edit"),
              const Divider(height: 1, color: Colors.white10),
              _buildItem(
                Icons.delete,
                "Видалити",
                "delete",
                isDestructive: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    IconData icon,
    String text,
    String id, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: () => onTap(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.redAccent : Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: isDestructive ? Colors.redAccent : Colors.white,
                fontSize: 16,
                decoration: TextDecoration.none,
                fontFamily: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

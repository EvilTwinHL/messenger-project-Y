import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

class SignalContextMenu {
  static void show(
    BuildContext context, {
    required GlobalKey messageKey,
    required Widget messageChild,
    required bool isMe,
    required Function(String emoji) onReactionTap,
    required Function(String action) onActionTap,
  }) {
    final RenderBox? renderBox =
        messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    HapticFeedback.mediumImpact();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (ctx, anim, _) => _ContextMenuOverlay(
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
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnim = Tween(
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
    final screen = MediaQuery.of(context).size;
    final safePad = MediaQuery.of(context).padding;

    const reactionBarH = 52.0;
    const reactionBarMarginV = 8.0;
    const menuH = 200.0;
    const menuW = 210.0;
    const edgePad = 12.0;

    // Доступна зона екрана
    final areaTop = safePad.top + edgePad;
    final areaBottom = screen.height - safePad.bottom - edgePad;

    // Позиція оригінального повідомлення
    final msgTop = widget.position.dy;

    // КЛЮЧОВА ПРАВКА: обмежуємо висоту копії до 40% екрана.
    // Це не чіпає оригінал у чаті — тільки копію в оверлеї.
    // Завдяки цьому меню і реакції завжди мають місце.
    final cappedMsgH = widget.size.height.clamp(0.0, screen.height * 0.40);
    final msgBottom = msgTop + cappedMsgH;

    // Вирішуємо: меню знизу чи зверху?
    // Знизу якщо там вистачає місця на меню + реакції + відступи
    final spaceBelow = areaBottom - msgBottom;
    final showMenuBelow =
        spaceBelow >= menuH + reactionBarH + reactionBarMarginV * 2 + 16;

    // Позиція меню
    double menuTop;
    if (showMenuBelow) {
      menuTop = msgBottom + 10;
    } else {
      menuTop = msgTop - menuH - 10;
    }
    menuTop = menuTop.clamp(areaTop, areaBottom - menuH);

    // Позиція реакцій — НЕ перетинаються з меню
    double reactionTop;
    if (showMenuBelow) {
      // Меню знизу → реакції над повідомленням
      reactionTop = msgTop - reactionBarH - reactionBarMarginV;
    } else {
      // Меню зверху → реакції між нижнім краєм меню і повідомленням
      reactionTop = menuTop + menuH + reactionBarMarginV;
    }
    reactionTop = reactionTop.clamp(areaTop, areaBottom - reactionBarH);
    // Гарантуємо що реакції не налізають на меню зверху
    if (!showMenuBelow && reactionTop < menuTop + menuH + 4) {
      reactionTop = menuTop + menuH + 4;
    }

    // Горизонтальне вирівнювання меню
    double? menuLeft;
    double? menuRight;
    if (widget.isMe) {
      menuRight = edgePad;
      if (screen.width - edgePad - menuW < edgePad) {
        menuRight = null;
        menuLeft = edgePad;
      }
    } else {
      menuLeft = edgePad;
    }

    return DefaultTextStyle(
      style: const TextStyle(
        decoration: TextDecoration.none,
        color: SignalColors.textPrimary,
        fontFamily: 'Roboto',
      ),
      child: Stack(
        children: [
          // Затемнений фон
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black.withOpacity(0.7)),
          ),

          // Копія повідомлення — обмежена по висоті через ClipRect
          Positioned(
            top: msgTop,
            left: widget.position.dx,
            width: widget.size.width,
            child: ClipRect(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: cappedMsgH),
                child: Material(
                  color: Colors.transparent,
                  child: widget.messageChild,
                ),
              ),
            ),
          ),

          // Панель реакцій
          Positioned(
            top: reactionTop,
            left: edgePad,
            right: edgePad,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: _ReactionBar(
                onTap: (e) {
                  widget.onReactionTap(e);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),

          // Меню дій
          Positioned(
            top: menuTop,
            left: menuLeft,
            right: menuRight,
            width: menuW,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _ActionMenu(
                isMe: widget.isMe,
                onTap: (action) {
                  Navigator.of(context).pop();
                  Future.delayed(const Duration(milliseconds: 320), () {
                    widget.onActionTap(action);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reaction bar ──────────────────────────────────────────────
class _ReactionBar extends StatelessWidget {
  final Function(String) onTap;
  const _ReactionBar({required this.onTap});

  static const _emojis = ['❤️', '👍', '👎', '😂', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: SignalColors.elevated,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _emojis
            .map(
              (e) => GestureDetector(
                onTap: () => onTap(e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    e,
                    style: const TextStyle(
                      fontSize: 28,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Action menu ───────────────────────────────────────────────
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
          color: SignalColors.elevated,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _item(Icons.reply_outlined, 'Відповісти', 'reply'),
            _divider(),
            _item(Icons.copy_outlined, 'Копіювати', 'copy'),
            if (isMe) ...[
              _divider(),
              _item(Icons.edit_outlined, 'Редагувати', 'edit'),
              _divider(),
              _item(Icons.delete_outline, 'Видалити', 'delete', red: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, String id, {bool red = false}) {
    final color = red ? SignalColors.danger : SignalColors.textPrimary;
    return InkWell(
      onTap: () => onTap(id),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
    color: SignalColors.divider,
    height: 1,
    indent: 16,
    endIndent: 16,
  );
}

import 'package:flutter/material.dart';
import '../theme.dart';
import '../main.dart' show AppColors;

// ═══════════════════════════════════════════════════════════════
// ⌨️ TYPING INDICATOR  (збільшений, без аватара для DM)
// ═══════════════════════════════════════════════════════════════
class TypingIndicator extends StatefulWidget {
  final String username;

  /// isDM: true — приватний чат (аватар прибрано).
  /// false — груповий чат (аватар відображається).
  final bool isDM;
  const TypingIndicator({super.key, required this.username, this.isDM = true});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  // Три анімації з зміщенням фаз
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dot1 = _staggeredAnim(0.0, 0.33);
    _dot2 = _staggeredAnim(0.2, 0.53);
    _dot3 = _staggeredAnim(0.4, 0.73);
  }

  Animation<double> _staggeredAnim(double begin, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween(0.3), weight: 20),
    ]).animate(
      CurvedAnimation(
        parent: _dotController,
        curve: Interval(begin, end, curve: Curves.linear),
      ),
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Аватар — тільки для групових чатів
          if (!widget.isDM) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.mainColor,
              child: Text(
                widget.username.isNotEmpty
                    ? widget.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Бульбашка з точками
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: SignalColors.incoming,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(_dot1),
                const SizedBox(width: 5),
                _buildDot(_dot2),
                const SizedBox(width: 5),
                _buildDot(_dot3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, -4 * (anim.value - 0.3)),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../main.dart' show AppColors;

// =======================
// 🎯 SWIPE-TO-REPLY WIDGET
// =======================
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final Color? replyIconColor;
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.replyIconColor,
  });
  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconOpacityAnimation;
  double _dragExtent = 0;
  bool _dragUnderway = false;
  static const double _kReplyThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _iconOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragUnderway = true;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragUnderway) return;
    final delta = details.primaryDelta!;
    // 🔥 ВИПРАВЛЕНО: Прибрали if (delta > 0), щоб можна було повертати назад
    setState(() {
      _dragExtent = (_dragExtent + delta).clamp(0.0, _kReplyThreshold * 1.5);
      _controller.value = (_dragExtent / _kReplyThreshold).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragUnderway) return;
    _dragUnderway = false;
    if (_dragExtent >= _kReplyThreshold) {
      Vibration.vibrate(duration: 50);
      widget.onReply();
    }
    setState(() {
      _dragExtent = 0;
    });
    _controller.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: Opacity(
                  opacity: _iconOpacityAnimation.value,
                  child: Transform.scale(
                    scale: _iconScaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (widget.replyIconColor ?? AppColors.mainColor)
                            .withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reply,
                        color: widget.replyIconColor ?? AppColors.mainColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: child,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

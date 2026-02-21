import 'package:flutter/material.dart';
import '../main.dart' show AppColors;

// =======================
// 🔥 ReplyPreview Widget
// =======================
class ReplyPreview extends StatelessWidget {
  final Map? replyTo;
  final VoidCallback? onTap;
  final bool isMe;

  const ReplyPreview({super.key, this.replyTo, this.onTap, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    if (replyTo == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white : AppColors.mainColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replyTo!['sender'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              replyTo!['text'] ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

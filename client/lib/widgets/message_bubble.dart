import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../main.dart' show AppColors;
import '../audio_player_widget.dart';
import 'reply_preview.dart';
import 'reaction_widgets.dart';

// =======================
// 💬 MessageBubble з Reply
// =======================
class MessageBubble extends StatelessWidget {
  final String text;
  final String sender;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration;
  final bool isMe;
  final dynamic timestamp;
  final String? avatarUrl;
  final bool isRead;
  final Map? replyTo;
  final Map<String, dynamic>? reactions;
  final String messageId;
  final String currentUsername;
  final Function(String messageId, String emoji)? onReactionTap;
  final bool edited;

  const MessageBubble({
    super.key,
    required this.text,
    required this.sender,
    required this.isMe,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    this.timestamp,
    this.avatarUrl,
    this.isRead = false,
    this.replyTo,
    this.reactions,
    required this.messageId,
    required this.currentUsername,
    this.onReactionTap,
    this.edited = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(timestamp);
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width *
                  AppSizes.bubbleMaxWidthRatio,
            ),
            decoration: BoxDecoration(
              color: isMe ? SignalColors.outgoing : SignalColors.incoming,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppSizes.bubbleRadius),
                topRight: const Radius.circular(AppSizes.bubbleRadius),
                bottomLeft: isMe
                    ? const Radius.circular(AppSizes.bubbleRadius)
                    : const Radius.circular(4),
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(AppSizes.bubbleRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.bubblePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        sender,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (replyTo != null)
                    ReplyPreview(replyTo: replyTo, isMe: isMe, onTap: () {}),
                  if (imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(imageUrl!, fit: BoxFit.cover),
                      ),
                    ),
                  if (audioUrl != null)
                    AudioMessagePlayer(
                      audioUrl: audioUrl!,
                      duration: audioDuration,
                      isMe: isMe,
                    ),
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: AppSizes.bubbleFontSize,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (edited) ...[
                        Text(
                          'ред.',
                          style: TextStyle(
                            fontSize: AppSizes.bubbleTimeFontSize,
                            color: Colors.white.withOpacity(0.4),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: AppSizes.bubbleTimeFontSize,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 5),
                        Icon(
                          isRead ? Icons.done_all : Icons.check,
                          size: 14,
                          color: isRead
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (reactions != null && reactions!.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, -10),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: ReactionsDisplay(
                reactions: reactions,
                currentUsername: currentUsername,
                onReactionTap: (emoji) {
                  if (onReactionTap != null) onReactionTap!(messageId, emoji);
                },
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) {
      final now = DateTime.now();
      return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp).toLocal();
      } else if (timestamp is Map && timestamp['_seconds'] != null) {
        date = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else {
        return '';
      }
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
  }
}

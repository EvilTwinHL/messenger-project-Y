import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../main.dart' show AppColors;
import '../audio_player_widget.dart';
import 'reply_preview.dart';
import 'reaction_widgets.dart';

// Кількість рядків після яких показується "Читати далі"
const int _kCollapsedLines = 8;

// =======================
// 💬 MessageBubble з Reply + Read More
// =======================
class MessageBubble extends StatefulWidget {
  final String text;
  final String sender;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration;
  final bool isMe;
  final dynamic timestamp;
  final String? avatarUrl;

  /// Статус повідомлення: "sent" | "delivered" | "read"
  /// null — fallback до старої логіки isRead
  final String? status;
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
    this.status,
    this.replyTo,
    this.reactions,
    required this.messageId,
    required this.currentUsername,
    this.onReactionTap,
    this.edited = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isExpanded = false;

  // Перевіряємо чи текст довгий (грубо: >_kCollapsedLines рядків ~60 символів/рядок)
  // Точна перевірка через TextPainter занадто дорога — використовуємо евристику
  bool _needsCollapse(String text) {
    if (text.length < 300) return false; // Короткий текст — не ховаємо
    final newlines = '\n'.allMatches(text).length;
    if (newlines >= _kCollapsedLines) return true;
    // Приблизно: якщо текст > ~480 символів (8 рядків × ~60 симв.)
    return text.length > 480;
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _formatTime(widget.timestamp);
    final bool longText = widget.text.isNotEmpty && _needsCollapse(widget.text);

    return Column(
      crossAxisAlignment: widget.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width *
                  AppSizes.bubbleMaxWidthRatio,
            ),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? SignalColors.outgoing
                  : SignalColors.incoming,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppSizes.bubbleRadius),
                topRight: const Radius.circular(AppSizes.bubbleRadius),
                bottomLeft: widget.isMe
                    ? const Radius.circular(AppSizes.bubbleRadius)
                    : const Radius.circular(4),
                bottomRight: widget.isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(AppSizes.bubbleRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.bubblePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ім'я відправника (тільки для чужих)
                  if (!widget.isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        widget.sender,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),

                  // Reply preview
                  if (widget.replyTo != null)
                    ReplyPreview(
                      replyTo: widget.replyTo,
                      isMe: widget.isMe,
                      onTap: () {},
                    ),

                  // Фото
                  if (widget.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // Аудіо
                  if (widget.audioUrl != null)
                    AudioMessagePlayer(
                      audioUrl: widget.audioUrl!,
                      duration: widget.audioDuration,
                      isMe: widget.isMe,
                    ),

                  // ── Текст з Read More ──────────────────────
                  if (widget.text.isNotEmpty) ...[
                    Text(
                      widget.text,
                      // Якщо довгий і не розгорнутий — обрізаємо
                      maxLines: longText && !_isExpanded
                          ? _kCollapsedLines
                          : null,
                      overflow: longText && !_isExpanded
                          ? TextOverflow.ellipsis
                          : TextOverflow.visible,
                      style: const TextStyle(
                        fontSize: AppSizes.bubbleFontSize,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),

                    // Кнопка "Читати далі" / "Згорнути"
                    if (longText)
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _isExpanded ? 'Згорнути ▲' : 'Читати далі ▼',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.isMe
                                  ? Colors.white.withOpacity(0.75)
                                  : AppColors.mainColor.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 4),

                  // Час + статус прочитання
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.edited) ...[
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
                      if (widget.isMe) ...[
                        const SizedBox(width: 5),
                        _StatusIcon(status: widget.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Реакції
        if (widget.reactions != null && widget.reactions!.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, -10),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: ReactionsDisplay(
                reactions: widget.reactions,
                currentUsername: widget.currentUsername,
                onReactionTap: (emoji) {
                  if (widget.onReactionTap != null) {
                    widget.onReactionTap!(widget.messageId, emoji);
                  }
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

// ══════════════════════════════════════════════════════════
// ✓ Іконка статусу повідомлення
// ══════════════════════════════════════════════════════════
class _StatusIcon extends StatelessWidget {
  final String? status;
  const _StatusIcon({this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'read':
        // ✓✓ сині — прочитано
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF4FC3F7));
      case 'delivered':
        // ✓✓ сірі — доставлено
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white.withOpacity(0.55),
        );
      case 'sent':
      default:
        // ✓ сірий — відправлено на сервер
        return Icon(
          Icons.check,
          size: 14,
          color: Colors.white.withOpacity(0.55),
        );
    }
  }
}
//---
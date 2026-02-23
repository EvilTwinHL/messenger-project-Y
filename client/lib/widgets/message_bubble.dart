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
// ✓ Signal-style іконка статусу повідомлення
// sent     = 1 кружок (контур) + галочка
// delivered = 2 кружки (контур) + галочка
// read     = 2 кружки (заповнені сині) + галочка
// ══════════════════════════════════════════════════════════
class _StatusIcon extends StatelessWidget {
  final String? status;
  const _StatusIcon({this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'read':
        return const _SignalStatus(circles: 2, filled: true);
      case 'delivered':
        return const _SignalStatus(circles: 2, filled: false);
      case 'sent':
      default:
        return const _SignalStatus(circles: 1, filled: false);
    }
  }
}

class _SignalStatus extends StatelessWidget {
  final int circles; // 1 = sent, 2 = delivered/read
  final bool filled; // true = read (сині), false = сірі

  const _SignalStatus({required this.circles, required this.filled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: circles == 2 ? 22 : 14,
      height: 14,
      child: CustomPaint(
        painter: _StatusPainter(circles: circles, filled: filled),
      ),
    );
  }
}

class _StatusPainter extends CustomPainter {
  final int circles;
  // filled тепер означає "read" стиль:
  // false = сірий контур (sent/delivered)
  // true  = синій контур БЕЗ заливки (read) — "інвертований"
  final bool filled;

  const _StatusPainter({required this.circles, required this.filled});

  // Синій колір для "read" — колір бабл-фону відправника
  static const _blue = Color(0xFF2B5CE6);
  // Сірий для sent/delivered
  static const _grey = Color(0x8DFFFFFF); // білий 55%

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;

    // filled = read: синій контур + сіра заливка + синя галочка
    // !filled = sent/delivered: сірий контур, без заливки, сіра галочка
    final strokeColor = filled ? _blue : _grey;
    final strokeWidth = filled ? 1.6 : 1.3;

    final fillPaint = Paint()
      ..color = filled
          ? const Color(0x99B0B8C8) // сіра заливка для read
          : const Color(0xFF2B5CE6) // синя заливка для delivered
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final checkPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawCircle(Offset center, {double opacityMult = 1.0}) {
      canvas.drawCircle(center, r - 0.8, fillPaint);

      final sp = opacityMult == 1.0
          ? strokePaint
          : (Paint()
              ..color = strokeColor.withOpacity(opacityMult)
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth);
      canvas.drawCircle(center, r - 0.8, sp);
    }

    if (circles == 1) {
      final center = Offset(r, r);
      drawCircle(center);
      _drawCheck(canvas, checkPaint, center, r * 0.52);
    } else {
      final leftCenter = Offset(r, r);
      final rightCenter = Offset(r * 2.15, r);
      drawCircle(leftCenter, opacityMult: 0.6);
      drawCircle(rightCenter);
      _drawCheck(canvas, checkPaint, leftCenter, r * 0.52);
      _drawCheck(canvas, checkPaint, rightCenter, r * 0.52);
    }
  }

  void _drawCheck(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path()
      ..moveTo(center.dx - size * 0.65, center.dy)
      ..lineTo(center.dx - size * 0.08, center.dy + size * 0.58)
      ..lineTo(center.dx + size * 0.65, center.dy - size * 0.52);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StatusPainter old) =>
      old.circles != circles || old.filled != filled;
}

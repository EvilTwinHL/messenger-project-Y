import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';
import '../main.dart' show AppColors;
import '../audio_player_widget.dart';
import 'reply_preview.dart';
import 'reaction_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  final String? status;
  final Map? replyTo;
  final Map<String, dynamic>? reactions;
  final String messageId;
  final String currentUsername;
  final Function(String messageId, String emoji)? onReactionTap;
  final bool edited;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;

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
    this.fileUrl,
    this.fileName,
    this.fileSize,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isExpanded = false;

  bool _needsCollapse(String text) {
    if (text.length < 300) return false;
    final newlines = '\n'.allMatches(text).length;
    if (newlines >= _kCollapsedLines) return true;
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

                  // Файл
                  if (widget.fileUrl != null)
                    _FileBubble(
                      fileUrl: widget.fileUrl!,
                      fileName: widget.fileName ?? 'Файл',
                      fileSize: widget.fileSize,
                      isMe: widget.isMe,
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

                  // Час + статус
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
// ✓ Signal-style іконка статусу
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
  final int circles;
  final bool filled;

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
  final bool filled;

  const _StatusPainter({required this.circles, required this.filled});

  static const _blue = Color(0xFF2B5CE6);
  static const _grey = Color(0x8DFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final strokeColor = filled ? _blue : _grey;
    final strokeWidth = filled ? 1.6 : 1.3;

    final fillPaint = Paint()
      ..color = filled ? const Color(0x99B0B8C8) : const Color(0xFF2B5CE6)
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

// ══════════════════════════════════════════════════════════
// 📎 FileBubble
// ══════════════════════════════════════════════════════════
class _FileBubble extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final bool isMe;

  const _FileBubble({
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    required this.isMe,
  });

  IconData _iconFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _showFileOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (ctx, anim, _) => _FileMenuOverlay(
          fileName: fileName,
          fileSize: fileSize,
          iconData: _iconFor(fileName),
          formatSize: _formatSize,
          onOpen: () => _openFile(),
          onSave: () => _saveFile(ctx),
        ),
      ),
    );
  }

  Future<void> _openFile() async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final savePath = '${tmpDir.path}/$fileName';
      await Dio().download(fileUrl, savePath);
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        final uri = Uri.parse(fileUrl);
        if (await canLaunchUrl(uri)) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _saveFile(BuildContext context) async {
    // Запитуємо дозвіл на Android
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      PermissionStatus status;
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ — дозвіл на storage не потрібен
        status = PermissionStatus.granted;
      } else {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Немає дозволу на збереження файлів'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    try {
      Directory? saveDir;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 29) {
          saveDir = await getExternalStorageDirectory();
        } else {
          saveDir = Directory('/storage/emulated/0/Download');
          if (!await saveDir.exists()) {
            saveDir = await getExternalStorageDirectory();
          }
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      if (saveDir == null) throw Exception('saveDir is null');

      debugPrint('[FILE SAVE] dir: ${saveDir.path}');
      debugPrint('[FILE SAVE] file: $fileName');
      debugPrint('[FILE SAVE] url: $fileUrl');

      final savePath = '${saveDir.path}/$fileName';
      await Dio().download(fileUrl, savePath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Збережено: $fileName'),
            backgroundColor: const Color(0xFF2B5CE6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[FILE SAVE] Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFileOptions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(fileName),
              color: isMe ? Colors.white70 : SignalColors.primary,
              size: 28,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (fileSize != null)
                    Text(
                      _formatSize(fileSize),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              color: Colors.white.withOpacity(0.6),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 📋 FileMenuOverlay — Signal-style меню файлу
// ══════════════════════════════════════════════════════════
class _FileMenuOverlay extends StatefulWidget {
  final String fileName;
  final int? fileSize;
  final IconData iconData;
  final String Function(int?) formatSize;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  const _FileMenuOverlay({
    required this.fileName,
    required this.fileSize,
    required this.iconData,
    required this.formatSize,
    required this.onOpen,
    required this.onSave,
  });

  @override
  State<_FileMenuOverlay> createState() => _FileMenuOverlayState();
}

class _FileMenuOverlayState extends State<_FileMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Меню по центру
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 240,
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
                        // Заголовок
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            children: [
                              Icon(
                                widget.iconData,
                                color: SignalColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: SignalColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (widget.fileSize != null)
                                      Text(
                                        widget.formatSize(widget.fileSize),
                                        style: const TextStyle(
                                          color: SignalColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: SignalColors.divider, height: 1),
                        _item(Icons.open_in_new, 'Відкрити', () {
                          Navigator.of(context).pop();
                          widget.onOpen();
                        }),
                        const Divider(
                          color: SignalColors.divider,
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                        _item(
                          Icons.download_rounded,
                          'Зберегти',
                          () {
                            Navigator.of(context).pop();
                            widget.onSave();
                          },
                          color: SignalColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color color = SignalColors.textPrimary,
  }) {
    return InkWell(
      onTap: onTap,
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
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

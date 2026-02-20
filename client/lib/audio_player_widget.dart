import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'theme.dart';

// ═══════════════════════════════════════════════════════════════
// 🎵 WAVEFORM AUDIO PLAYER  (Signal-style)
// ═══════════════════════════════════════════════════════════════

class AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int? duration; // секунди
  final bool isMe;

  const AudioMessagePlayer({
    super.key,
    required this.audioUrl,
    this.duration,
    required this.isMe,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0.0; // 0..1
  int _elapsed = 0;
  int _totalSeconds = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  // Генеруємо псевдо-хвилі з URL як seed (детерміновано для одного повідомлення)
  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.duration ?? 0;
    _bars = _generateBars(widget.audioUrl);

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _elapsed = pos.inSeconds;
        if (_totalSeconds > 0) {
          _progress = pos.inMilliseconds / (_totalSeconds * 1000);
          if (_progress > 1) _progress = 1;
        }
      });
    });

    _stateSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _progress = 0;
        _elapsed = 0;
      });
    });
  }

  /// Генерує 40 стовпчиків, детерміновано на основі URL
  List<double> _generateBars(String seed) {
    final rng = Random(seed.hashCode);
    return List.generate(40, (i) {
      // Імітуємо природну форму мовлення: тихіше на початку/кінці
      final pos = i / 40;
      final envelope = sin(pos * pi).clamp(0.3, 1.0);
      return (0.2 + rng.nextDouble() * 0.8) * envelope;
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_progress >= 1.0) {
        await _player.stop();
        setState(() {
          _progress = 0;
          _elapsed = 0;
        });
      }
      await _player.play(UrlSource(widget.audioUrl));
      // Отримуємо тривалість якщо невідома
      if (_totalSeconds == 0) {
        final dur = await _player.getDuration();
        if (dur != null && mounted) {
          setState(() => _totalSeconds = dur.inSeconds);
        }
      }
      setState(() => _isPlaying = true);
    }
  }

  /// Перемотка по тапу на waveform
  void _seekTo(double fraction) {
    final targetMs = (fraction * _totalSeconds * 1000).round();
    _player.seek(Duration(milliseconds: targetMs));
    setState(() {
      _progress = fraction;
      _elapsed = (fraction * _totalSeconds).round();
    });
  }

  String _formatDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playedColor = widget.isMe
        ? Colors.white.withOpacity(0.95)
        : SignalColors.primary;
    final unplayedColor = widget.isMe
        ? Colors.white.withOpacity(0.35)
        : SignalColors.textSecondary.withOpacity(0.45);
    final btnColor = widget.isMe
        ? Colors.white.withOpacity(0.15)
        : SignalColors.elevated;
    final iconColor = widget.isMe ? Colors.white : SignalColors.textPrimary;
    final timeColor = widget.isMe
        ? Colors.white.withOpacity(0.6)
        : SignalColors.textSecondary;

    final displaySeconds = _isPlaying || _progress > 0
        ? _elapsed
        : _totalSeconds;

    return SizedBox(
      width: 230,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // ── Кнопка Play/Pause ──
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: btnColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: iconColor,
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ── Waveform ──
              Expanded(
                child: GestureDetector(
                  onTapDown: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    // Ширина waveform = expanded частина
                    final waveWidth = box.size.width - 40 - 10;
                    final fraction = (details.localPosition.dx / waveWidth)
                        .clamp(0.0, 1.0);
                    _seekTo(fraction);
                  },
                  child: _WaveformWidget(
                    bars: _bars,
                    progress: _progress,
                    playedColor: playedColor,
                    unplayedColor: unplayedColor,
                    isPlaying: _isPlaying,
                  ),
                ),
              ),
            ],
          ),

          // ── Час: elapsed зліва, total справа ──
          Padding(
            padding: const EdgeInsets.only(left: 50, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isPlaying || _progress > 0
                      ? _formatDuration(_elapsed)
                      : _formatDuration(0),
                  style: TextStyle(fontSize: 11, color: timeColor),
                ),
                Text(
                  _formatDuration(displaySeconds),
                  style: TextStyle(fontSize: 11, color: timeColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Власний рендер waveform
// ───────────────────────────────────────────────────────────────
class _WaveformWidget extends StatelessWidget {
  final List<double> bars;
  final double progress; // 0..1
  final Color playedColor;
  final Color unplayedColor;
  final bool isPlaying;

  const _WaveformWidget({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: CustomPaint(
        painter: _WaveformPainter(
          bars: bars,
          progress: progress,
          playedColor: playedColor,
          unplayedColor: unplayedColor,
          isPlaying: isPlaying,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final bool isPlaying;

  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = bars.length;
    final barW = (size.width / count) * 0.55;
    final gap = (size.width / count) * 0.45;
    final maxH = size.height * 0.85;
    final minH = size.height * 0.15;
    final midY = size.height / 2;

    final progressX = progress * size.width;

    for (int i = 0; i < count; i++) {
      final x = i * (barW + gap);
      final barH = (minH + bars[i] * (maxH - minH)).clamp(minH, maxH);

      final isPlayed = x < progressX;
      final paint = Paint()
        ..color = isPlayed ? playedColor : unplayedColor
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barW / 2, midY),
          width: barW,
          height: barH,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }

    // Playhead cursor (білий/синій вертикальний рядок)
    if (progress > 0 && progress < 1) {
      final cursorPaint = Paint()
        ..color = playedColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(progressX, midY - maxH / 2),
        Offset(progressX, midY + maxH / 2),
        cursorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.isPlaying != isPlaying;
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatDateUtils {
  /// HH:MM з будь-якого timestamp (Firestore, ISO string, int ms)
  static String formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      DateTime d;
      if (ts is Timestamp) {
        d = ts.toDate().toLocal();
      } else if (ts is String) {
        d = DateTime.parse(ts).toLocal();
      } else if (ts is int) {
        d = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
      } else if (ts is Map && ts['_seconds'] != null) {
        d = DateTime.fromMillisecondsSinceEpoch(
          (ts['_seconds'] as int) * 1000,
        ).toLocal();
      } else {
        return '';
      }
      return '${d.hour.toString().padLeft(2, '0')}'
          ':${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// Мітка дати: 'Сьогодні', 'Вчора', 'DD.MM.YYYY'
  static String dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Сьогодні';
    if (d == yday) return 'Вчора';
    return '${date.day.toString().padLeft(2, '0')}'
        '.${date.month.toString().padLeft(2, '0')}'
        '.${date.year}';
  }

  /// Парсить timestamp у DateTime
  static DateTime parseDate(dynamic ts) {
    if (ts == null) return DateTime.now();
    try {
      if (ts is Timestamp) return ts.toDate();
      if (ts is String) return DateTime.parse(ts);
      if (ts is Map && ts['_seconds'] != null)
        return DateTime.fromMillisecondsSinceEpoch(
          (ts['_seconds'] as int) * 1000,
        );
    } catch (_) {}
    return DateTime.now();
  }

  /// Чи однаковий день
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

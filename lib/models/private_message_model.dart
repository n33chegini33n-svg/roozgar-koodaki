import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/jalali.dart';
import 'permissions.dart';

/// پیام خصوصی بین معلم و ولی دربارهٔ یک نوآموز
class PrivateMessage {
  final String id;
  final String studentName; // شناسهٔ گفتگو
  final String senderName;
  final String senderRole; // teacher / parent
  final String text;
  final String date; // مثل 1405/07/15
  final String time; // مثل 14:30
  final int timestamp;

  const PrivateMessage({
    required this.id,
    required this.studentName,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.date,
    required this.time,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentName': studentName,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'date': date,
        'time': time,
        'timestamp': timestamp,
      };

  factory PrivateMessage.fromJson(Map<String, dynamic> j) => PrivateMessage(
        id: (j['id'] ?? '').toString(),
        studentName: (j['studentName'] ?? '').toString(),
        senderName: (j['senderName'] ?? '').toString(),
        senderRole: (j['senderRole'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        time: (j['time'] ?? '').toString(),
        timestamp: (j['timestamp'] ?? 0) is int ? (j['timestamp'] ?? 0) as int : 0,
      );
}

class ThreadSummary {
  final String studentName;
  final int count;
  final String lastDate;
  const ThreadSummary(this.studentName, this.count, this.lastDate);
}

class PrivateMessageService {
  static const String _key = 'private_messages_v1';
  static List<PrivateMessage>? _cache;
  static void clearCache() => _cache = null;

  static Future<List<PrivateMessage>> _all() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      final now = DateTime.now();
      _cache = [
        PrivateMessage(
          id: 'PM-seed',
          studentName: 'آرتین شجاعی',
          senderName: Session.role == AppRole.teacher ? Session.userName : 'مربی کلاس ${Session.className}',
          senderRole: 'teacher',
          text: 'سلام، آرتین امروز در بازی گروهی خیلی خوب بود و به دوستانش کمک کرد.',
          date: JalaliDate.now().formatted,
          time: '10:30',
          timestamp: now.millisecondsSinceEpoch,
        ),
      ];
      await _persist();
      return _cache!;
    }
    try {
      _cache = [
        for (final e in jsonDecode(raw) as List) PrivateMessage.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } catch (_) {
      _cache = [];
    }
    return _cache!;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final m in _cache ?? <PrivateMessage>[]) m.toJson()]));
  }

  /// گفتگوی یک نوآموز (قدیمی‌ترین اول)
  static Future<List<PrivateMessage>> thread(String studentName) async {
    final all = await _all();
    final list = all.where((m) => m.studentName == studentName).toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  static Future<void> send({
    required String studentName,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    final all = await _all();
    final now = DateTime.now();
    all.add(PrivateMessage(
      id: 'PM-${now.millisecondsSinceEpoch}',
      studentName: studentName,
      senderName: senderName,
      senderRole: senderRole,
      text: text,
      date: JalaliDate.now().formatted,
      time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      timestamp: now.millisecondsSinceEpoch,
    ));
    await _persist();
  }

  /// خلاصهٔ همهٔ گفتگوها (بدون متن پیام‌ها) برای فهرست مدیر
  static Future<List<ThreadSummary>> summaries() async {
    final all = await _all();
    final Map<String, List<PrivateMessage>> by = {};
    for (final m in all) {
      by.putIfAbsent(m.studentName, () => []).add(m);
    }
    final out = <ThreadSummary>[];
    by.forEach((name, list) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      out.add(ThreadSummary(name, list.length, list.first.date));
    });
    return out;
  }

  static Future<int> countFor(String studentName) async {
    final all = await _all();
    return all.where((m) => m.studentName == studentName).length;
  }
}

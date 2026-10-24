import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/jalali.dart';
import 'school_classes.dart';

/// سطوح ارزشیابی توصیفی (دورهٔ ابتدایی)
const List<String> kReportLevels = ['خیلی خوب', 'خوب', 'قابل قبول', 'نیاز به تلاش بیشتر'];

/// درس‌ها یا حیطه‌ها بر اساس کلاس
List<String> subjectsForClass(String className) {
  final n = normalizeClassName(className);
  if (n.contains('پیش')) {
    return ['مهارت‌های اجتماعی', 'زبان و گفتار', 'پیش‌ریاضی', 'هنر و خلاقیت', 'حرکت و بازی', 'ارزش‌ها و قرآن'];
  }
  return ['قرآن', 'فارسی', 'ریاضی', 'علوم تجربی', 'هنر', 'تربیت‌بدنی'];
}

/// نیم‌سال جاری: مهر تا دی = اول؛ بقیهٔ سال تحصیلی = دوم
String currentTerm() {
  final j = JalaliDate.now();
  final start = j.month >= 7 ? j.year : j.year - 1;
  final which = (j.month >= 7 && j.month <= 10) ? 'اول' : 'دوم';
  return 'نیم‌سال $which $start-${start + 1}';
}

class ReportCard {
  final String studentName;
  final String className;
  final String term;
  final Map<String, String> levels; // درس ← سطح
  final String note;
  final String updatedBy;
  final String updatedAt;

  const ReportCard({
    required this.studentName,
    required this.className,
    required this.term,
    required this.levels,
    required this.note,
    required this.updatedBy,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'studentName': studentName,
        'className': className,
        'term': term,
        'levels': levels,
        'note': note,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt,
      };

  factory ReportCard.fromJson(Map<String, dynamic> j) => ReportCard(
        studentName: (j['studentName'] ?? '').toString(),
        className: normalizeClassName((j['className'] ?? '').toString()),
        term: (j['term'] ?? '').toString(),
        levels: {
          for (final e in ((j['levels'] ?? {}) as Map).entries) e.key.toString(): e.value.toString(),
        },
        note: (j['note'] ?? '').toString(),
        updatedBy: (j['updatedBy'] ?? '').toString(),
        updatedAt: (j['updatedAt'] ?? '').toString(),
      );
}

class ReportCardService {
  static const String _key = 'report_cards_v1';
  static List<ReportCard>? _cache;
  static void clearCache() => _cache = null;

  static Future<List<ReportCard>> _all() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try {
      return _cache = [
        for (final e in jsonDecode(raw) as List) ReportCard.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } catch (_) {
      return _cache = [];
    }
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final c in _cache ?? <ReportCard>[]) c.toJson()]));
  }

  static Future<ReportCard?> get(String studentName, String term) async {
    final all = await _all();
    for (final c in all) {
      if (c.studentName == studentName && c.term == term) return c;
    }
    return null;
  }

  /// همهٔ کارنامه‌های یک نوآموز (جدیدترین اول)
  static Future<List<ReportCard>> forStudent(String studentName) async {
    final all = await _all();
    final list = all.where((c) => c.studentName == studentName).toList();
    list.sort((a, b) => b.term.compareTo(a.term));
    return list;
  }

  static Future<void> save(ReportCard card) async {
    final all = await _all();
    all.removeWhere((c) => c.studentName == card.studentName && c.term == card.term);
    all.add(card);
    await _persist();
  }
}

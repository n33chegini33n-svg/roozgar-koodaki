import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/jalali.dart';
import 'school_classes.dart';
import 'user_directory.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup;
import '../services/backend.dart';
import '../services/backend_directory.dart';

class AttendanceRecord {
  final String id;
  final String studentName;
  final String className;
  final String status; // 'حاضر 🟢', 'غایب 🔴', 'مرخصی 🟡'
  final String date; // e.g. '1403/12/15'
  final int year; // e.g. 1403 (supports up to 8 years retention)
  final String month; // e.g. 'اسفند'
  final String week; // e.g. 'هفته سوم'
  final String day; // e.g. 'پنجشنبه'
  final String teacherName; // Name of teacher/staff who recorded attendance
  final int timestamp;

  AttendanceRecord({
    required this.id,
    required this.studentName,
    required this.className,
    required this.status,
    required this.date,
    required this.year,
    required this.month,
    required this.week,
    required this.day,
    required this.teacherName,
    required this.timestamp,
  });

  AttendanceRecord copyWith({String? status}) => AttendanceRecord(
        id: id,
        studentName: studentName,
        className: className,
        status: status ?? this.status,
        date: date,
        year: year,
        month: month,
        week: week,
        day: day,
        teacherName: teacherName,
        timestamp: timestamp,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentName': studentName,
        'className': className,
        'status': status,
        'date': date,
        'year': year,
        'month': month,
        'week': week,
        'day': day,
        'teacherName': teacherName,
        'timestamp': timestamp,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'] ?? '',
        studentName: json['studentName'] ?? '',
        className: normalizeClassName(((json['className']) ?? '').toString()),
        status: json['status'] ?? 'حاضر 🟢',
        date: json['date'] ?? '',
        year: json['year'] ?? 1403,
        month: json['month'] ?? 'فروردین',
        week: json['week'] ?? 'هفته اول',
        day: json['day'] ?? 'شنبه',
        teacherName: json['teacherName'] ?? 'خانم رضایی (مربی)',
        timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      );
}

// تبدیل JSON سنگین در isolate جدا (UI را قفل نمی‌کند)
List<dynamic> _decodeRecords(String jsonStr) => jsonDecode(jsonStr) as List<dynamic>;
String _encodeRecords(List<Map<String, dynamic>> maps) => jsonEncode(maps);

/// تبدیل برچسب‌های نمایشی به کد دیتابیس و برعکس
class AttendanceStatusCodec {
  static String toCode(String label) {
    if (label.contains('غایب')) return 'absent';
    if (label.contains('تأخیر')) return 'late';
    if (label.contains('مرخصی')) return 'excused';
    return 'present';
  }

  static String toLabel(String code) {
    switch (code) {
      case 'absent':
        return 'غایب 🔴';
      case 'late':
        return 'تأخیر 🟡';
      case 'excused':
        return 'مرخصی 🟡';
      default:
        return 'حاضر 🟢';
    }
  }
}

class AttendanceArchiveService {
  static const String _storageKey = 'manager_attendance_archive_8years';

  // کش حافظه: بعد از بار اول دیگر هر بار کل آرشیو از دیسک خوانده نمی‌شود
  static List<AttendanceRecord>? _cache;

  /// همهٔ رکوردها (جدیدترین اول). [forceReload] کش را دور می‌زند.
  static void clearCache() => _cache = null;

  // ---------------- حالت سرور ----------------
  static const String _sel = 'id, day, status, created_at, students(full_name), classes(name), profiles(full_name)';

  static String _nameOf(dynamic v) => v is Map && v['full_name'] is String ? v['full_name'] as String : '';

  static AttendanceRecord _fromServer(Map<String, dynamic> r) {
    final d = DateTime.parse(r['day'] as String);
    final j = JalaliDate.fromDateTime(d);
    final cls = r['classes'];
    return AttendanceRecord(
      id: r['id'] as String,
      studentName: _nameOf(r['students']),
      className: normalizeClassName(cls is Map && cls['name'] is String ? cls['name'] as String : ''),
      status: AttendanceStatusCodec.toLabel(r['status'] as String),
      date: j.formatted,
      year: j.year,
      month: j.monthName,
      week: j.weekName,
      day: j.weekdayName,
      teacherName: _nameOf(r['profiles']),
      timestamp: DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch,
    );
  }

  static Future<List<AttendanceRecord>> _serverRecords(bool force) async {
    if (_cache != null && !force) return _cache!;
    final out = <AttendanceRecord>[];
    for (var from = 0; from < 20000; from += 1000) {
      final rows = await Backend.client
          .from('attendance_records')
          .select(_sel)
          .order('day', ascending: false)
          .order('created_at', ascending: false)
          .range(from, from + 999);
      out.addAll(rows.map((e) => _fromServer(Map<String, dynamic>.from(e))));
      if (rows.length < 1000) break;
    }
    return _cache = out;
  }

  static Future<List<AttendanceRecord>> _serverRecordsFor(String className, String date) async {
    await ServerDirectory.ensureLoaded();
    final cid = ServerDirectory.classId(className);
    if (cid == null) return [];
    final p = date.split('/');
    final g = JalaliDate.toGregorian(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    final rows = await Backend.client
        .from('attendance_records')
        .select(_sel)
        .eq('class_id', cid)
        .eq('day', JalaliDate.isoDay(g));
    return rows.map((e) => _fromServer(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> _serverAdd(List<AttendanceRecord> newRecords) async {
    await ServerDirectory.ensureLoaded();
    final rows = <Map<String, dynamic>>[];
    for (final r in newRecords) {
      final sid = ServerDirectory.studentId(r.studentName, r.className);
      final cid = ServerDirectory.classId(r.className);
      if (sid == null || cid == null) {
        throw Exception('نوآموز «${r.studentName}» در سرور پیدا نشد');
      }
      rows.add({
        'student_id': sid,
        'class_id': cid,
        'day': JalaliDate.isoDay(DateTime.fromMillisecondsSinceEpoch(r.timestamp)),
        'status': AttendanceStatusCodec.toCode(r.status),
      });
    }
    try {
      await Backend.client.from('attendance_records').insert(rows);
    } on sup.PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('حضور و غیاب امروز قبلاً ثبت شده است');
      throw Exception('ثبت در سرور انجام نشد: ${e.message}');
    }
    _cache = null;
  }

  static Future<bool> _serverUpdate(String recordId, String newStatus) async {
    try {
      final res = await Backend.client
          .from('attendance_records')
          .update({'status': AttendanceStatusCodec.toCode(newStatus)})
          .eq('id', recordId)
          .select('id');
      if (res.isEmpty) return false; // RLS: فقط مدیر/ادمین اجازهٔ اصلاح مستقیم دارند
      _cache = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<AttendanceRecord>> getRecords({bool forceReload = false}) async {
    if (Backend.ready) return _serverRecords(forceReload);
    if (_cache != null && !forceReload) return _cache!;

    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      // داده نمونه فقط برای نسخهٔ توسعه؛ بعد از اتصال به سرور حذف شود
      final initialData = _generateInitialSampleData(await UserDirectory.byRole('student'));
      await saveRecords(initialData);
      return _cache!;
    }
    try {
      final decoded = await compute(_decodeRecords, jsonStr);
      _cache = decoded
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // به‌جای حذف بی‌صدای آرشیو، فایل خراب را دست‌نخورده نگه می‌داریم
      _cache = [];
    }
    return _cache!;
  }

  /// ذخیرهٔ کل لیست (یک بار نوشتن)
  static Future<void> saveRecords(List<AttendanceRecord> records) async {
    _cache = records;
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr =
        await compute(_encodeRecords, records.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  /// رکوردهای ثبت‌شدهٔ یک کلاس در یک تاریخ (برای تشخیص «قفل‌بودن» حضور و غیاب)
  static Future<List<AttendanceRecord>> recordsFor(String className, String date) async {
    if (Backend.ready) return _serverRecordsFor(className, date);
    final all = await getRecords();
    return all.where((r) => sameClass(r.className, className) && r.date == date).toList();
  }

  /// تغییر وضعیت یک رکورد قفل‌شده؛ فقط باید بعد از تأیید ناظم/مدیر صدا زده شود.
  static Future<bool> updateStatus(String recordId, String newStatus) async {
    if (Backend.ready) return _serverUpdate(recordId, newStatus);
    final records = List<AttendanceRecord>.from(await getRecords());
    final i = records.indexWhere((r) => r.id == recordId);
    if (i < 0) return false;
    records[i] = records[i].copyWith(status: newStatus);
    await saveRecords(records);
    return true;
  }

  /// افزودن یک رکورد
  static Future<void> addRecord(AttendanceRecord record) => addRecords([record]);

  /// افزودن چند رکورد با «فقط یک بار» خواندن و نوشتن
  /// (قبلاً برای هر نوآموز یک بار کل آرشیو خوانده و نوشته می‌شد)
  static Future<void> addRecords(List<AttendanceRecord> newRecords) async {
    if (newRecords.isEmpty) return;
    if (Backend.ready) return _serverAdd(newRecords);
    final records = List<AttendanceRecord>.from(await getRecords());
    records.insertAll(0, newRecords); // جدیدترین اول
    await saveRecords(records);
  }

  /// داده نمونهٔ چندساله از فهرست واقعی نوآموزان (فقط برای نسخهٔ نمایشی)
  static List<AttendanceRecord> _generateInitialSampleData(List<UserModel> studentUsers) {
    final List<AttendanceRecord> list = [];
    final students = studentUsers.isEmpty
        ? [UserModel(id: 'x', name: 'نوآموز نمونه', role: 'student', className: kClassNames.first, phone: '')]
        : studentUsers;
    final today = JalaliDate.now();

    final teachers = ['خانم رضایی', 'آقای محمدی', 'خانم احمدی', 'خانم کریمی'];
    final statuses = ['حاضر 🟢', 'حاضر 🟢', 'حاضر 🟢', 'غایب 🔴', 'مرخصی 🟡'];
    final months = ['مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند', 'فروردین', 'اردیبهشت', 'خرداد'];
    final weeks = ['هفته اول', 'هفته دوم', 'هفته سوم', 'هفته چهارم'];
    final days = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه'];

    int idCounter = 1;
    for (int year = today.year - 5; year <= today.year; year++) {
      for (final month in months) {
        final mi = JalaliDate.monthNames.indexOf(month) + 1;
        if (year == today.year && mi > today.month) continue; // تاریخ آینده ساخته نشود
        for (final week in weeks) {
          for (int i = 0; i < 2; i++) {
            final student = students[(idCounter + i) % students.length];
            list.add(AttendanceRecord(
              id: 'REC-$year-$idCounter',
              studentName: student.name,
              className: normalizeClassName(student.className),
              status: statuses[(idCounter * 7) % statuses.length],
              date: '$year/${mi.toString().padLeft(2, '0')}/${(1 + i * 3 + weeks.indexOf(week) * 6).toString().padLeft(2, '0')}',
              year: year,
              month: month,
              week: week,
              day: days[(idCounter + i) % days.length],
              teacherName: teachers[(idCounter + i) % teachers.length],
              timestamp: DateTime(2020 + (year - 1399), 6, 15).millisecondsSinceEpoch + (idCounter * 100000),
            ));
            idCounter++;
          }
        }
      }
    }
    return list;
  }
}

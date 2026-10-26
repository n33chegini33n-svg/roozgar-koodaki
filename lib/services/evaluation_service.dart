import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/evaluation_feedback_model.dart';
import '../models/permissions.dart';
import 'backend.dart';

/// جدول مورد انتظار: public.evaluation_feedback.
/// یادداشت‌ها فقط برای نویسنده و مدیران در دسترس باشند؛ آمار فقط ستون‌های نمره را می‌خواند.
class EvaluationService {
  const EvaluationService._();

  static const String _table = 'evaluation_feedback';
  static const String _localKey = 'evaluation_feedback_v1';
  static const String _statsColumns =
      'teacher_id, teacher_name, teacher_teaching_score, teacher_communication_score, '
      'teacher_care_score, teacher_progress_score, school_education_score, school_staff_score, '
      'school_nutrition_score, school_environment_score';

  static Future<bool> submitFeedback(EvaluationFeedback feedback) async {
    if (Session.role != AppRole.parent) {
      throw StateError('ثبت نظرسنجی فقط برای حساب والدین مجاز است.');
    }
    final scores = [
      feedback.teacherTeachingScore,
      feedback.teacherCommunicationScore,
      feedback.teacherCareScore,
      feedback.teacherProgressScore,
      feedback.schoolEducationScore,
      feedback.schoolStaffScore,
      feedback.schoolNutritionScore,
      feedback.schoolEnvironmentScore,
    ];
    if (scores.any((score) => score < 1 || score > 5)) {
      throw RangeError('امتیازها باید بین ۱ تا ۵ باشند.');
    }

    if (!Backend.ready) {
      final prefs = await SharedPreferences.getInstance();
      final existing = _decodeLocal(prefs.getString(_localKey));
      final localFeedback = EvaluationFeedback(
        id: feedback.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        parentId: Session.userName,
        studentId: feedback.studentId,
        studentName: feedback.studentName,
        className: feedback.className,
        teacherId: feedback.teacherId,
        teacherName: feedback.teacherName,
        teacherTeachingScore: feedback.teacherTeachingScore,
        teacherCommunicationScore: feedback.teacherCommunicationScore,
        teacherCareScore: feedback.teacherCareScore,
        teacherProgressScore: feedback.teacherProgressScore,
        schoolEducationScore: feedback.schoolEducationScore,
        schoolStaffScore: feedback.schoolStaffScore,
        schoolNutritionScore: feedback.schoolNutritionScore,
        schoolEnvironmentScore: feedback.schoolEnvironmentScore,
        privateNote: feedback.privateNote,
        createdAt: feedback.createdAt,
      );
      await prefs.setString(
        _localKey,
        jsonEncode([...existing.map((item) => item.toJson()), localFeedback.toJson()]),
      );
      return false;
    }

    final user = Backend.client.auth.currentUser;
    if (user == null) throw StateError('برای ارسال نظرسنجی باید وارد حساب شوید.');
    if (!Session.childStudentIds.contains(feedback.studentId)) {
      throw StateError('این فرزند به حساب والد مرتبط نیست.');
    }
    if (feedback.studentId.isEmpty || feedback.teacherId.isEmpty) {
      throw StateError('اطلاعات فرزند یا مربی اختصاصی کامل نیست.');
    }

    final payload = feedback.toJson()
      ..remove('id')
      ..remove('parent_id')
      ..['parent_id'] = user.id;
    await Backend.client.from(_table).insert(payload);
    return true;
  }

  static Future<EvaluationStats> loadEvaluationStats() async {
    if (Session.role != AppRole.admin &&
        Session.role != AppRole.manager &&
        Session.role != AppRole.deputy) {
      throw StateError('اجازهٔ مشاهدهٔ آمار ارزیابی وجود ندارد.');
    }

    final List<EvaluationFeedback> feedback;
    if (Backend.ready) {
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0;; offset += 1000) {
        final page = await Backend.client
            .from(_table)
            .select(_statsColumns)
            .order('created_at', ascending: false)
            .range(offset, offset + 999);
        rows.addAll(page.map((row) => Map<String, dynamic>.from(row)));
        if (page.length < 1000) break;
      }
      feedback = rows.map(EvaluationFeedback.fromJson).toList();
    } else {
      final prefs = await SharedPreferences.getInstance();
      feedback = _decodeLocal(prefs.getString(_localKey));
    }
    return _aggregate(feedback);
  }

  static List<EvaluationFeedback> _decodeLocal(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((item) => EvaluationFeedback.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static EvaluationStats _aggregate(List<EvaluationFeedback> records) {
    if (records.isEmpty) return const EvaluationStats();

    final teacherTotals = <String, (double, int)>{};
    for (final record in records) {
      final teacherName = record.teacherName.trim();
      if (teacherName.isEmpty) continue;
      final average = (record.teacherTeachingScore +
              record.teacherCommunicationScore +
              record.teacherCareScore +
              record.teacherProgressScore) /
          4;
      final current = teacherTotals[teacherName] ?? (0, 0);
      teacherTotals[teacherName] = (current.$1 + average, current.$2 + 1);
    }

    double averageOf(int Function(EvaluationFeedback) value) =>
        records.fold<double>(0, (sum, item) => sum + value(item)) / records.length;

    return EvaluationStats(
      teacherRatings: Map.unmodifiable({
        for (final entry in teacherTotals.entries) entry.key: entry.value.$1 / entry.value.$2,
      }),
      schoolEducationScore: averageOf((item) => item.schoolEducationScore),
      schoolStaffScore: averageOf((item) => item.schoolStaffScore),
      schoolNutritionScore: averageOf((item) => item.schoolNutritionScore),
      schoolEnvironmentScore: averageOf((item) => item.schoolEnvironmentScore),
      responseCount: records.length,
    );
  }
}

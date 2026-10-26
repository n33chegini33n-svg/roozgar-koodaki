class EvaluationFeedback {
  final String? id;
  final String? parentId;
  final String studentId;
  final String studentName;
  final String className;
  final String teacherId;
  final String teacherName;
  final int teacherTeachingScore;
  final int teacherCommunicationScore;
  final int teacherCareScore;
  final int teacherProgressScore;
  final int schoolEducationScore;
  final int schoolStaffScore;
  final int schoolNutritionScore;
  final int schoolEnvironmentScore;
  final String privateNote;
  final DateTime createdAt;
  final String monthKey;
  final int editCount;

  bool get isLocked => editCount >= 1;

  const EvaluationFeedback({
    this.id,
    this.parentId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.teacherTeachingScore,
    required this.teacherCommunicationScore,
    required this.teacherCareScore,
    required this.teacherProgressScore,
    required this.schoolEducationScore,
    required this.schoolStaffScore,
    required this.schoolNutritionScore,
    required this.schoolEnvironmentScore,
    this.privateNote = '',
    required this.createdAt,
    this.monthKey = '',
    this.editCount = 0,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (parentId != null) 'parent_id': parentId,
        'student_id': studentId,
        'student_name': studentName,
        'class_name': className,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'teacher_teaching_score': teacherTeachingScore,
        'teacher_communication_score': teacherCommunicationScore,
        'teacher_care_score': teacherCareScore,
        'teacher_progress_score': teacherProgressScore,
        'school_education_score': schoolEducationScore,
        'school_staff_score': schoolStaffScore,
        'school_nutrition_score': schoolNutritionScore,
        'school_environment_score': schoolEnvironmentScore,
        'private_note': privateNote,
        'created_at': createdAt.toUtc().toIso8601String(),
        'month_key': monthKey,
        'edit_count': editCount,
      };

  factory EvaluationFeedback.fromJson(Map<String, dynamic> json) => EvaluationFeedback(
        id: json['id']?.toString(),
        parentId: json['parent_id']?.toString(),
        studentId: json['student_id']?.toString() ?? '',
        studentName: json['student_name']?.toString() ?? '',
        className: json['class_name']?.toString() ?? '',
        teacherId: json['teacher_id']?.toString() ?? '',
        teacherName: json['teacher_name']?.toString() ?? '',
        teacherTeachingScore: _score(json['teacher_teaching_score']),
        teacherCommunicationScore: _score(json['teacher_communication_score']),
        teacherCareScore: _score(json['teacher_care_score']),
        teacherProgressScore: _score(json['teacher_progress_score']),
        schoolEducationScore: _score(json['school_education_score']),
        schoolStaffScore: _score(json['school_staff_score']),
        schoolNutritionScore: _score(json['school_nutrition_score']),
        schoolEnvironmentScore: _score(json['school_environment_score']),
        privateNote: json['private_note']?.toString() ?? '',
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
        monthKey: json['month_key']?.toString() ?? '',
        editCount: json['edit_count'] is num ? (json['edit_count'] as num).toInt() : int.tryParse('${json['edit_count'] ?? ''}') ?? 0,
      );

  EvaluationFeedback copyWith({
    String? id,
    String? parentId,
    String? studentId,
    String? studentName,
    String? className,
    String? teacherId,
    String? teacherName,
    int? teacherTeachingScore,
    int? teacherCommunicationScore,
    int? teacherCareScore,
    int? teacherProgressScore,
    int? schoolEducationScore,
    int? schoolStaffScore,
    int? schoolNutritionScore,
    int? schoolEnvironmentScore,
    String? privateNote,
    DateTime? createdAt,
    String? monthKey,
    int? editCount,
  }) => EvaluationFeedback(
        id: id ?? this.id,
        parentId: parentId ?? this.parentId,
        studentId: studentId ?? this.studentId,
        studentName: studentName ?? this.studentName,
        className: className ?? this.className,
        teacherId: teacherId ?? this.teacherId,
        teacherName: teacherName ?? this.teacherName,
        teacherTeachingScore: teacherTeachingScore ?? this.teacherTeachingScore,
        teacherCommunicationScore: teacherCommunicationScore ?? this.teacherCommunicationScore,
        teacherCareScore: teacherCareScore ?? this.teacherCareScore,
        teacherProgressScore: teacherProgressScore ?? this.teacherProgressScore,
        schoolEducationScore: schoolEducationScore ?? this.schoolEducationScore,
        schoolStaffScore: schoolStaffScore ?? this.schoolStaffScore,
        schoolNutritionScore: schoolNutritionScore ?? this.schoolNutritionScore,
        schoolEnvironmentScore: schoolEnvironmentScore ?? this.schoolEnvironmentScore,
        privateNote: privateNote ?? this.privateNote,
        createdAt: createdAt ?? this.createdAt,
        monthKey: monthKey ?? this.monthKey,
        editCount: editCount ?? this.editCount,
      );

  static int _score(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

/// فقط میانگین‌ها و تعداد پاسخ‌ها؛ یادداشت محرمانه عمداً در آمار قرار نمی‌گیرد.
class EvaluationStats {
  final Map<String, double> teacherRatings;
  final double? schoolEducationScore;
  final double? schoolStaffScore;
  final double? schoolNutritionScore;
  final double? schoolEnvironmentScore;
  final int responseCount;

  const EvaluationStats({
    this.teacherRatings = const {},
    this.schoolEducationScore,
    this.schoolStaffScore,
    this.schoolNutritionScore,
    this.schoolEnvironmentScore,
    this.responseCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'teacher_ratings': teacherRatings,
        'school_education_score': schoolEducationScore,
        'school_staff_score': schoolStaffScore,
        'school_nutrition_score': schoolNutritionScore,
        'school_environment_score': schoolEnvironmentScore,
        'response_count': responseCount,
      };

  factory EvaluationStats.fromJson(Map<String, dynamic> json) {
    final rawRatings = json['teacher_ratings'];
    return EvaluationStats(
      teacherRatings: rawRatings is Map
          ? rawRatings.map((key, value) => MapEntry('$key', value is num ? value.toDouble() : double.tryParse('$value') ?? 0))
          : const {},
      schoolEducationScore: _optionalScore(json['school_education_score']),
      schoolStaffScore: _optionalScore(json['school_staff_score']),
      schoolNutritionScore: _optionalScore(json['school_nutrition_score']),
      schoolEnvironmentScore: _optionalScore(json['school_environment_score']),
      responseCount: json['response_count'] is num ? (json['response_count'] as num).toInt() : 0,
    );
  }

  static double? _optionalScore(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
}

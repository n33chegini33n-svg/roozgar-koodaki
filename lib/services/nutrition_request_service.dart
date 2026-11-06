import '../services/backend.dart';
import '../utils/jalali.dart';

/// درخواست تغییر منو یا حساسیت که منتظر تأیید مدیر است
class NutritionRequest {
  final String id;
  final String kind; // menu | menu_edit | allergy
  final Map<String, dynamic> payload;
  final String status; // pending | approved | rejected
  final DateTime? submittedAt;

  const NutritionRequest({
    required this.id,
    required this.kind,
    required this.payload,
    required this.status,
    required this.submittedAt,
  });

  factory NutritionRequest.fromRow(Map<String, dynamic> r) => NutritionRequest(
        id: '${r['id']}',
        kind: '${r['kind']}',
        payload: Map<String, dynamic>.from((r['payload'] as Map?) ?? {}),
        status: '${r['status']}',
        submittedAt: DateTime.tryParse('${r['submitted_at']}'),
      );
}

/// یک هفته از منو (شروع و پایان و برچسب شمسی)
class MenuWeek {
  final String id;
  final DateTime start;
  final DateTime end;
  final String label;

  const MenuWeek({required this.id, required this.start, required this.end, required this.label});
}

/// همهٔ تماس با سرور منو و درخواست‌های تغذیه اینجاست
class NutritionRequestService {
  static String _today() => JalaliDate.isoDay(DateTime.now());

  static MenuWeek _weekFromRow(Map<String, dynamic> r) => MenuWeek(
        id: '${r['id']}',
        start: DateTime.parse('${r['week_start']}'),
        end: DateTime.parse('${r['week_end']}'),
        label: '${r['label_jalali'] ?? ''}',
      );

  /// هفتهٔ جاری یا پیش‌رو (اولین هفته‌ای که هنوز تمام نشده)
  static Future<MenuWeek?> upcomingWeek() async {
    final rows = await Backend.client
        .from('menu_weeks')
        .select('id, week_start, week_end, label_jalali')
        .gte('week_end', _today())
        .order('week_start', ascending: true)
        .limit(1);
    if (rows.isEmpty) return null;
    return _weekFromRow(Map<String, dynamic>.from(rows.first));
  }

  /// هفته‌های گذشته (بایگانی)
  static Future<List<MenuWeek>> archivedWeeks() async {
    final rows = await Backend.client
        .from('menu_weeks')
        .select('id, week_start, week_end, label_jalali')
        .lt('week_end', _today())
        .order('week_start', ascending: false)
        .limit(60);
    return [for (final r in rows) _weekFromRow(Map<String, dynamic>.from(r))];
  }

  /// وعده‌های یک هفته به شکل «روز|وعده» ← متن
  static Future<Map<String, String>> weekItems(String weekId) async {
    final rows = await Backend.client
        .from('menu_week_items')
        .select('day, meal, content')
        .eq('week_id', weekId);
    final out = <String, String>{};
    for (final r in rows) {
      out['${r['day']}|${r['meal']}'] = '${r['content'] ?? ''}';
    }
    return out;
  }

  /// آشپز: پیشنهاد یک هفتهٔ کامل
  static Future<void> submitMenu({
    required String weekStart,
    required String label,
    required Map<String, Map<String, String>> menu,
  }) async {
    await Backend.client.rpc('submit_nutrition_request', params: {
      'p_kind': 'menu',
      'p_payload': {'week_start': weekStart, 'label': label, 'menu': menu},
    });
  }

  /// آشپز: پیشنهاد تغییر یک وعده در هفتهٔ تأییدشده
  static Future<void> submitMenuEdit({
    required String weekId,
    required String day,
    required String meal,
    required String content,
  }) async {
    await Backend.client.rpc('submit_nutrition_request', params: {
      'p_kind': 'menu_edit',
      'p_payload': {'week_id': weekId, 'day': day, 'meal': meal, 'content': content},
    });
  }

  /// مدیر: ثبت مستقیم یک هفتهٔ کامل
  static Future<void> managerCreateWeek({
    required String weekStart,
    required String label,
    required Map<String, Map<String, String>> menu,
  }) async {
    await Backend.client.rpc('manager_create_menu_week', params: {
      'p_week_start': weekStart,
      'p_label': label,
      'p_menu': menu,
    });
  }

  /// مدیر: ویرایش مستقیم یک وعده
  static Future<void> managerEditItem({
    required String weekId,
    required String day,
    required String meal,
    required String content,
  }) async {
    await Backend.client.rpc('manager_edit_menu_item', params: {
      'p_week_id': weekId,
      'p_day': day,
      'p_meal': meal,
      'p_content': content,
    });
  }

  /// مدیر: حذف یک هفتهٔ بایگانی‌شده
  static Future<void> deleteWeek(String weekId) async {
    await Backend.client.rpc('delete_menu_week', params: {'p_week_id': weekId});
  }

  static Future<void> submitAllergyAdd({
    required String studentId,
    required String allergen,
    required String severity,
    required String notes,
  }) async {
    await Backend.client.rpc('submit_nutrition_request', params: {
      'p_kind': 'allergy',
      'p_payload': {
        'action': 'add',
        'student_id': studentId,
        'allergen': allergen,
        'severity': severity,
        'notes': notes,
      },
    });
  }

  static Future<void> submitAllergyRemove(String allergyId) async {
    await Backend.client.rpc('submit_nutrition_request', params: {
      'p_kind': 'allergy',
      'p_payload': {'action': 'remove', 'allergy_id': allergyId},
    });
  }

  /// درخواست‌های در انتظار (برای مدیر)
  static Future<List<NutritionRequest>> pending() async {
    final rows = await Backend.client
        .from('nutrition_requests')
        .select('id, kind, payload, status, submitted_at')
        .eq('status', 'pending')
        .order('submitted_at', ascending: false);
    return rows.map<NutritionRequest>((r) => NutritionRequest.fromRow(Map<String, dynamic>.from(r))).toList();
  }

  /// سوابق درخواست‌های خود آشپز
  static Future<List<NutritionRequest>> mine() async {
    final uid = Backend.client.auth.currentUser!.id;
    final rows = await Backend.client
        .from('nutrition_requests')
        .select('id, kind, payload, status, submitted_at')
        .eq('submitted_by', uid)
        .order('submitted_at', ascending: false)
        .limit(30);
    return rows.map<NutritionRequest>((r) => NutritionRequest.fromRow(Map<String, dynamic>.from(r))).toList();
  }

  static Future<void> decide({required String id, required bool approve, String note = ''}) async {
    await Backend.client.rpc('decide_nutrition_request', params: {
      'p_id': id,
      'p_approve': approve,
      'p_note': note,
    });
  }
}

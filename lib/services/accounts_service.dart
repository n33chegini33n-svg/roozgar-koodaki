import 'backend.dart';

/// مقطع‌های کلاس و نوآموز
const List<String> kClassGrades = [
  'مهدکودک',
  'پیش‌دبستانی',
  'اول دبستان',
  'دوم دبستان',
  'سوم دبستان',
  'چهارم دبستان',
  'پنجم دبستان',
  'ششم دبستان',
];

class SchoolClass {
  final String id;
  final String name;
  final String grade;
  final bool active;

  const SchoolClass({
    required this.id,
    required this.name,
    required this.grade,
    required this.active,
  });

  factory SchoolClass.fromRow(Map<String, dynamic> r) => SchoolClass(
        id: '${r['id']}',
        name: '${r['name'] ?? ''}',
        grade: '${r['grade'] ?? ''}',
        active: r['active'] != false,
      );

  String get label => grade.isEmpty ? name : '$name • $grade';
}

/// یک نوآموز از روی پروندهٔ ثبت‌نام ارسال‌شده
class RegistrationStudent {
  final String studentId;
  final String name;
  final String grade;
  final String nationalCode;
  final String phones;
  final String status;

  const RegistrationStudent({
    required this.studentId,
    required this.name,
    required this.grade,
    required this.nationalCode,
    required this.phones,
    required this.status,
  });

  factory RegistrationStudent.fromRow(Map<String, dynamic> r) {
    final raw = r['data'];
    final d = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    String v(String k) => '${d[k] ?? ''}'.trim();

    final full = '${v('نام نوآموز')} ${v('نام خانوادگی')}'.trim();
    final name = full.isNotEmpty ? full : '${r['student_name'] ?? 'بدون نام'}';
    final phones = [v('شماره همراه اصلی پدر'), v('شماره همراه اصلی مادر')]
        .where((e) => e.isNotEmpty)
        .map(Backend.latinDigits)
        .join(' ');

    return RegistrationStudent(
      studentId: '${r['student_id']}',
      name: name,
      grade: v('مقطع تحصیلی نوآموز'),
      nationalCode: Backend.latinDigits(v('کد ملی نوآموز')),
      phones: phones,
      status: '${r['status'] ?? ''}',
    );
  }

  String get statusLabel => status == 'approved' ? 'تأیید شده' : 'ارسال شده';

  /// متنی که جستجو روی آن انجام می‌شود (نام، کد ملی، شمارهٔ ولی، مقطع)
  String get searchText => Backend.latinDigits('$name $nationalCode $phones $grade').toLowerCase();
}

class AccountsService {
  /// فقط کلاس‌های فعال (برای فرم‌ها)
  static Future<List<SchoolClass>> activeClasses() async {
    final rows = await Backend.client
        .from('classes')
        .select('id, name, grade, active')
        .eq('active', true)
        .order('name');
    return rows.map<SchoolClass>((r) => SchoolClass.fromRow(Map<String, dynamic>.from(r))).toList();
  }

  /// همهٔ کلاس‌ها (برای صفحهٔ مدیریت کلاس‌ها)
  static Future<List<SchoolClass>> allClasses() async {
    final rows = await Backend.client
        .from('classes')
        .select('id, name, grade, active')
        .order('name');
    return rows.map<SchoolClass>((r) => SchoolClass.fromRow(Map<String, dynamic>.from(r))).toList();
  }

  /// ساخت کلاس (id = null) یا ویرایش کلاس موجود
  static Future<void> saveClass({
    String? id,
    required String name,
    required String grade,
    required bool active,
  }) async {
    final data = {
      'name': name,
      'grade': grade,
      'active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await Backend.client.from('classes').insert(data);
    } else {
      await Backend.client.from('classes').update(data).eq('id', id);
    }
  }

  /// نوآموزانی که پروندهٔ ثبت‌نام ارسال‌شده یا تأییدشده دارند
  static Future<List<RegistrationStudent>> registeredStudents() async {
    final rows = await Backend.client
        .from('registration_records')
        .select('student_id, status, student_name, data')
        .eq('is_deleted', false)
        .not('student_id', 'is', null)
        .inFilter('status', ['submitted', 'approved'])
        .order('updated_at', ascending: false)
        .limit(1000);
    return rows
        .map<RegistrationStudent>((r) => RegistrationStudent.fromRow(Map<String, dynamic>.from(r)))
        .toList();
  }
}

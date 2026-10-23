import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audit_log_model.dart';
import 'school_classes.dart';

/// نقش‌های سیستم. «معاون» در مدرسه همان «ناظم» است.
enum AppRole { admin, manager, deputy, teacher, parent, student }

extension AppRoleLabel on AppRole {
  String get label {
    switch (this) {
      case AppRole.admin:
        return 'ادمین سیستم';
      case AppRole.manager:
        return 'مدیر';
      case AppRole.deputy:
        return 'معاون / ناظم';
      case AppRole.teacher:
        return 'مربی / معلم';
      case AppRole.parent:
        return 'ولی';
      case AppRole.student:
        return 'دانش‌آموز';
    }
  }
}

/// دامنهٔ دسترسی: هیچ / فقط مورد خودش (کلاس خودش، فرزند خودش) / همه
enum Scope { none, own, all }

extension ScopeLabel on Scope {
  String labelFor(AppRole role) {
    switch (this) {
      case Scope.none:
        return 'ندارد';
      case Scope.own:
      if (role == AppRole.parent) return 'فرزند خودش';
      if (role == AppRole.student) return 'خودش';
      return 'کلاس خودش';
      case Scope.all:
        return 'همه';
    }
  }
}

/// هر دسترسی یک «کار» مشخص است
enum Perm {
  // آموزشی
  recordAttendance,
  requestAttendanceEdit,
  assignPoints,
  sendParentAnnouncement,
  // نظارت
  viewAttendance,
  approveAttendanceEdit,
  exportReports,
  viewHealthRecords,
  viewAuditLog,
  // مدیریتی
  manageUsers,
  viewFinancial,
  sendBroadcast,
  approveRequests,
  manageNutrition,
  managePlanning,
  manageHomework,
  viewHomework,
  viewPlans,
  // پیام خصوصی و کارنامه
  sendPrivateMessage,
  reviewPrivateMessages,
  viewReportCard,
  manageReportCard,
  // فقط مدیر و ادمین (در صفحهٔ تنظیمات نمایش داده نمی‌شود)
  managePermissions,
  // فقط ادمین سیستم
  manageAppSettings,
}

class PermInfo {
  final String title;
  final String description;
  final IconData icon;
  final String group;
  final List<Scope> scopes; // دامنه‌هایی که برای این دسترسی معنا دارند
  const PermInfo(this.title, this.description, this.icon, this.group, this.scopes);
}

const List<Scope> _noneAll = [Scope.none, Scope.all];
const List<Scope> _noneOwnAll = [Scope.none, Scope.own, Scope.all];

const Map<Perm, PermInfo> kPermInfo = {
  Perm.recordAttendance: PermInfo('ثبت حضور و غیاب', 'ثبت روزانه؛ بعد از ثبت، رکورد قفل می‌شود', Icons.how_to_reg_rounded, 'آموزشی', _noneOwnAll),
  Perm.requestAttendanceEdit: PermInfo('درخواست اصلاح حضور و غیاب', 'ارسال درخواست اصلاح (با دلیل) برای رکورد قفل‌شده', Icons.edit_note_rounded, 'آموزشی', _noneOwnAll),
  Perm.assignPoints: PermInfo('امتیاز و رفتار', 'ثبت امتیاز مثبت و موارد نیازمند تلاش', Icons.stars_rounded, 'آموزشی', _noneOwnAll),
  Perm.sendParentAnnouncement: PermInfo('اطلاعیه برای اولیا', 'ارسال پیام به والدین', Icons.campaign_rounded, 'آموزشی', _noneOwnAll),
  Perm.viewAttendance: PermInfo('مشاهدهٔ بایگانی حضور و غیاب', 'فقط‌خواندنی', Icons.inventory_2_rounded, 'نظارت', _noneOwnAll),
  Perm.approveAttendanceEdit: PermInfo('تأیید اصلاح حضور و غیاب', 'تأیید یا رد درخواست اصلاح رکورد قفل‌شده', Icons.rule_rounded, 'نظارت', _noneAll),
  Perm.exportReports: PermInfo('خروجی اکسل و PDF', 'دریافت گزارش از سیستم', Icons.file_download_rounded, 'نظارت', _noneOwnAll),
  Perm.viewHealthRecords: PermInfo('پروندهٔ سلامت', 'حساسیت‌ها و واکسیناسیون برای ایمنی کودک', Icons.health_and_safety_rounded, 'نظارت', _noneOwnAll),
  Perm.viewAuditLog: PermInfo('گزارش تغییرات', 'چه کسی، چه زمانی، چه چیزی را تغییر داد', Icons.history_rounded, 'نظارت', _noneAll),
  Perm.manageUsers: PermInfo('مدیریت کاربران', 'ثبت‌نام و ویرایش نوآموز، والدین و کادر', Icons.manage_accounts_rounded, 'مدیریتی', _noneAll),
  Perm.viewFinancial: PermInfo('امور مالی', 'شهریه، پرداخت‌ها و گزارش مالی', Icons.account_balance_wallet_rounded, 'مدیریتی', _noneAll),
  Perm.sendBroadcast: PermInfo('بخشنامه به همه', 'پیام به تمام والدین و کادر', Icons.send_rounded, 'مدیریتی', _noneAll),
  Perm.approveRequests: PermInfo('تأیید درخواست‌ها', 'مرخصی، ثبت‌نام و موارد مشابه', Icons.fact_check_rounded, 'مدیریتی', _noneAll),
  Perm.manageHomework: PermInfo('تعریف تکلیف', 'تعریف و حذف تکلیف کلاس', Icons.assignment_rounded, 'آموزشی', _noneOwnAll),
  Perm.viewHomework: PermInfo('مشاهدهٔ تکالیف', 'دیدن تکالیف و علامت‌زدن انجام‌شدن', Icons.menu_book_rounded, 'نظارت', _noneOwnAll),
  Perm.viewPlans: PermInfo('مشاهدهٔ برنامه‌های آموزشی', 'برنامه‌های آموزشی ثبت‌شدهٔ کلاس', Icons.event_note_rounded, 'نظارت', _noneOwnAll),
  Perm.managePlanning: PermInfo('برنامه‌ریزی آموزشی', 'ثبت برنامهٔ آموزشی کلاس‌ها', Icons.menu_book_rounded, 'مدیریتی', _noneAll),
  Perm.manageNutrition: PermInfo('تغذیه و برنامهٔ غذایی', 'منو و حساسیت‌های غذایی', Icons.restaurant_rounded, 'مدیریتی', _noneAll),
  Perm.sendPrivateMessage: PermInfo('پیام خصوصی به ولی', 'گفتگوی خصوصی معلم و ولی دربارهٔ یک نوآموز', Icons.lock_rounded, 'آموزشی', _noneOwnAll),
  Perm.reviewPrivateMessages: PermInfo('بازبینی پیام‌های خصوصی', 'فقط با ثبت دلیل؛ هر بازبینی در گزارش تغییرات ثبت می‌شود', Icons.policy_rounded, 'نظارت', _noneAll),
  Perm.viewReportCard: PermInfo('مشاهدهٔ کارنامه', 'کارنامهٔ توصیفی نوآموز', Icons.workspace_premium_rounded, 'نظارت', _noneOwnAll),
  Perm.manageReportCard: PermInfo('ثبت کارنامه', 'ثبت و ویرایش ارزشیابی توصیفی', Icons.edit_note_rounded, 'آموزشی', _noneOwnAll),
};

/// مقدار پیش‌فرض. دسترسی ثبت‌نشده یعنی Scope.none
const Map<AppRole, Map<Perm, Scope>> _defaults = {
  // ادمین سیستم: صاحب نرم‌افزار؛ همه چیز + تنظیمات برنامه و اشتراک (ثابت)
  AppRole.admin: {
    Perm.recordAttendance: Scope.all,
    Perm.requestAttendanceEdit: Scope.all,
    Perm.assignPoints: Scope.all,
    Perm.sendParentAnnouncement: Scope.all,
    Perm.viewAttendance: Scope.all,
    Perm.approveAttendanceEdit: Scope.all,
    Perm.exportReports: Scope.all,
    Perm.viewHealthRecords: Scope.all,
    Perm.viewAuditLog: Scope.all,
    Perm.manageUsers: Scope.all,
    Perm.viewFinancial: Scope.all,
    Perm.sendBroadcast: Scope.all,
    Perm.approveRequests: Scope.all,
    Perm.manageNutrition: Scope.all,
    Perm.managePlanning: Scope.all,
    Perm.manageHomework: Scope.all,
    Perm.viewHomework: Scope.all,
    Perm.viewPlans: Scope.all,
    Perm.reviewPrivateMessages: Scope.all,
    Perm.viewReportCard: Scope.all,
    Perm.manageReportCard: Scope.all,
    Perm.managePermissions: Scope.all,
    Perm.manageAppSettings: Scope.all,
  },
  AppRole.manager: {
    Perm.recordAttendance: Scope.all,
    Perm.requestAttendanceEdit: Scope.all,
    Perm.assignPoints: Scope.all,
    Perm.sendParentAnnouncement: Scope.all,
    Perm.viewAttendance: Scope.all,
    Perm.approveAttendanceEdit: Scope.all,
    Perm.exportReports: Scope.all,
    Perm.viewHealthRecords: Scope.all,
    Perm.viewAuditLog: Scope.all,
    Perm.manageUsers: Scope.all,
    Perm.viewFinancial: Scope.all,
    Perm.sendBroadcast: Scope.all,
    Perm.approveRequests: Scope.all,
    Perm.manageNutrition: Scope.all,
    Perm.managePlanning: Scope.all,
    Perm.manageHomework: Scope.all,
    Perm.viewHomework: Scope.all,
    Perm.viewPlans: Scope.all,
    Perm.reviewPrivateMessages: Scope.all,
    Perm.viewReportCard: Scope.all,
    Perm.manageReportCard: Scope.all,
    Perm.managePermissions: Scope.all,
  },
  AppRole.deputy: {
    Perm.recordAttendance: Scope.all,
    Perm.assignPoints: Scope.all,
    Perm.sendParentAnnouncement: Scope.all,
    Perm.viewAttendance: Scope.all,
    Perm.approveAttendanceEdit: Scope.all,
    Perm.exportReports: Scope.all,
    Perm.viewHealthRecords: Scope.all,
    Perm.sendBroadcast: Scope.all,
    Perm.approveRequests: Scope.all,
    Perm.manageNutrition: Scope.all,
    Perm.managePlanning: Scope.all,
    Perm.manageHomework: Scope.all,
    Perm.viewHomework: Scope.all,
    Perm.viewPlans: Scope.all,
    Perm.viewReportCard: Scope.all,
  },
  AppRole.teacher: {
    Perm.recordAttendance: Scope.own,
    Perm.requestAttendanceEdit: Scope.own,
    Perm.assignPoints: Scope.own,
    Perm.sendParentAnnouncement: Scope.own,
    Perm.viewAttendance: Scope.own,
    Perm.viewHealthRecords: Scope.own,
    Perm.manageHomework: Scope.own,
    Perm.viewHomework: Scope.own,
    Perm.viewPlans: Scope.own,
    Perm.sendPrivateMessage: Scope.own,
    Perm.viewReportCard: Scope.own,
    Perm.manageReportCard: Scope.own,
  },
  // ولی: فقط فرزند خودش؛ ثابت و قابل تغییر نیست
  AppRole.parent: {
    Perm.viewAttendance: Scope.own,
    Perm.viewHealthRecords: Scope.own,
    Perm.viewHomework: Scope.own,
    Perm.viewPlans: Scope.own,
    Perm.viewFinancial: Scope.own,
    Perm.sendPrivateMessage: Scope.own,
    Perm.viewReportCard: Scope.own,
  },
  // دانش‌آموز ورود مستقل دارد، اما مجوز داده‌ای از سمت کلاینت نمی‌گیرد.
  AppRole.student: {},
};

/// نقش‌هایی که مدیر می‌تواند دسترسی‌شان را تغییر دهد
const List<AppRole> kConfigurableRoles = [AppRole.deputy, AppRole.teacher];

/// هویت کاربر واردشده (تا زمان اتصال به سرور، نمونه است)
class Session {
  static AppRole role = AppRole.parent;
  static String userName = '';
  static String className = '';
  static String childName = '';
  static List<String> childStudentIds = [];

  /// پاک‌کردن هویت فعال
  static void reset() {
    role = AppRole.parent;
    userName = '';
    className = '';
    childName = '';
    childStudentIds = [];
  }

  static void signIn(AppRole r) {
    role = r;
    switch (r) {
      case AppRole.admin:
        userName = 'ادمین سیستم';
        break;
      case AppRole.manager:
        userName = 'مدیر';
        break;
      case AppRole.deputy:
        userName = 'معاون';
        break;
      case AppRole.teacher:
        userName = 'خانم رضایی (مربی)';
        break;
      case AppRole.parent:
        userName = 'ولی';
        break;
      case AppRole.student:
        userName = 'دانش‌آموز';
        break;
    }
  }
}

/// مدیریت مرکزی دسترسی‌ها؛ روی دستگاه ذخیره می‌شود.
class PermissionService extends ChangeNotifier {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  static const String _key = 'role_permissions_v2';
  bool _allowLocalOverrides = false;

  bool get allowsLocalOverrides => _allowLocalOverrides;
  final Map<AppRole, Map<Perm, Scope>> _matrix = {
    for (final e in _defaults.entries) e.key: {...e.value},
  };

  Future<void> load({bool allowLocalOverrides = false}) async {
    _allowLocalOverrides = allowLocalOverrides;
    if (!allowLocalOverrides) {
      for (final role in kConfigurableRoles) {
        _matrix[role] = {..._defaults[role]!};
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final role in kConfigurableRoles) {
        final inner = map[role.name];
        if (inner is! Map) continue;
        final parsed = <Perm, Scope>{};
        for (final p in Perm.values) {
          final v = inner[p.name];
          if (v is String) {
            for (final s in Scope.values) {
              if (s.name == v) parsed[p] = s;
            }
          }
        }
        _matrix[role] = parsed;
      }
    } catch (_) {
      // داده خراب: مقادیر پیش‌فرض می‌مانند
    }
  }

  Scope scopeOf(AppRole role, Perm perm) => _matrix[role]?[perm] ?? Scope.none;

  bool can(AppRole role, Perm perm) => scopeOf(role, perm) != Scope.none;

  /// بررسی دسترسی روی یک کلاس مشخص (برای دامنهٔ «کلاس خودش»)
  bool allows(AppRole role, Perm perm, {String? className}) {
    final s = scopeOf(role, perm);
    if (s == Scope.all) return true;
    if (s == Scope.own) return className != null && sameClass(className, Session.className);
    return false;
  }

  Future<void> setScope(AppRole role, Perm perm, Scope scope) async {
    if (!_allowLocalOverrides || !kConfigurableRoles.contains(role)) return;
    final before = scopeOf(role, perm);
    if (before == scope) return;
    _matrix.putIfAbsent(role, () => {})[perm] = scope;
    notifyListeners();
    await _save();
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'تغییر دسترسی',
      details: '${role.label} • ${kPermInfo[perm]?.title}: ${before.labelFor(role)} ← ${scope.labelFor(role)}',
    );
  }

  Future<void> resetToDefaults() async {
    if (!_allowLocalOverrides) return;
    for (final role in kConfigurableRoles) {
      _matrix[role] = {..._defaults[role]!};
    }
    notifyListeners();
    await _save();
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: 'بازگردانی دسترسی‌ها',
      details: 'دسترسی معاون و مربی به حالت پیش‌فرض برگشت',
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        for (final role in kConfigurableRoles)
          role.name: {
            for (final e in (_matrix[role] ?? <Perm, Scope>{}).entries) e.key.name: e.value.name,
          },
      }),
    );
  }
}

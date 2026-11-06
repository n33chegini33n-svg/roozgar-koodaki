import '../models/permissions.dart';
import '../models/user_directory.dart';
import 'backend.dart';
import 'backend_directory.dart';

/// عملیات مدیریتی روی رکوردهای کاربران؛ مجوز نهایی باید در RLS نیز اعمال شود.
class UserAdminService {
  const UserAdminService._();

  static Future<void> updateUser({
    required UserModel previous,
    required String name,
    required String phone,
    required String role,
    required String className,
    List<String> classIds = const [],
  }) async {
    if (!Backend.ready) throw StateError('اتصال سرور آماده نیست.');
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      throw StateError('شما اجازهٔ مدیریت کاربران را ندارید.');
    }
    if (name.trim().isEmpty) throw ArgumentError('نام کاربر نمی‌تواند خالی باشد.');

    await ServerDirectory.ensureLoaded(force: true);
    if (previous.isStudentRecord) {
      if (role != 'student') {
        throw StateError('تغییر نقش دانش‌آموز از این فرم پشتیبانی نمی‌شود.');
      }
      final classId = ServerDirectory.classId(className);
      if (classId == null) throw StateError('کلاس انتخاب‌شده در سرور پیدا نشد.');
      final rows = await Backend.client
          .from('students')
          .update({'full_name': name.trim(), 'class_id': classId})
          .eq('id', previous.id)
          .select('id');
      if (rows.isEmpty) throw StateError('رکورد دانش‌آموز پیدا نشد یا اجازهٔ ویرایش ندارید.');
      return;
    }

    if (role == 'admin') {
      throw StateError('نقش ادمین سیستم از این فرم قابل تعیین نیست.');
    }
    if (role == 'manager' && Session.role != AppRole.admin) {
      throw StateError('فقط ادمین سیستم می‌تواند نقش مدیر را تعیین کند.');
    }

    final payload = <String, dynamic>{
      'full_name': name.trim(),
      'phone': phone.trim(),
      'role': role,
    };
    if (role == 'teacher' || role == 'deputy') {
      if (classIds.isEmpty) throw StateError('حداقل یک کلاس انتخاب کنید.');
      payload['class_id'] = classIds.first;
    } else if (role == 'student') {
      final classId = ServerDirectory.classId(className);
      if (classId == null) throw StateError('کلاس انتخاب‌شده در سرور پیدا نشد.');
      payload['class_id'] = classId;
    } else {
      payload['class_id'] = null;
    }

    final rows = await Backend.client
        .from('profiles')
        .update(payload)
        .eq('id', previous.profileId ?? previous.id)
        .select('id');
    if (rows.isEmpty) throw StateError('پروفایل پیدا نشد یا اجازهٔ ویرایش ندارید.');
    final profileKey = previous.profileId ?? previous.id;
    if (role == 'teacher' || role == 'deputy') {
      // همهٔ کلاس‌های کادر را یکجا جایگزین می‌کنیم
      await Backend.client.from('teacher_classes').delete().eq('profile_id', profileKey);
      await Backend.client.from('teacher_classes').insert([
        for (final id in classIds) {'profile_id': profileKey, 'class_id': id},
      ]);
    } else {
      await Backend.client.from('teacher_classes').delete().eq('profile_id', profileKey);
    }
  }

  /// حذف نرم: رکورد از بین نمی‌رود، فقط علامت حذف و غیرفعال می‌شود.
  static Future<void> deleteUser(UserModel user) async {
    if (!Backend.ready) throw StateError('اتصال سرور آماده نیست.');
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      throw StateError('شما اجازهٔ مدیریت کاربران را ندارید.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    if (user.isStudentRecord) {
      final rows = await Backend.client
          .from('students')
          .update({'is_deleted': true, 'deleted_at': now})
          .eq('id', user.id)
          .select('id');
      if (rows.isEmpty) throw StateError('رکورد دانش‌آموز پیدا نشد یا اجازهٔ حذف ندارید.');
      // حساب ورود متصل به این نوآموز هم غیرفعال شود
      await Backend.client
          .from('profiles')
          .update({'is_deleted': true, 'deleted_at': now, 'active': false})
          .eq('student_id', user.id);
      return;
    }

    final profileId = user.profileId ?? user.id;
    if (profileId == Backend.client.auth.currentUser?.id) {
      throw StateError('نمی‌توانید حساب خودتان را حذف کنید.');
    }
    final rows = await Backend.client
        .from('profiles')
        .update({'is_deleted': true, 'deleted_at': now, 'active': false})
        .eq('id', profileId)
        .select('id');
    if (rows.isEmpty) throw StateError('رکورد کاربر پیدا نشد یا اجازهٔ حذف ندارید.');
  }

  static Future<void> setActive(UserModel user, bool active) async {
    if (!Backend.ready) throw StateError('اتصال سرور آماده نیست.');
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      throw StateError('شما اجازهٔ مدیریت کاربران را ندارید.');
    }
    final profileId = user.profileId;
    if (profileId == null || profileId.isEmpty) {
      throw StateError('برای این رکورد، حسابی در profiles پیدا نشد.');
    }
    final currentUserId = Backend.client.auth.currentUser?.id;
    if (!active && profileId == currentUserId) {
      throw StateError('نمی‌توانید حساب فعالی را که با آن وارد شده‌اید غیرفعال کنید.');
    }
    final rows = await Backend.client
        .from('profiles')
        .update({'active': active})
        .eq('id', profileId)
        .select('id');
    if (rows.isEmpty) throw StateError('وضعیت حساب تغییر نکرد؛ مجوز سرور یا شناسه را بررسی کنید.');
  }
}

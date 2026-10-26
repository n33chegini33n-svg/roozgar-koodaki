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
  }) async {
    if (!Backend.ready) throw StateError('اتصال سرور آماده نیست.');
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      throw StateError('شما اجازهٔ مدیریت کاربران را ندارید.');
    }
    if (name.trim().isEmpty) throw ArgumentError('نام کاربر نمی‌تواند خالی باشد.');

    await ServerDirectory.ensureLoaded(force: true);
    if (previous.role == 'student') {
      if (role != 'student') {
        throw StateError('تغییر نوع حساب دانش‌آموز به حساب پرسنل یا والد از این فرم پشتیبانی نمی‌شود.');
      }
      final classId = ServerDirectory.classId(className);
      if (classId == null) throw StateError('کلاس انتخاب‌شده در سرور پیدا نشد.');
      final rows = await Backend.client
          .from('students')
          .update({'full_name': name.trim(), 'class_id': classId})
          .eq('id', previous.id)
          .select('id');
      if (rows.isEmpty) throw StateError('رکورد دانش‌آموز پیدا نشد یا اجازهٔ ویرایش وجود ندارد.');
      return;
    }

    if (role == 'student') {
      throw StateError('تبدیل حساب والد یا پرسنل به دانش‌آموز از این فرم پشتیبانی نمی‌شود.');
    }
    final payload = <String, dynamic>{
      'full_name': name.trim(),
      'phone': phone.trim(),
      'role': role,
    };
    if (role == 'teacher' || role == 'deputy') {
      final classId = ServerDirectory.classId(className);
      if (classId == null) throw StateError('کلاس انتخاب‌شده در سرور پیدا نشد.');
      payload['class_id'] = classId;
    } else {
      payload['class_id'] = null;
    }
    final rows = await Backend.client
        .from('profiles')
        .update(payload)
        .eq('id', previous.id)
        .select('id');
    if (rows.isEmpty) throw StateError('پروفایل پیدا نشد یا اجازهٔ ویرایش وجود ندارد.');
  }

  static Future<void> deleteUser(UserModel user) async {
    if (!Backend.ready) throw StateError('اتصال سرور آماده نیست.');
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      throw StateError('شما اجازهٔ مدیریت کاربران را ندارید.');
    }
    final table = user.role == 'student' ? 'students' : 'profiles';
    final rows = await Backend.client.from(table).delete().eq('id', user.id).select('id');
    if (rows.isEmpty) throw StateError('رکورد کاربر پیدا نشد یا اجازهٔ حذف وجود ندارد.');
  }
}

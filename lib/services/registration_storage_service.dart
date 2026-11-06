import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sup;

import 'backend.dart';

/// اسناد ثبت‌نام کودکان باید در باکت خصوصی نگهداری شوند.
/// باکت registration-docs و policyهای Storage باید پیش از استفاده در Supabase ساخته شوند.
class RegistrationStorageService {
  const RegistrationStorageService._();

  static const String bucketName = 'registration-docs';

  static Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!Backend.ready) throw StateError('اتصال به سرور برقرار نیست.');
    final user = Backend.client.auth.currentUser;
    if (user == null) throw StateError('برای بارگذاری مدرک باید وارد حساب شوید.');

    final extension = _safeExtension(fileName);
    final path = '${user.id}/registration-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await Backend.client.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: sup.FileOptions(
            contentType: _contentType(extension),
            upsert: false,
          ),
        );
    return path;
  }

  static Future<void> deleteOwnAttachment(String path) async {
    if (!Backend.ready) throw StateError('اتصال به سرور برقرار نیست.');
    final user = Backend.client.auth.currentUser;
    if (user == null || !belongsToCurrentUser(path)) {
      throw StateError('اجازهٔ حذف این پیوست را ندارید.');
    }
    await Backend.client.storage.from(bucketName).remove([path]);
  }

  static bool belongsToCurrentUser(String path) {
    final user = Backend.ready ? Backend.client.auth.currentUser : null;
    return user != null && path.startsWith('${user.id}/');
  }

  static String _safeExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final extension = dot < 0 ? 'jpg' : fileName.substring(dot + 1).toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    if (!allowed.contains(extension)) {
      throw const FormatException('فقط فایل تصویری معتبر قابل بارگذاری است.');
    }
    return extension;
  }

  static String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}

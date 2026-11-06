import 'backend.dart';

class RegistrationAdminService {
  /// تعداد پرونده‌های ثبت‌نامی که هنوز در انتظار بررسی هستند.
  static Future<int> pendingCount() async {
    if (!Backend.ready) return 0;

    final rows = await Backend.client
        .from('registration_records')
        .select('parent_id')
        .inFilter('status', ['submitted', 'pending'])
        .limit(1000);
    return rows.length;
  }

  /// تعداد پرونده‌های در انتظار بررسی که پیوست مدرک دارند و هنوز دیده نشده‌اند.
  static Future<int> pendingAttachmentCount() async {
    if (!Backend.ready) return 0;

    List<dynamic> rows;
    try {
      rows = await Backend.client
          .from('registration_records')
          .select('attachment_url, data, attachment_seen_at')
          .inFilter('status', ['submitted', 'pending'])
          .limit(1000);
    } catch (firstError) {
      try {
        rows = await Backend.client
            .from('registration_records')
            .select('attachment_url, data')
            .inFilter('status', ['submitted', 'pending'])
            .limit(1000);
      } catch (e) {
        throw StateError('شمارش مدارک در انتظار انجام نشد: $e');
      }
    }
    return rows.where((row) {
      if (_hasUnseenAttachment(Map<String, dynamic>.from(row))) return true;
      return false;
    }).length;
  }

  static Future<void> markAttachmentSeen(Map<String, dynamic> record) async {
    if (!Backend.ready) return;
    final recordId = record['id']?.toString().trim() ?? '';
    if (recordId.isEmpty) {
      throw StateError('شناسهٔ یکتای پرونده برای ثبت مشاهدهٔ مدرک لازم است.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final data = record['data'] is Map
        ? Map<String, dynamic>.from(record['data'] as Map)
        : <String, dynamic>{};
    data['__attachment_seen_at'] = now;
    try {
      final updated = await Backend.client.from('registration_records').update({
        'attachment_seen_at': now,
        'data': data,
        'updated_at': now,
      }).eq('id', recordId).select('id');
      if (updated.isEmpty) {
        throw StateError('مشاهدهٔ مدرک در پرونده ذخیره نشد.');
      }
    } catch (e) {
      final updated = await Backend.client.from('registration_records').update({
        'data': data,
        'updated_at': now,
      }).eq('id', recordId).select('id');
      if (updated.isEmpty) {
        throw StateError('مشاهدهٔ مدرک در پرونده ذخیره نشد: $e');
      }
    }
    record['attachment_seen_at'] = now;
    record['data'] = data;
  }

  static bool _hasUnseenAttachment(Map<String, dynamic> row) {
    final attachmentUrl = '${row['attachment_url'] ?? ''}'.trim();
    final rawData = row['data'];
    final data = rawData is Map ? rawData : const <String, dynamic>{};
    final dataAttachment = '${data['لینک/پیوست شناسنامه'] ?? ''}'.trim();
    final hasFile = attachmentUrl.isNotEmpty || dataAttachment.isNotEmpty;
    if (!hasFile) return false;
    final seenColumn = '${row['attachment_seen_at'] ?? ''}'.trim();
    final seenData = '${data['__attachment_seen_at'] ?? ''}'.trim();
    return seenColumn.isEmpty && seenData.isEmpty;
  }
}

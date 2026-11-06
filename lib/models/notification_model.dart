import '../services/backend.dart';

/// یک اعلان یا مورد پیگیری برای یک کاربر
class AppNotice {
  final String id;
  final String title;
  final String body;
  final String kind;
  final String? target; // مقصد: parent_registration | manager_registration
  final bool isRead;
  final DateTime createdAt;

  const AppNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    this.target,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        kind: '${j['kind'] ?? 'info'}',
        target: j['target']?.toString(),
        isRead: j['is_read'] == true,
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// اعلان‌ها و پیگیری‌های کاربر فعلی (RLS فقط اعلان‌های خود کاربر را برمی‌گرداند)
class NotificationService {
  static Future<List<AppNotice>> mine() async {
    if (!Backend.ready) return [];
    final rows = await Backend.client
        .from('notifications')
        .select('id, title, body, kind, target, is_read, created_at')
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) AppNotice.fromJson(Map<String, dynamic>.from(r))];
  }

  static Future<int> unreadCount() async {
    if (!Backend.ready) return 0;
    final rows = await Backend.client.from('notifications').select('id').eq('is_read', false);
    return rows.length;
  }

  static Future<void> markRead(String id) async {
    if (!Backend.ready) return;
    await Backend.client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  static Future<void> markAllRead() async {
    if (!Backend.ready) return;
    final uid = Backend.client.auth.currentUser?.id;
    if (uid == null) return;
    await Backend.client.from('notifications').update({'is_read': true}).eq('user_id', uid).eq('is_read', false);
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import 'audit_log_model.dart';
import 'permissions.dart';
import 'school_classes.dart';

class Audience {
  static const String all = 'all';
  static const String parents = 'parents';
  static const String staff = 'staff';
  static const String classOnly = 'class';
  static String label(String a, [String className = '']) {
    switch (a) {
      case parents: return 'همهٔ والدین';
      case staff: return 'کادر (مربیان و معاونین)';
      case classOnly: return 'والدین $className';
      default: return 'والدین و کادر';
    }
  }
}

class Announcement {
  final String id, title, body, audience, className, sender, senderRole;
  final int createdAt;
  const Announcement({required this.id, required this.title, required this.body, required this.audience, required this.className, required this.sender, required this.senderRole, required this.createdAt});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'audience': audience, 'className': className, 'sender': sender, 'senderRole': senderRole, 'createdAt': createdAt};
  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}', body: '${j['body'] ?? ''}', audience: '${j['audience'] ?? Audience.all}', className: normalizeClassName('${j['className'] ?? ''}'), sender: '${j['sender'] ?? ''}', senderRole: '${j['senderRole'] ?? ''}', createdAt: (j['createdAt'] as num?)?.toInt() ?? 0);

  static Announcement fromServer(Map<String, dynamic> r) {
    final cls = r['classes'];
    return Announcement(id: '${r['id'] ?? ''}', title: '${r['title'] ?? ''}', body: '${r['body'] ?? ''}', audience: '${r['audience'] ?? Audience.all}', className: normalizeClassName(cls is Map ? '${cls['name'] ?? ''}' : ''), sender: 'کادر مدرسه', senderRole: '', createdAt: DateTime.tryParse('${r['created_at']}')?.millisecondsSinceEpoch ?? 0);
  }
}

class AnnouncementService {
  static const String _key = 'announcements_v1';
  static const int _maxItems = 500;
  static List<Announcement>? _cache;

  static Future<List<Announcement>> getAll() async {
    if (Backend.ready) return _serverAll();
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try { return _cache = (jsonDecode(raw) as List).map((e) => Announcement.fromJson(Map<String, dynamic>.from(e as Map))).toList(); } catch (_) { return _cache = []; }
  }

  static Future<List<Announcement>> _serverAll() async {
    final rows = await Backend.client.from('announcements').select('id,title,body,audience,class_id,sender,created_at,classes(name)').order('created_at', ascending: false).limit(_maxItems);
    return rows.map<Announcement>((r) => Announcement.fromServer(Map<String, dynamic>.from(r))).toList();
  }

  static Future<void> send({required String title, required String body, required String audience, String className = ''}) async {
    if (Backend.ready) {
      await ServerDirectory.ensureLoaded();
      final classId = audience == Audience.classOnly ? ServerDirectory.classId(className) : null;
      if (audience == Audience.classOnly && classId == null) throw Exception('کلاس انتخاب‌شده در سرور پیدا نشد');
      await Backend.client.from('announcements').insert({'title': title, 'body': body, 'audience': audience, 'class_id': classId, 'sender': Backend.client.auth.currentUser!.id});
      return;
    }
    final all = await getAll();
    final now = DateTime.now().millisecondsSinceEpoch;
    all.insert(0, Announcement(id: 'ANN-$now', title: title, body: body, audience: audience, className: className, sender: Session.userName, senderRole: Session.role.label, createdAt: now));
    if (all.length > _maxItems) all.removeRange(_maxItems, all.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
    await AuditLogService.log(actor: Session.userName, role: Session.role.label, action: 'ارسال اطلاعیه', details: '«$title» ← ${Audience.label(audience, className)}');
  }

  static Future<List<Announcement>> visibleTo(AppRole role, {String className = ''}) async {
    final all = await getAll();
    switch (role) {
      case AppRole.admin: case AppRole.manager: case AppRole.deputy: return all;
      case AppRole.teacher: return all.where((a) => a.audience == Audience.all || a.audience == Audience.staff || (a.audience == Audience.classOnly && sameClass(a.className, className))).toList();
      case AppRole.parent: return all.where((a) => a.audience == Audience.all || a.audience == Audience.parents || (a.audience == Audience.classOnly && sameClass(a.className, className))).toList();
      case AppRole.student: return all.where((a) => a.audience == Audience.classOnly && sameClass(a.className, className)).toList();
    }
  }
}

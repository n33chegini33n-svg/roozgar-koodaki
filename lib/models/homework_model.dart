import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import 'audit_log_model.dart';
import 'permissions.dart';
import 'school_classes.dart';

class Homework {
  final String id, title, description, due, className, createdBy;
  final int createdAt;
  const Homework({required this.id, required this.title, required this.description, required this.due, required this.className, required this.createdBy, required this.createdAt});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'description': description, 'due': due, 'className': className, 'createdBy': createdBy, 'createdAt': createdAt};
  factory Homework.fromJson(Map<String, dynamic> j) => Homework(id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}', description: '${j['description'] ?? ''}', due: '${j['due'] ?? ''}', className: normalizeClassName('${j['className'] ?? ''}'), createdBy: '${j['createdBy'] ?? ''}', createdAt: (j['createdAt'] as num?)?.toInt() ?? 0);
  factory Homework.fromServer(Map<String, dynamic> r) { final c=r['classes']; return Homework(id: '${r['id']}', title: '${r['title'] ?? ''}', description: '${r['description'] ?? ''}', due: '${r['due'] ?? ''}', className: normalizeClassName(c is Map ? '${c['name'] ?? ''}' : ''), createdBy: 'کادر مدرسه', createdAt: DateTime.tryParse('${r['created_at']}')?.millisecondsSinceEpoch ?? 0); }
}

class HomeworkService {
  static const String _key = 'homework_v1';
  static const String _doneKey = 'homework_done_v1';
  static List<Homework>? _cache;
  static Map<String, List<String>>? _done;

  static Future<List<Homework>> getAll() async {
    if (Backend.ready) return _serverAll();
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance(); final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return _cache = [];
    try { return _cache = (jsonDecode(raw) as List).map((e) => Homework.fromJson(Map<String, dynamic>.from(e as Map))).toList(); } catch (_) { return _cache = []; }
  }
  static Future<List<Homework>> _serverAll() async { final rows=await Backend.client.from('homework').select('id,title,description,due,class_id,created_by,created_at,classes(name)').order('created_at', ascending:false).limit(500); return rows.map<Homework>((r)=>Homework.fromServer(Map<String,dynamic>.from(r))).toList(); }
  static Future<List<Homework>> forClass(String className) async { final all=await getAll(); return all.where((h)=>sameClass(h.className,className)).toList(); }
  static Future<void> _save() async { final prefs=await SharedPreferences.getInstance(); await prefs.setString(_key,jsonEncode(_cache!.map((e)=>e.toJson()).toList())); }
  static Future<void> add(Homework h) async {
    if (Backend.ready) { await ServerDirectory.ensureLoaded(); final cid=ServerDirectory.classId(h.className); if(cid==null) throw Exception('کلاس تکلیف در سرور پیدا نشد'); await Backend.client.from('homework').insert({'title':h.title,'description':h.description,'due':h.due,'class_id':cid,'created_by':Backend.client.auth.currentUser!.id}); return; }
    final all=await getAll(); all.insert(0,h); await _save(); await AuditLogService.log(actor:Session.userName,role:Session.role.label,action:'تعریف تکلیف',details:'${h.className} • ${h.title} • ${h.due}');
  }
  static Future<void> remove(String id) async { if(Backend.ready){await Backend.client.from('homework').delete().eq('id',id);return;} final all=await getAll(); final i=all.indexWhere((h)=>h.id==id); if(i<0)return; final h=all.removeAt(i); await _save(); await AuditLogService.log(actor:Session.userName,role:Session.role.label,action:'حذف تکلیف',details:'${h.className} • ${h.title}'); }
  static Future<String?> _myStudentId() async { await ServerDirectory.ensureLoaded(); return ServerDirectory.studentId(Session.childName, Session.className); }
  static Future<Set<String>> doneIds(String child) async {
    if(Backend.ready){ await ServerDirectory.ensureLoaded(); final sid=ServerDirectory.studentId(child,Session.className); if(sid==null)return {}; final rows=await Backend.client.from('homework_done').select('homework_id').eq('student_id',sid); return rows.map<String>((r)=>'${r['homework_id']}').toSet(); }
    final d=await _loadDone(); return (d[child]??const <String>[]).toSet();
  }
  static Future<void> setDone(String child,String id,bool value) async { if(Backend.ready){final sid=await _myStudentId(); if(sid==null)throw Exception('نوآموز در سرور پیدا نشد'); if(value){await Backend.client.from('homework_done').upsert({'homework_id':id,'student_id':sid});}else{await Backend.client.from('homework_done').delete().eq('homework_id',id).eq('student_id',sid);}return;} final d=await _loadDone(); final list=d.putIfAbsent(child,()=>[]); value?(list.contains(id)?null:list.add(id)):list.remove(id); final prefs=await SharedPreferences.getInstance(); await prefs.setString(_doneKey,jsonEncode(d)); }
  static Future<List<String>> doneBy(String id) async { if(Backend.ready){ final rows=await Backend.client.from('homework_done').select('students(full_name)').eq('homework_id',id); return rows.map<String>((r){final s=r['students'];return s is Map?'${s['full_name']??''}':'';}).where((s)=>s.isNotEmpty).toList(); } final d=await _loadDone(); return [for(final e in d.entries)if(e.value.contains(id))e.key]; }
  static Future<Map<String,List<String>>> _loadDone() async { if(_done!=null)return _done!; final prefs=await SharedPreferences.getInstance(); final raw=prefs.getString(_doneKey); final map=<String,List<String>>{}; if(raw!=null){try{final decoded=jsonDecode(raw) as Map<String,dynamic>;decoded.forEach((k,v)=>map[k]=List<String>.from(v as List));}catch(_){}} return _done=map; }
}

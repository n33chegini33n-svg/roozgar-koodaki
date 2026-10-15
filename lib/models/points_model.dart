import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import '../utils/jalali.dart';
import 'permissions.dart';

class PointEvent {
  final String student, skill, by; final int delta, ts;
  const PointEvent({required this.student,required this.skill,required this.delta,required this.by,required this.ts});
  Map<String,dynamic> toJson()=>{'student':student,'skill':skill,'delta':delta,'by':by,'ts':ts};
  factory PointEvent.fromJson(Map<String,dynamic> j)=>PointEvent(student:'${j['student']??''}',skill:'${j['skill']??''}',delta:(j['delta'] as num?)?.toInt()??0,by:'${j['by']??''}',ts:(j['ts'] as num?)?.toInt()??0);
  factory PointEvent.fromServer(Map<String,dynamic> r){final s=r['students'];return PointEvent(student:s is Map?'${s['full_name']??''}':'',skill:'${r['skill']??''}',delta:(r['delta'] as num?)?.toInt()??0,by:'کادر مدرسه',ts:DateTime.tryParse('${r['created_at']}')?.millisecondsSinceEpoch??0);}
}

class PointsService {
  static const String _totalsKey='points_totals_v1', _eventsKey='points_events_v1'; static const int _maxEvents=500;
  static const Map<String,int> _seed={'آرتین شجاعی':24,'سارا محمدی':18,'علی احمدی':21,'مریم کریمی':30,'کارن رضایی':15};
  static Map<String,int>? _totals; static List<PointEvent>? _events;
  static Future<List<Map<String,dynamic>>> _serverRows(String student) async { await ServerDirectory.ensureLoaded(); final sid=ServerDirectory.studentId(student,Session.className); if(sid==null)return []; final rows=await Backend.client.from('points_events').select('student_id,skill,delta,by_user,created_at,students(full_name)').eq('student_id',sid).order('created_at',ascending:false).limit(_maxEvents); return rows.map<Map<String,dynamic>>((r)=>Map<String,dynamic>.from(r)).toList(); }
  static Future<int> total(String student) async { if(Backend.ready){final rows=await _serverRows(student);return rows.fold<int>(0,(sum,r)=>sum+((r['delta'] as num?)?.toInt()??0));} return (await _loadTotals())[student]??0; }
  static Future<bool> add(String student,int delta,String skill,{String className=''}) async { final cls=className.isEmpty?Session.className:className; if(!PermissionService.instance.allows(Session.role,Perm.assignPoints,className:cls))return false; if(Backend.ready){await ServerDirectory.ensureLoaded();final sid=ServerDirectory.studentId(student,cls);if(sid==null)throw Exception('نوآموز در سرور پیدا نشد');await Backend.client.from('points_events').insert({'student_id':sid,'skill':skill,'delta':delta,'by_user':Backend.client.auth.currentUser!.id});return true;} final totals=await _loadTotals();totals[student]=(totals[student]??0)+delta;final events=await _loadEvents();events.insert(0,PointEvent(student:student,skill:skill,delta:delta,by:Session.userName,ts:DateTime.now().millisecondsSinceEpoch));if(events.length>_maxEvents)events.removeRange(_maxEvents,events.length);final prefs=await SharedPreferences.getInstance();await prefs.setString(_totalsKey,jsonEncode(totals));await prefs.setString(_eventsKey,jsonEncode(events.map((e)=>e.toJson()).toList()));return true; }
  static Future<List<PointEvent>> eventsFor(String student,{int limit=20}) async { if(Backend.ready){final rows=await _serverRows(student);return rows.take(limit).map(PointEvent.fromServer).toList();} final all=await _loadEvents();return all.where((e)=>e.student==student).take(limit).toList(); }
  static Future<List<MapEntry<String,int>>> lastDays(String student,{int days=5}) async { final all=Backend.ready?await eventsFor(student,limit:_maxEvents):await _loadEvents(); final now=DateTime.now();final out=<MapEntry<String,int>>[];for(int i=days-1;i>=0;i--){final d=DateTime(now.year,now.month,now.day).subtract(Duration(days:i));final sum=all.where((e){final t=DateTime.fromMillisecondsSinceEpoch(e.ts);return e.student==student&&t.year==d.year&&t.month==d.month&&t.day==d.day;}).fold<int>(0,(a,e)=>a+e.delta);out.add(MapEntry(JalaliDate.fromDateTime(d).weekdayName,sum));}return out; }
  static Future<Map<String,int>> _loadTotals() async {if(_totals!=null)return _totals!;final prefs=await SharedPreferences.getInstance();final raw=prefs.getString(_totalsKey);final map=<String,int>{..._seed};if(raw!=null){try{final d=jsonDecode(raw) as Map<String,dynamic>;d.forEach((k,v)=>map[k]=(v as num).toInt());}catch(_){}}return _totals=map;}
  static Future<List<PointEvent>> _loadEvents() async {if(_events!=null)return _events!;final prefs=await SharedPreferences.getInstance();final raw=prefs.getString(_eventsKey);if(raw==null)return _events=[];try{return _events=(jsonDecode(raw) as List).map((e)=>PointEvent.fromJson(Map<String,dynamic>.from(e as Map))).toList();}catch(_){return _events=[];}}
}

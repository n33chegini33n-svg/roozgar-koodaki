import '../widgets/illustration_banner.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audit_log_model.dart';
import '../utils/jalali.dart';

/// گزارش تغییرات: چه کسی، چه زمانی، چه کاری کرد (فقط‌خواندنی)
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  List<AuditEntry> _all = [];
  List<AuditEntry> _filtered = [];
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await AuditLogService.getAll();
    if (!mounted) return;
    setState(() {
      _all = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _search.text.trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        _filtered = q.isEmpty
            ? _all
            : _all
                .where((e) =>
                    e.actor.toLowerCase().contains(q) ||
                    e.action.toLowerCase().contains(q) ||
                    e.details.toLowerCase().contains(q))
                .toList();
      });
    });
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${JalaliDate.fromDateTime(d).formatted}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('گزارش تغییرات'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: IllustrationBanner(
                      image: 'ill_audit_log.png',
                      title: 'گزارش تغییرات',
                      subtitle: 'هر تغییر مهم، همراه با کاربر و زمان آن ثبت می‌شود.',
                      tint: Color(0xFFE0F2F1),
                      imageHeight: 70,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _search,
                      onChanged: _onChanged,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        labelText: 'جستجو در کاربر، عملیات یا جزئیات',
                        border: OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(child: Text('موردی ثبت نشده است', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final e = _filtered[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE1F5FE),
                                    child: Icon(Icons.history_rounded, color: _navy),
                                  ),
                                  title: Text(e.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${e.actor} (${e.role})\n${e.details}', style: const TextStyle(fontSize: 12)),
                                  isThreeLine: true,
                                  trailing: Text(_fmt(e.timestamp), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

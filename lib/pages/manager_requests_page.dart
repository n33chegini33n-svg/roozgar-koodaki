import '../widgets/illustration_banner.dart';
import 'package:flutter/material.dart';
import '../models/attendance_edit_request_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';

/// درخواست‌ها و تأییدیه: فعلاً درخواست‌های اصلاح حضور و غیاب
class ManagerRequestsPage extends StatefulWidget {
  const ManagerRequestsPage({super.key});

  @override
  State<ManagerRequestsPage> createState() => _ManagerRequestsPageState();
}

class _ManagerRequestsPageState extends State<ManagerRequestsPage> {
  static const Color _navy = Color(0xFF01579B);
  bool _loading = true;
  List<AttendanceEditRequest> _all = [];

  bool get _canDecide => PermissionService.instance.can(Session.role, Perm.approveAttendanceEdit);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await EditRequestService.getAll();
    if (!mounted) return;
    setState(() {
      _all = List.of(list);
      _loading = false;
    });
  }

  String _fmt(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${JalaliDate.fromDateTime(d).formatted}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _decide(AttendanceEditRequest r, bool approve) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(approve ? 'تأیید اصلاح' : 'رد درخواست'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.studentName} • ${r.date}\n${r.oldStatus}  ←  ${r.newStatus}'),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: approve ? 'یادداشت (اختیاری)' : 'دلیل رد',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'تأیید' : 'رد')),
          ],
        ),
      ),
    );
    final note = noteCtrl.text.trim();
    if (ok != true) return;
    if (!approve && note.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای رد، دلیل را بنویسید')));
      }
      return;
    }
    try {
      await EditRequestService.decide(
        requestId: r.id,
        approved: approve,
        by: Session.userName,
        byRole: Session.role.label,
        note: note,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
    await _load();
  }

  Widget _card(AttendanceEditRequest r) {
    final pending = r.state == 'pending';
    final color = r.state == 'approved'
        ? const Color(0xFF2E9E6B)
        : (r.state == 'rejected' ? const Color(0xFFE5484D) : const Color(0xFFF59E0B));
    final stateLabel = r.state == 'approved' ? 'تأیید شد' : (r.state == 'rejected' ? 'رد شد' : 'در انتظار');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(stateLabel, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${r.className} • ${r.date}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Text('${r.oldStatus}  ←  ${r.newStatus}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('دلیل: ${r.reason}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('درخواست‌دهنده: ${r.requestedBy} • ${_fmt(r.createdAt)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (!pending) ...[
              const Divider(height: 18),
              Text(
                '${r.decidedBy} • ${_fmt(r.decidedAt)}${r.decisionNote.isEmpty ? '' : '\n${r.decisionNote}'}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (pending && _canDecide) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _decide(r, true),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('تأیید'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _decide(r, false),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('رد'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _list(List<AttendanceEditRequest> items, String empty) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: IllustrationBanner(
            image: 'ill_requests.png',
            title: 'درخواست‌ها و تأییدیه',
            subtitle: 'اصلاح حضور و غیاب با دلیل ثبت می‌شود و پس از تأیید اعمال می‌گردد.',
            tint: Color(0xFFFFF8E1),
            imageHeight: 70,
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(empty, style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _card(items[i]),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _all.where((r) => r.state == 'pending').toList();
    final done = _all.where((r) => r.state != 'pending').toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F8FF),
          appBar: AppBar(
            title: const Text('درخواست‌ها و تأییدیه'),
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'در انتظار (${pending.length})'),
                const Tab(text: 'سوابق'),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _list(pending, 'درخواستی در انتظار نیست'),
                    _list(done, 'هنوز سابقه‌ای وجود ندارد'),
                  ],
                ),
        ),
      ),
    );
  }
}

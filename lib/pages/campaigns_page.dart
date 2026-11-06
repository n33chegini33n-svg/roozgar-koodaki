import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../utils/jalali.dart';
import 'campaign_detail_page.dart';

const Color _navy = Color(0xFF01579B);

/// صفحهٔ جدا برای کمپین‌های مالی (فقط فعال و بایگانی)
class CampaignsPage extends StatefulWidget {
  const CampaignsPage({super.key});

  @override
  State<CampaignsPage> createState() => _CampaignsPageState();
}

class _CampaignsPageState extends State<CampaignsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _campaigns = [];
  Map<String, int> _studentCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Backend.client
          .from('campaigns')
          .select('id, title, reason, amount_per_student, due_jalali, status, created_at')
          .order('created_at', ascending: false);
      final plans = await Backend.client
          .from('tuition_plans')
          .select('campaign_id')
          .not('campaign_id', 'is', null);
      final counts = <String, int>{};
      for (final p in plans) {
        final id = '${p['campaign_id']}';
        counts[id] = (counts[id] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() {
        _campaigns = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        _studentCounts = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _money(num v) {
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _dateOf(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return JalaliDate.fromDateTime(d.toLocal()).formatted;
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CampaignDetailPage(campaign: c)),
    );
    _load();
  }

  Future<void> _deleteCampaign(Map<String, dynamic> c) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف کامل کمپین',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text('کمپین «${c['title']}» برای همیشه حذف می‌شود. این کار برگشت ندارد. ادامه می‌دهید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await Backend.client.rpc('delete_campaign', params: {'p_campaign': '${c['id']}'});
      messenger.showSnackBar(const SnackBar(
        content: Text('کمپین حذف شد'),
        backgroundColor: Colors.green,
      ));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('حذف انجام نشد: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _list(bool isArchivedTab, String emptyText) {
    final items = _campaigns.where((c) {
      final status = '${c['status']}';
      return isArchivedTab ? status == 'archived' : status != 'archived';
    }).toList();

    if (items.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        final id = '${c['id']}';
        final students = _studentCounts[id] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _open(c),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${c['title']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
                        const SizedBox(height: 4),
                        Text('دلیل: ${c['reason']}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(
                          'مبلغ هر فرزند: ${_money((c['amount_per_student'] as num?) ?? 0)} تومان  •  '
                          'نوآموز: $students'
                          '${(c['due_jalali'] ?? '').toString().isEmpty ? '' : '  •  مهلت: ${c['due_jalali']}'}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text('ساخته شده: ${_dateOf(c['created_at']?.toString())}',
                            style: const TextStyle(fontSize: 11, color: Colors.black45)),
                      ],
                    ),
                  ),
                  if (isArchivedTab)
                    IconButton(
                      tooltip: 'حذف کمپین بدون واریزی',
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () => _deleteCampaign(c),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F8FF),
          appBar: AppBar(
            title: const Text('کمپین‌های مالی'),
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            actions: [
              IconButton(tooltip: 'به‌روزرسانی', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
            ],
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'فعال'),
                Tab(text: 'بایگانی'),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('خطا: $_error')))
                  : TabBarView(
                      children: [
                        _list(false, 'کمپین فعالی وجود ندارد'),
                        _list(true, 'کمپین بایگانی‌شده‌ای وجود ندارد'),
                      ],
                    ),
        ),
      ),
    );
  }
}

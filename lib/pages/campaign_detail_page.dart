import 'package:flutter/material.dart';
import '../services/backend.dart';

const Color _navy = Color(0xFF01579B);

/// فهرست نوآموزان یک کمپین و مدیریت وضعیت (فقط فعال و بایگانی)
class CampaignDetailPage extends StatefulWidget {
  final Map<String, dynamic> campaign;
  const CampaignDetailPage({super.key, required this.campaign});

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _StudentRow {
  final String name;
  final String className;
  final int total;
  final int paid;

  const _StudentRow({
    required this.name,
    required this.className,
    required this.total,
    required this.paid,
  });

  bool get isPaid => paid >= total && total > 0;
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  bool _loading = true;
  String? _error;
  List<_StudentRow> _rows = [];
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = '${widget.campaign['status'] ?? 'active'}';
    if (_status == 'frozen') _status = 'active';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Backend.client
          .from('tuition_plans')
          .select('id, total, students(full_name, classes(name)), tuition_schedule(amount, settled)')
          .eq('campaign_id', '${widget.campaign['id']}');

      final rows = <_StudentRow>[];
      for (final r in data) {
        final st = r['students'] is Map ? r['students'] as Map : const {};
        final cls = st['classes'] is Map ? st['classes'] as Map : const {};
        final sched = r['tuition_schedule'] is List ? r['tuition_schedule'] as List : const [];
        var paid = 0;
        for (final x in sched) {
          if (x is Map && x['settled'] == true) {
            paid += ((x['amount'] as num?) ?? 0).toInt();
          }
        }
        rows.add(_StudentRow(
          name: '${st['full_name'] ?? ''}',
          className: '${cls['name'] ?? ''}',
          total: ((r['total'] as num?) ?? 0).toInt(),
          paid: paid,
        ));
      }
      rows.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  Future<void> _changeStatus(String newStatus, String actionName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(actionName, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          content: Text('آیا از $actionName اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأیید')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await Backend.client.from('campaigns').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', '${widget.campaign['id']}');

      setState(() => _status = newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionName با موفقیت انجام شد'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در تغییر وضعیت: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _money(int v) {
    final s = v.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
      b.write(s[i]);
    }
    return v < 0 ? '-${b.toString()}' : b.toString();
  }

  Widget _statusBadge() {
    final isArchived = _status == 'archived';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isArchived ? Colors.grey.shade200 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isArchived ? 'بایگانی شده' : 'فعال',
        style: TextStyle(
          color: isArchived ? Colors.grey.shade800 : Colors.green.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _rows.where((r) => r.isPaid).length;
    final collected = _rows.fold<int>(0, (a, r) {
      final n = r.paid > r.total ? r.total : r.paid;
      return a + (n > 0 ? n : 0);
    });
    final perStudent = ((widget.campaign['amount_per_student'] as num?) ?? 0).toInt();
    final isArchived = _status == 'archived';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: Text('${widget.campaign['title']}'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(tooltip: 'به‌روزرسانی', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('خطا: $_error')))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${widget.campaign['title']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy),
                                    ),
                                  ),
                                  _statusBadge(),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('دلیل: ${widget.campaign['reason']}'),
                              const SizedBox(height: 6),
                              Text('مبلغ برای هر نوآموز: ${_money(perStudent)} تومان',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (widget.campaign['due_jalali'] != null &&
                                  '${widget.campaign['due_jalali']}'.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('مهلت پرداخت: ${widget.campaign['due_jalali']}'),
                              ],
                              const SizedBox(height: 6),
                              Text('وضعیت دریافت: $paidCount از ${_rows.length} نوآموز پرداخت کرده‌اند'),
                              Text('جمع وصول‌شده: ${_money(collected)} تومان',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              const Divider(height: 20),
                              if (!isArchived)
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.archive_outlined, size: 18),
                                  label: const Text('بایگانی کردن کمپین'),
                                  onPressed: () => _changeStatus('archived', 'بایگانی کردن کمپین'),
                                )
                              else
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.unarchive_outlined, size: 18),
                                  label: const Text('بازگردانی به فعال'),
                                  onPressed: () => _changeStatus('active', 'بازگردانی کمپین'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('نوآموزی در این کمپین ثبت نشده است')),
                        ),
                      for (final r in _rows)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  r.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: r.isPaid ? Colors.green : Colors.grey.shade400,
                                  size: 26,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(r.className,
                                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: r.isPaid ? Colors.green.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    r.isPaid ? 'پرداخت شده' : 'در انتظار پرداخت',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: r.isPaid ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

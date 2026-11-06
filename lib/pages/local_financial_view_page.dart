import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLocalFinancialKey = 'manager_financial_records_v1';

/// نمایش طراحی مالی ذخیره‌شده روی همین کامپیوتر (حالت بدون سرور)
/// فقط برای خواندن و انتقال به سرور است. چیزی را تغییر نمی‌دهد.
class LocalFinancialViewPage extends StatefulWidget {
  const LocalFinancialViewPage({super.key});

  @override
  State<LocalFinancialViewPage> createState() => _LocalFinancialViewPageState();
}

class _LocalFinancialViewPageState extends State<LocalFinancialViewPage> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kLocalFinancialKey);
      if (raw == null || raw.isEmpty) {
        _items = [];
      } else {
        final list = jsonDecode(raw) as List;
        _items = [for (final e in list) Map<String, dynamic>.from(e as Map)];
      }
    } catch (e) {
      _error = 'خواندن اطلاعات محلی انجام نشد: $e';
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  String _recordText(Map<String, dynamic> m) {
    final b = StringBuffer();
    b.writeln('نوآموز: ${m['studentName'] ?? ''} | کلاس: ${m['className'] ?? ''}');
    b.writeln('بخش: ${m['feeType'] ?? ''} | عنوان: ${m['feeTitle'] ?? ''}');
    b.writeln('مبلغ: ${_int(m['amount'])} تومان | وضعیت: ${m['status'] ?? ''}');
    b.writeln('شمول در صورت‌حساب: ${m['isIncluded'] == false ? 'خیر' : 'بله'}');
    final kinds = <String>[
      if (m['isCash'] == true) 'نقدی',
      if (m['isInstallment'] == true) 'اقساطی',
    ];
    b.writeln('نوع پرداخت: ${kinds.isEmpty ? 'مشخص نشده' : kinds.join(' و ')}');

    final stages = (m['cashStages'] as List?) ?? const [];
    if (stages.isNotEmpty) {
      b.writeln('مراحل نقدی:');
      for (int i = 0; i < stages.length; i++) {
        final s = Map<String, dynamic>.from(stages[i] as Map);
        final amt = _int(s['amount']);
        if (amt == 0 && s['isSettled'] != true) continue;
        b.writeln('  مرحله ${i + 1}: ${amt} تومان، ${s['isSettled'] == true ? 'تسویه شده' : 'تسویه نشده'}، سررسید: ${s['dueDate'] ?? ''}');
      }
    }

    if (m['isInstallment'] == true) {
      final count = _int(m['installmentCount']);
      final settled = (m['installmentSettled'] as List?) ?? const [];
      b.writeln('اقساط: $count قسط');
      for (int i = 0; i < count; i++) {
        final ok = i < settled.length && settled[i] == true;
        b.writeln('  قسط ${i + 1}: ${ok ? 'تسویه شده' : 'تسویه نشده'}');
      }
    }

    b.writeln('شماره فیش: ${m['receiptNo'] ?? ''} | تاریخ: ${m['date'] ?? ''}');
    final desc = '${m['description'] ?? ''}'.trim();
    if (desc.isNotEmpty) b.writeln('توضیح: $desc');
    final doc = '${m['documentNote'] ?? ''}'.trim();
    if (doc.isNotEmpty) b.writeln('مستندات: $doc');
    return b.toString().trimRight();
  }

  String _allText() {
    final parts = <String>[];
    for (int i = 0; i < _items.length; i++) {
      parts.add('--- بند ${i + 1} ---\n${_recordText(_items[i])}');
    }
    return parts.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('بایگانی محلی مالی'),
          backgroundColor: const Color(0xFF01579B),
          foregroundColor: Colors.white,
          actions: [
            if (_items.isNotEmpty)
              IconButton(
                tooltip: 'کپی همه',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _allText()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ همه کپی شد. حالا در گفتگو جایگذاری کن.')),
                  );
                },
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error)))
                : _items.isEmpty
                    ? const Center(child: Text('اطلاعات محلی پیدا نشد.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(_recordText(_items[i]), style: const TextStyle(height: 1.6)),
                          ),
                        ),
                      ),
      ),
    );
  }
}

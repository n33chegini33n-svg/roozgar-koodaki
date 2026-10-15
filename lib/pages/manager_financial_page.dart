import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/export_helper.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';
import '../models/school_classes.dart';
import '../services/backend.dart';

class TuitionRecord {
  final String id;
  final String studentName;
  final String className;
  final int amount; // in Toman
  final String status; // 'پرداخت‌شده 🟢', 'در انتظار تأیید 🟡', 'معوقه / بدهکار 🔴'
  final String date;
  final String receiptNo;
  final String feeType;
  final String feeTitle;

  TuitionRecord({
    required this.id,
    required this.studentName,
    required this.className,
    required this.amount,
    required this.status,
    required this.date,
    required this.receiptNo,
    this.feeType = 'شهریه',
    this.feeTitle = 'شهریه',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentName': studentName,
        'className': className,
        'amount': amount,
        'status': status,
        'date': date,
        'receiptNo': receiptNo,
        'feeType': feeType,
        'feeTitle': feeTitle,
      };

  factory TuitionRecord.fromJson(Map<String, dynamic> json) => TuitionRecord(
        id: json['id'] ?? '',
        studentName: json['studentName'] ?? '',
        className: normalizeClassName(((json['className']) ?? '').toString()),
        amount: json['amount'] ?? 0,
        status: json['status'] ?? 'پرداخت‌شده 🟢',
        date: json['date'] ?? JalaliDate.now().formatted,
        receiptNo: json['receiptNo'] ?? 'REC-001',
        feeType: json['feeType'] ?? 'شهریه',
        feeTitle: json['feeTitle'] ?? 'شهریه',
      );
}

class ManagerFinancialPage extends StatefulWidget {
  const ManagerFinancialPage({super.key});

  @override
  State<ManagerFinancialPage> createState() => _ManagerFinancialPageState();
}

class _ManagerFinancialPageState extends State<ManagerFinancialPage> {
  bool _isLoading = true;
  List<TuitionRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    if (Backend.ready) {
      try {
        final rows = await Backend.client
            .from('tuition_records')
            .select('id, student_id, amount, status, receipt_no, jalali_date, fee_type, fee_title, students(full_name, classes(name))')
            .order('created_at', ascending: false)
            .limit(500);
        final records = rows.map<TuitionRecord>((row) {
          final student = row['students'];
          final classes = student is Map ? student['classes'] : null;
          final amount = (row['amount'] as num?)?.toInt() ?? 0;
          final status = '${row['status'] ?? 'overdue'}';
          return TuitionRecord(
            id: '${row['id']}',
            studentName: student is Map ? '${student['full_name'] ?? ''}' : '',
            className: normalizeClassName(classes is Map ? '${classes['name'] ?? ''}' : ''),
            amount: amount,
            status: status == 'paid'
                ? 'پرداخت‌شده 🟢'
                : status == 'pending'
                    ? 'در انتظار تأیید 🟡'
                    : 'معوقه / بدهکار 🔴',
            date: '${row['jalali_date'] ?? ''}',
            receiptNo: '${row['receipt_no'] ?? ''}',
            feeType: '${row['fee_type'] ?? 'شهریه'}',
            feeTitle: '${row['fee_title'] ?? row['fee_type'] ?? 'شهریه'}',
          );
        }).toList();
        if (!mounted) return;
        setState(() {
          _records = records;
          _isLoading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خواندن اطلاعات مالی انجام نشد: $e')));
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('manager_financial_records_v1');
    if (data != null) {
      List decoded = jsonDecode(data);
      if (!mounted) return;
      setState(() {
        _records = decoded.map((e) => TuitionRecord.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      _records = [
        TuitionRecord(id: 'F1', studentName: 'آرتین شجاعی', className: 'پیش‌دبستانی آفتاب ☀️', amount: 4500000, status: 'پرداخت‌شده 🟢', date: JalaliDate.now().formatted, receiptNo: 'RC-9821'),
        TuitionRecord(id: 'F2', studentName: 'سارا محمدی', className: 'پیش‌دبستانی آفتاب ☀️', amount: 4500000, status: 'در انتظار تأیید 🟡', date: JalaliDate.now().formatted, receiptNo: 'RC-9822'),
        TuitionRecord(id: 'F3', studentName: 'علی احمدی', className: 'اول دبستان ستاره 🌟', amount: 6200000, status: 'معوقه / بدهکار 🔴', date: JalaliDate.now().formatted, receiptNo: 'RC-9810'),
        TuitionRecord(id: 'F4', studentName: 'نیلا صادقی', className: 'دوم دبستان مهتاب 🌙', amount: 6200000, status: 'پرداخت‌شده 🟢', date: JalaliDate.now().formatted, receiptNo: 'RC-9819'),
      ];
      await _saveFinancialData();
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFinancialData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manager_financial_records_v1', jsonEncode(_records.map((e) => e.toJson()).toList()));
  }

  /// تأیید یا رد رسید پرداخت (فقط با اجازهٔ مالی)
  Future<void> _reviewReceipt(TuitionRecord r) async {
    if (!PermissionService.instance.can(Session.role, Perm.viewFinancial)) return;
    final decision = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('بررسی رسید پرداخت'),
          content: Text('${r.studentName}\nمبلغ: ${r.amount} تومان\nشمارهٔ پیگیری: ${r.receiptNo}\nتاریخ: ${r.date}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بعداً')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'reject'), child: const Text('رد رسید', style: TextStyle(color: Colors.red))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('تأیید پرداخت')),
          ],
        ),
      ),
    );
    if (decision == null || !mounted) return;
    final idx = _records.indexWhere((x) => x.id == r.id);
    if (idx < 0) return;
    final newStatus = decision == 'ok' ? 'پرداخت‌شده 🟢' : 'معوقه / بدهکار 🔴';
    if (Backend.ready) {
      await Backend.client
          .from('tuition_records')
          .update({'status': decision == 'ok' ? 'paid' : 'overdue'})
          .eq('id', r.id);
      if (!mounted) return;
      await _loadFinancialData();
      return;
    }
    setState(() {
      _records[idx] = TuitionRecord(
        id: r.id,
        studentName: r.studentName,
        className: r.className,
        amount: r.amount,
        status: newStatus,
        date: r.date,
        receiptNo: r.receiptNo,
        feeType: r.feeType,
        feeTitle: r.feeTitle,
      );
    });
    await _saveFinancialData();
    await AuditLogService.log(
      actor: Session.userName,
      role: Session.role.label,
      action: decision == 'ok' ? 'تأیید رسید پرداخت' : 'رد رسید پرداخت',
      details: '${r.studentName} • ${r.amount} تومان • ${r.receiptNo}',
    );
  }

  void _showAddInvoiceDialog() {
    if (!PermissionService.instance.can(Session.role, Perm.viewFinancial)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شما اجازهٔ ثبت رکورد مالی را ندارید'), backgroundColor: Colors.red),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    String selectedClass = 'پیش‌دبستانی آفتاب ☀️';
    final amountCtrl = TextEditingController();
    String selectedStatus = 'پرداخت‌شده 🟢';
    final receiptCtrl = TextEditingController(text: 'RC-${DateTime.now().millisecond}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('💳 صدور فاکتور یا ثبت فیش واریزی'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'نام نوآموز', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'کلاس', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedClass,
                          isDense: true,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'پیش‌دبستانی آفتاب ☀️', child: Text('پیش‌دبستانی آفتاب ☀️')),
                            DropdownMenuItem(value: 'اول دبستان ستاره 🌟', child: Text('اول دبستان ستاره 🌟')),
                            DropdownMenuItem(value: 'دوم دبستان مهتاب 🌙', child: Text('دوم دبستان مهتاب 🌙')),
                          ],
                          onChanged: (val) => setDialogState(() => selectedClass = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'مبلغ (تومان)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'وضعیت پرداخت', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStatus,
                          isDense: true,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'پرداخت‌شده 🟢', child: Text('پرداخت‌شده 🟢')),
                            DropdownMenuItem(value: 'در انتظار تأیید 🟡', child: Text('در انتظار تأیید فیش 🟡')),
                            DropdownMenuItem(value: 'معوقه / بدهکار 🔴', child: Text('معوقه / بدهکار 🔴')),
                          ],
                          onChanged: (val) => setDialogState(() => selectedStatus = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: receiptCtrl,
                      decoration: const InputDecoration(labelText: 'شماره فیش / پیگیری', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty && amountCtrl.text.trim().isNotEmpty) {
                    final newRecord = TuitionRecord(
                      id: 'F-${DateTime.now().millisecondsSinceEpoch}',
                      studentName: nameCtrl.text.trim(),
                      className: selectedClass,
                      amount: int.tryParse(amountCtrl.text.trim()) ?? 0,
                      status: selectedStatus,
                      date: JalaliDate.now().formatted,
                      receiptNo: receiptCtrl.text.trim(),
                    );
                    setState(() {
                      _records.insert(0, newRecord);
                      _saveFinancialData();
                    });
                    AuditLogService.log(
                      actor: Session.userName,
                      role: Session.role.label,
                      action: 'ثبت رکورد مالی',
                      details: '${newRecord.studentName} • ${newRecord.amount} تومان • ${newRecord.status} • رسید ${newRecord.receiptNo}',
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ رکورد مالی با موفقیت ثبت شد!'), backgroundColor: Colors.green),
                    );
                  }
                },
                child: const Text('ثبت نهایی'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _totalIncome {
    int sum = 0;
    for (var r in _records) {
      if (r.status.contains('پرداخت‌شده')) sum += r.amount;
    }
    return sum;
  }

  int get _totalPending {
    int sum = 0;
    for (var r in _records) {
      if (r.status.contains('بدهکار') || r.status.contains('معوقه')) sum += r.amount;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('امور مالی و حسابداری شهریه'),
        backgroundColor: const Color(0xFF01579B),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'خروجی اکسل',
            onPressed: () {
              ExportHelper.exportToExcel(
                context: context,
                title: 'گزارش امور مالی و شهریه مهدکودک',
                headers: ['نام نوآموز', 'کلاس', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش'],
                rows: _records.map((r) => [r.studentName, r.className, r.amount, r.status, r.date, r.receiptNo]).toList(),
                fileName: 'financial_report_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'خروجی PDF',
            onPressed: () {
              ExportHelper.exportToPdf(
                context: context,
                title: 'گزارش رسمی امور مالی و حسابداری شهریه',
                headers: ['نام نوآموز', 'کلاس', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش'],
                rows: _records.map((r) => [r.studentName, r.className, r.amount, r.status, r.date, r.receiptNo]).toList(),
                fileName: 'financial_report_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
          /*print*/
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'چاپ',
            onPressed: () {
              ExportHelper.printTable(
                context: context,
                title: 'گزارش رسمی امور مالی و حسابداری شهریه',
                headers: ['نام نوآموز', 'کلاس', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش'],
                rows: _records.map((r) => [r.studentName, r.className, r.amount, r.status, r.date, r.receiptNo]).toList(),
                fileName: 'financial_report_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddInvoiceDialog,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('صدور فاکتور جدید'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 3,
                          color: Colors.green.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('کل درآمد وصول‌شده', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('$_totalIncome تومان', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          elevation: 3,
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('مجموع معوقات / بدهکاران', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('$_totalPending تومان', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'لیست تراکنش‌ها و وضعیت شهریه نوآموزان:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF01579B)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: _records.isEmpty
                          ? const Center(child: Text('هیچ رکورد مالی ثبت نشده است.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _records.length,
                              itemBuilder: (context, index) {
                                final r = _records[index];
                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: r.status.contains('پرداخت‌شده') ? Colors.green.shade100 : Colors.amber.shade100,
                                      child: Icon(
                                        r.status.contains('پرداخت‌شده') ? Icons.check_circle : Icons.warning_rounded,
                                        color: r.status.contains('پرداخت‌شده') ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                    onTap: r.status.contains('انتظار') ? () => _reviewReceipt(r) : null,
                                    title: Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('نوع: ${r.feeTitle}\nکلاس: ${r.className} | تاریخ: ${r.date} | فیش: ${r.receiptNo}${r.status.contains('انتظار') ? '\nبرای بررسی رسید بزنید' : ''}'),
                                    trailing: SizedBox(
                                      width: 140,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('${r.amount} تومان', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(r.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

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
  final String description;

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
    this.description = '',
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
        'description': description,
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
        description: json['description'] ?? '',
      );

  TuitionRecord copyWith({
    String? id,
    String? studentName,
    String? className,
    int? amount,
    String? status,
    String? date,
    String? receiptNo,
    String? feeType,
    String? feeTitle,
    String? description,
  }) {
    return TuitionRecord(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      date: date ?? this.date,
      receiptNo: receiptNo ?? this.receiptNo,
      feeType: feeType ?? this.feeType,
      feeTitle: feeTitle ?? this.feeTitle,
      description: description ?? this.description,
    );
  }
}

class ManagerFinancialPage extends StatefulWidget {
  const ManagerFinancialPage({super.key});

  @override
  State<ManagerFinancialPage> createState() => _ManagerFinancialPageState();
}

class _ManagerFinancialPageState extends State<ManagerFinancialPage> {
  bool _isLoading = true;
  List<TuitionRecord> _records = [];
  String _searchQuery = '';

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
            .select('id, student_id, amount, status, receipt_no, jalali_date, fee_type, fee_title, description, students(full_name, classes(name))')
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
            description: '${row['description'] ?? ''}',
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
      final now = JalaliDate.now().formatted;
      _records = [
        TuitionRecord(id: 'F1', studentName: 'آرتین شجاعی', className: 'پیش‌دبستانی آفتاب ☀️', amount: 4500000, status: 'پرداخت‌شده 🟢', date: now, receiptNo: 'RC-9821', feeType: 'شهریه', feeTitle: 'شهریه نیم‌سال اول', description: 'واریز کامل از طریق درگاه بانکی'),
        TuitionRecord(id: 'F2', studentName: 'آرتین شجاعی', className: 'پیش‌دبستانی آفتاب ☀️', amount: 800000, status: 'پرداخت‌شده 🟢', date: now, receiptNo: 'RC-9825', feeType: 'سرویس', feeTitle: 'هزینه سرویس رفت و برگشت', description: 'پرداخت نقدی به دفتر'),
        TuitionRecord(id: 'F3', studentName: 'سارا محمدی', className: 'پیش‌دبستانی آفتاب ☀️', amount: 4500000, status: 'در انتظار تأیید 🟡', date: now, receiptNo: 'RC-9822', feeType: 'شهریه', feeTitle: 'شهریه پایه', description: 'فیش فیزیکی تحویل دفتر گردید جهت استعلام'),
        TuitionRecord(id: 'F4', studentName: 'سارا محمدی', className: 'پیش‌دبستانی آفتاب ☀️', amount: 500000, status: 'پرداخت‌شده 🟢', date: now, receiptNo: 'RC-9830', feeType: 'کتاب و لوازم', feeTitle: 'بسته آموزشی و کارگاه', description: 'تسویه شد'),
        TuitionRecord(id: 'F5', studentName: 'علی احمدی', className: 'اول دبستان ستاره 🌟', amount: 6200000, status: 'معوقه / بدهکار 🔴', date: now, receiptNo: 'RC-9810', feeType: 'شهریه', feeTitle: 'شهریه سالانه', description: 'مهلت پرداخت تا آخر ماه تمدید شد'),
        TuitionRecord(id: 'F6', studentName: 'نیلا صادقی', className: 'دوم دبستان مهتاب 🌙', amount: 6200000, status: 'پرداخت‌شده 🟢', date: now, receiptNo: 'RC-9819', feeType: 'شهریه', feeTitle: 'شهریه کل سال', description: 'پرداخت یکجا با تخفیف خوش‌حسابی'),
        TuitionRecord(id: 'F7', studentName: 'نیلا صادقی', className: 'دوم دبستان مهتاب 🌙', amount: 1200000, status: 'پرداخت‌شده 🟢', date: now, receiptNo: 'RC-9844', feeType: 'فوق‌برنامه', feeTitle: 'کلاس زبان و رباتیک', description: 'ثبت‌نام دوره پاییزه'),
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

  /// گروه‌بندی رکوردها بر اساس نام نوآموز
  Map<String, List<TuitionRecord>> get _groupedRecords {
    final Map<String, List<TuitionRecord>> grouped = {};
    for (var r in _records) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final match = r.studentName.toLowerCase().contains(query) ||
            r.className.toLowerCase().contains(query) ||
            r.feeTitle.toLowerCase().contains(query) ||
            r.feeType.toLowerCase().contains(query) ||
            r.receiptNo.toLowerCase().contains(query);
        if (!match) continue;
      }
      grouped.putIfAbsent(r.studentName, () => []).add(r);
    }
    return grouped;
  }

  /// ویرایش توضیحات یا وضعیت یک هزینه مشخص
  Future<void> _editRecordDialog(TuitionRecord record) async {
    if (!PermissionService.instance.can(Session.role, Perm.viewFinancial)) return;
    final descCtrl = TextEditingController(text: record.description);
    String currentStatus = record.status;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('ویرایش بند مالی: ${record.feeTitle}'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نوآموز: ${record.studentName} (${record.className})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('مبلغ: ${_formatNumber(record.amount)} تومان | شماره فیش: ${record.receiptNo}'),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'وضعیت پرداخت', border: OutlineInputBorder()),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentStatus,
                        isDense: true,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'پرداخت‌شده 🟢', child: Text('پرداخت‌شده 🟢')),
                          DropdownMenuItem(value: 'در انتظار تأیید 🟡', child: Text('در انتظار تأیید فیش 🟡')),
                          DropdownMenuItem(value: 'معوقه / بدهکار 🔴', child: Text('معوقه / بدهکار 🔴')),
                        ],
                        onChanged: (val) => setDState(() => currentStatus = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'توضیحات مدیر / یادداشت بررسی',
                      hintText: 'توضیحات لازم در خصوص این واریزی یا وضعیت بدهی را وارد کنید...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF01579B), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ذخیره تغییرات'),
              ),
            ],
          ),
        ),
      ),
    );

    if (updated == true) {
      final idx = _records.indexWhere((x) => x.id == record.id);
      if (idx >= 0) {
        final newRecord = _records[idx].copyWith(
          status: currentStatus,
          description: descCtrl.text.trim(),
        );

        if (Backend.ready) {
          String statusDb = 'overdue';
          if (currentStatus.contains('پرداخت‌شده')) statusDb = 'paid';
          if (currentStatus.contains('انتظار')) statusDb = 'pending';

          await Backend.client
              .from('tuition_records')
              .update({'status': statusDb, 'description': descCtrl.text.trim()})
              .eq('id', record.id);
        }

        setState(() {
          _records[idx] = newRecord;
        });
        await _saveFinancialData();

        await AuditLogService.log(
          actor: Session.userName,
          role: Session.role.label,
          action: 'ویرایش مشخصات بند مالی',
          details: '${newRecord.studentName} • ${newRecord.feeTitle} • ${newRecord.status} • توضیحات: ${newRecord.description}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ مشخصات و توضیحات با موفقیت به روزرسانی شد.'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  /// باز کردن دایالوگ/پوشه جامع صورت‌حساب مالی نوآموز
  void _showStudentFinancialDetailsModal(String studentName, List<TuitionRecord> studentRecords) {
    if (studentRecords.isEmpty) return;
    final className = studentRecords.first.className;

    showDialog(
      context: context,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // دریافت آخرین رکوردهای این نوآموز
            final currentStudentRecords = _records.where((r) => r.studentName == studentName).toList();
            int totalCharges = currentStudentRecords.fold(0, (sum, item) => sum + item.amount);
            int paidCharges = currentStudentRecords
                .where((item) => item.status.contains('پرداخت‌شده'))
                .fold(0, (sum, item) => sum + item.amount);
            int pendingCharges = totalCharges - paidCharges;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  width: 900,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.88,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Modal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF01579B).withOpacity(0.1),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF01579B), size: 28),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'جدول و صورت‌حساب مالی $studentName',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                                  ),
                                  Text('کلاس: $className', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // خلاصه سریع صورت‌حساب این نوآموز
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryChip('جمع کل هزینه‌ها', '${_formatNumber(totalCharges)} تومان', Colors.blue.shade900),
                            _summaryChip('پرداخت‌شده', '${_formatNumber(paidCharges)} تومان', Colors.green.shade800),
                            _summaryChip('مانده / بدهکار', '${_formatNumber(pendingCharges)} تومان', pendingCharges > 0 ? Colors.red.shade800 : Colors.green.shade800),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // دکمه‌های خروجی و پرینت اختصاصی نوآموز
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.table_chart_rounded, size: 18),
                            label: const Text('خروجی اکسل'),
                            onPressed: () {
                              ExportHelper.exportToExcel(
                                context: context,
                                title: 'صورت‌حساب مالی $studentName ($className)',
                                headers: ['بخش هزینه', 'عنوان هزینه', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                                rows: currentStudentRecords
                                    .map((r) => [r.feeType, r.feeTitle, r.amount, r.status, r.date, r.receiptNo, r.description])
                                    .toList(),
                                fileName: 'financial_${studentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: const Text('خروجی PDF'),
                            onPressed: () {
                              ExportHelper.exportToPdf(
                                context: context,
                                title: 'صورت‌حساب مالی $studentName ($className)',
                                headers: ['بخش هزینه', 'عنوان', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                                rows: currentStudentRecords
                                    .map((r) => [r.feeType, r.feeTitle, r.amount, r.status, r.date, r.receiptNo, r.description])
                                    .toList(),
                                fileName: 'financial_${studentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.indigo.shade900,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('پرینت مستقیم'),
                            onPressed: () {
                              ExportHelper.printTable(
                                context: context,
                                title: 'صورت‌حساب رسمی مالی $studentName ($className)',
                                headers: ['بخش هزینه', 'عنوان', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                                rows: currentStudentRecords
                                    .map((r) => [r.feeType, r.feeTitle, r.amount, r.status, r.date, r.receiptNo, r.description])
                                    .toList(),
                                fileName: 'financial_${studentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
                              );
                            },
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('افزودن بند هزینه'),
                            onPressed: () async {
                              await _showAddInvoiceDialog(prefilledStudent: studentName, prefilledClass: className);
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // جدول گزینه‌ها و آیتم‌های مالی نوآموز (DataTable)
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF01579B).withOpacity(0.08)),
                                columns: const [
                                  DataColumn(label: Text('بخش هزینه', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('عنوان هزینه', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('مبلغ (تومان)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('وضعیت', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('تاریخ', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('شماره فیش', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('توضیحات مدیر', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('عملیات', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: currentStudentRecords.map((rec) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(rec.feeType, style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w600)),
                                      )),
                                      DataCell(Text(rec.feeTitle, style: const TextStyle(fontWeight: FontWeight.w500))),
                                      DataCell(Text('${_formatNumber(rec.amount)} تومان', style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(rec.status, style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(rec.date, style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(rec.receiptNo, style: const TextStyle(fontSize: 12))),
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            rec.description.isEmpty ? '—' : rec.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: rec.description.isEmpty ? Colors.grey : Colors.black87),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF01579B)),
                                          tooltip: 'ثبت/ویرایش توضیحات و وضعیت',
                                          onPressed: () async {
                                            await _editRecordDialog(rec);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  String _formatNumber(int number) {
    final s = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('،');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  Future<void> _showAddInvoiceDialog({String? prefilledStudent, String? prefilledClass}) async {
    if (!PermissionService.instance.can(Session.role, Perm.viewFinancial)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شما اجازهٔ ثبت رکورد مالی را ندارید'), backgroundColor: Colors.red),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: prefilledStudent ?? '');
    String selectedClass = prefilledClass ?? 'پیش‌دبستانی آفتاب ☀️';
    final amountCtrl = TextEditingController();
    String selectedStatus = 'پرداخت‌شده 🟢';
    String selectedFeeType = 'شهریه';
    final feeTitleCtrl = TextEditingController(text: 'شهریه ماهانه');
    final descCtrl = TextEditingController();
    final receiptCtrl = TextEditingController(text: 'RC-${DateTime.now().millisecond}');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('💳 صدور فاکتور یا ثبت بند مالی جدید'),
            content: SizedBox(
              width: 440,
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
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'بخش هزینه', border: OutlineInputBorder()),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedFeeType,
                                isDense: true,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'شهریه', child: Text('شهریه')),
                                  DropdownMenuItem(value: 'سرویس', child: Text('سرویس')),
                                  DropdownMenuItem(value: 'کتاب و لوازم', child: Text('کتاب و لوازم')),
                                  DropdownMenuItem(value: 'فوق‌برنامه', child: Text('فوق‌برنامه')),
                                  DropdownMenuItem(value: 'تغذیه', child: Text('تغذیه')),
                                  DropdownMenuItem(value: 'سایر', child: Text('سایر')),
                                ],
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedFeeType = val!;
                                    if (feeTitleCtrl.text.isEmpty || feeTitleCtrl.text.startsWith('شهریه') || feeTitleCtrl.text.startsWith('هزینه')) {
                                      feeTitleCtrl.text = '$selectedFeeType نوآموز';
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: feeTitleCtrl,
                            decoration: const InputDecoration(labelText: 'عنوان هزینه', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'توضیحات / یادداشت مدیر جهت بررسی', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
                onPressed: () async {
                  if (nameCtrl.text.trim().isNotEmpty && amountCtrl.text.trim().isNotEmpty) {
                    final newRecord = TuitionRecord(
                      id: 'F-${DateTime.now().millisecondsSinceEpoch}',
                      studentName: nameCtrl.text.trim(),
                      className: selectedClass,
                      amount: int.tryParse(amountCtrl.text.trim()) ?? 0,
                      status: selectedStatus,
                      date: JalaliDate.now().formatted,
                      receiptNo: receiptCtrl.text.trim(),
                      feeType: selectedFeeType,
                      feeTitle: feeTitleCtrl.text.trim().isEmpty ? selectedFeeType : feeTitleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                    );

                    if (Backend.ready) {
                      try {
                        String dbStatus = 'overdue';
                        if (selectedStatus.contains('پرداخت‌شده')) dbStatus = 'paid';
                        if (selectedStatus.contains('انتظار')) dbStatus = 'pending';

                        await Backend.client.from('tuition_records').insert({
                          'amount': newRecord.amount,
                          'status': dbStatus,
                          'receipt_no': newRecord.receiptNo,
                          'jalali_date': newRecord.date,
                          'fee_type': newRecord.feeType,
                          'fee_title': newRecord.feeTitle,
                          'description': newRecord.description,
                        });
                      } catch (_) {}
                    }

                    setState(() {
                      _records.insert(0, newRecord);
                    });
                    await _saveFinancialData();

                    await AuditLogService.log(
                      actor: Session.userName,
                      role: Session.role.label,
                      action: 'ثبت بند مالی جدید',
                      details: '${newRecord.studentName} • ${newRecord.feeTitle} (${newRecord.feeType}) • ${_formatNumber(newRecord.amount)} تومان',
                    );

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ بند مالی با موفقیت ثبت شد!'), backgroundColor: Colors.green),
                      );
                    }
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
      if (r.status.contains('بدهکار') || r.status.contains('معوقه') || r.status.contains('انتظار')) sum += r.amount;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('امور مالی و حسابداری شهریه'),
        backgroundColor: const Color(0xFF01579B),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'خروجی کل به اکسل',
            onPressed: () {
              ExportHelper.exportToExcel(
                context: context,
                title: 'گزارش جامع امور مالی و شهریه نوآموزان',
                headers: ['نام نوآموز', 'کلاس', 'بخش هزینه', 'عنوان هزینه', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                rows: _records.map((r) => [r.studentName, r.className, r.feeType, r.feeTitle, r.amount, r.status, r.date, r.receiptNo, r.description]).toList(),
                fileName: 'financial_report_all_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'خروجی کل به PDF',
            onPressed: () {
              ExportHelper.exportToPdf(
                context: context,
                title: 'گزارش جامع رسمی امور مالی و شهریه نوآموزان',
                headers: ['نام نوآموز', 'کلاس', 'عنوان هزینه', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                rows: _records.map((r) => [r.studentName, r.className, r.feeTitle, r.amount, r.status, r.date, r.receiptNo, r.description]).toList(),
                fileName: 'financial_report_all_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'چاپ کل گزارش',
            onPressed: () {
              ExportHelper.printTable(
                context: context,
                title: 'گزارش جامع رسمی امور مالی و شهریه نوآموزان',
                headers: ['نام نوآموز', 'کلاس', 'عنوان هزینه', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                rows: _records.map((r) => [r.studentName, r.className, r.feeTitle, r.amount, r.status, r.date, r.receiptNo, r.description]).toList(),
                fileName: 'financial_report_all_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddInvoiceDialog(),
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
                  // کارت‌های خلاصه مالی
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
                                Text('${_formatNumber(_totalIncome)} تومان', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                const Text('مجموع معوقات و در انتظار', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('${_formatNumber(_totalPending)} تومان', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // جستجو در نوآموزان
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'جستجوی نام نوآموز، کلاس، شماره فیش یا نوع هزینه...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'لیست نوآموزان و وضعیت حساب مالی (جهت مشاهده جزئیات کلیک کنید):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF01579B)),
                      ),
                      Text('تعداد نوآموزان: ${grouped.length}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // لیست نوآموزان به صورت کارتی و قابل کلیک
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: grouped.isEmpty
                          ? const Center(child: Text('هیچ رکورد مالی مطابق با جستجو پیدا نشد.'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: grouped.keys.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final studentName = grouped.keys.elementAt(index);
                                final studentRecords = grouped[studentName]!;
                                final className = studentRecords.first.className;

                                final total = studentRecords.fold(0, (sum, r) => sum + r.amount);
                                final paid = studentRecords
                                    .where((r) => r.status.contains('پرداخت‌شده'))
                                    .fold(0, (sum, r) => sum + r.amount);
                                final pending = total - paid;
                                final hasPending = pending > 0 || studentRecords.any((r) => r.status.contains('انتظار'));

                                return InkWell(
                                  onTap: () => _showStudentFinancialDetailsModal(studentName, studentRecords),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: hasPending ? Colors.amber.shade100 : Colors.green.shade100,
                                          child: Icon(
                                            hasPending ? Icons.warning_rounded : Icons.check_circle_rounded,
                                            color: hasPending ? Colors.orange.shade800 : Colors.green.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    studentName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      className,
                                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'شامل ${studentRecords.length} بند هزینه • کل: ${_formatNumber(total)} تومان | پرداخت‌شده: ${_formatNumber(paid)} تومان',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              hasPending ? 'مانده: ${_formatNumber(pending)} تومان' : 'تسویه کامل 🟢',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: hasPending ? Colors.red.shade700 : Colors.green.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: const [
                                                Text('مشاهده جدول هزینه‌ها', style: TextStyle(fontSize: 11, color: Color(0xFF01579B), fontWeight: FontWeight.bold)),
                                                Icon(Icons.chevron_left_rounded, size: 16, color: Color(0xFF01579B)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
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

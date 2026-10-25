import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/export_helper.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';
import '../models/school_classes.dart';
import '../services/backend.dart';
import '../services/financial_access_policy.dart';
import '../services/backend_directory.dart';
import '../models/tuition_record_model.dart';
import 'financial/student_financial_details_dialog.dart';
export '../models/tuition_record_model.dart';

class ManagerFinancialPage extends StatefulWidget {
  const ManagerFinancialPage({super.key});

  @override
  State<ManagerFinancialPage> createState() => _ManagerFinancialPageState();
}

class _ManagerFinancialPageState extends State<ManagerFinancialPage> {
  bool _isLoading = true;
  List<TuitionRecord> _records = [];
  String _searchQuery = '';

  bool get _canReadLedger =>
      FinancialAccessPolicy.canReadManagementLedger(Session.role);
  bool get _canManageLedger =>
      FinancialAccessPolicy.canManageLedger(Session.role);

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    if (!_canReadLedger) {
      if (!mounted) return;
      setState(() {
        _records = [];
        _isLoading = false;
      });
      return;
    }

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
        TuitionRecord(
          id: 'F1',
          studentName: 'آرتین شجاعی',
          className: 'پیش‌دبستانی آفتاب ☀️',
          amount: 4500000,
          status: 'پرداخت‌شده 🟢',
          date: now,
          receiptNo: 'RC-9821',
          feeType: 'شهریه',
          feeTitle: 'شهریه سالانه',
          description: 'پرداخت نقدی نهایی شد',
          isIncluded: true,
          isCash: true,
          isInstallment: false,
          cashStages: [CashStage(title: 'مرحله اول', amount: 4500000, dueDate: now, isSettled: true)],
          documentNote: 'فیش بانکی ضمیمه گردید',
        ),
        TuitionRecord(
          id: 'F2',
          studentName: 'آرتین شجاعی',
          className: 'پیش‌دبستانی آفتاب ☀️',
          amount: 800000,
          status: 'پرداخت‌شده 🟢',
          date: now,
          receiptNo: 'RC-9825',
          feeType: 'سرویس',
          feeTitle: 'هزینه سرویس رفت و برگشت',
          description: 'پرداخت نقدی به دفتر',
          isIncluded: true,
          isCash: true,
          isInstallment: false,
          cashStages: [CashStage(title: 'مرحله اول', amount: 800000, dueDate: now, isSettled: true)],
        ),
        TuitionRecord(
          id: 'F3',
          studentName: 'آرتین شجاعی',
          className: 'پیش‌دبستانی آفتاب ☀️',
          amount: 600000,
          status: 'معوقه / بدهکار 🔴',
          date: now,
          receiptNo: 'RC-9829',
          feeType: 'ناهار',
          feeTitle: 'هزینه برنامه ناهار گرم',
          description: 'اختیاری',
          isIncluded: false, // غیر شمول در ابتدا
        ),
        TuitionRecord(
          id: 'F4',
          studentName: 'سارا محمدی',
          className: 'پیش‌دبستانی آفتاب ☀️',
          amount: 4500000,
          status: 'در انتظار تأیید 🟡',
          date: now,
          receiptNo: 'RC-9822',
          feeType: 'شهریه',
          feeTitle: 'شهریه پایه',
          description: 'درخواست پرداخت اقساطی',
          isIncluded: true,
          isCash: false,
          isInstallment: true,
          installmentCount: 4,
          documentNote: '۴ فقره چک صیادی دریافت شد',
        ),
      ];
      await _saveFinancialData();
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFinancialData() async {
    if (!_canManageLedger) return;
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

  /// ویرایش توضیحات و تنظیمات پرداخت یک بند هزینه
  Future<void> _editRecordDialog(TuitionRecord record) async {
    if (!_canManageLedger) return;
    final descCtrl = TextEditingController(text: record.description);
    final docNoteCtrl = TextEditingController(text: record.documentNote);
    String currentStatus = record.status;
    bool isCash = record.isCash;
    bool isInstallment = record.isInstallment;
    int installmentCount = record.installmentCount;

    // مراحل نقدی
    List<CashStage> stages = List.from(record.cashStages);
    if (stages.isEmpty) {
      stages = [CashStage(title: 'مرحله اول', amount: record.amount, dueDate: JalaliDate.now().formatted, isSettled: record.status.contains('پرداخت‌شده'))];
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('پیکربندی بند مالی: ${record.feeTitle}'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نوآموز: ${record.studentName} (${record.className})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('مبلغ کل بند: ${_formatNumber(record.amount)} تومان | شماره فیش: ${record.receiptNo}'),
                    const SizedBox(height: 16),

                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'وضعیت کلی پرداخت', border: OutlineInputBorder()),
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

                    // انتخاب روش پرداخت (نقد / اقساط)
                    const Text('نوع پرداخت:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Checkbox(
                          value: isCash,
                          onChanged: (v) => setDState(() => isCash = v ?? false),
                        ),
                        const Text('پرداخت نقدی'),
                        const SizedBox(width: 20),
                        Checkbox(
                          value: isInstallment,
                          onChanged: (v) => setDState(() => isInstallment = v ?? false),
                        ),
                        const Text('پرداخت اقساطی'),
                      ],
                    ),

                    if (isCash) ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('مراحل پرداخت نقدی (حداکثر ۳ مرحله): ${stages.length} مرحله', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF01579B))),
                          if (stages.length < 3)
                            TextButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('افزودن مرحله'),
                              onPressed: () {
                                setDState(() {
                                  final numName = stages.length == 1 ? 'مرحله دوم' : 'مرحله سوم';
                                  stages.add(CashStage(title: numName, amount: 0, dueDate: JalaliDate.now().formatted));
                                });
                              },
                            ),
                        ],
                      ),
                      for (int i = 0; i < stages.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(stages[i].title, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: '${stages[i].amount}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'مبلغ', isDense: true, border: OutlineInputBorder()),
                                  onChanged: (val) {
                                    final amt = int.tryParse(val) ?? 0;
                                    stages[i] = stages[i].copyWith(amount: amt);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Checkbox(
                                value: stages[i].isSettled,
                                onChanged: (v) {
                                  setDState(() {
                                    stages[i] = stages[i].copyWith(isSettled: v ?? false);
                                  });
                                },
                              ),
                              const Text('تسویه', style: TextStyle(fontSize: 11)),
                              if (stages.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  onPressed: () {
                                    setDState(() {
                                      stages.removeAt(i);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],

                    if (isInstallment) ...[
                      const Divider(),
                      const Text('تنظیمات اقساط ماهانه:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF01579B))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('تعداد اقساط: '),
                          DropdownButton<int>(
                            value: installmentCount,
                            items: List.generate(10, (idx) => idx + 1)
                                .map((countVal) => DropdownMenuItem(value: countVal, child: Text('$countVal قسط ماهانه')))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDState(() => installmentCount = val);
                            },
                          ),
                        ],
                      ),
                    ],

                    const Divider(),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'توضیحات و یادداشت مدیر',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: docNoteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'مستندات و تصویر فیش/چک صیادی (توضیحات یا لینک)',
                              prefixIcon: Icon(Icons.attach_file_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text('آپلود عکس', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDState(() {
                              docNoteCtrl.text = 'تصویر فیش/سند مالی ضمیمه شد (فایل تصویر)';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📸 تصویر فیش/سند مالی انتخاب و ثبت گردید.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
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

    if (updated == true && _canManageLedger) {
      final idx = _records.indexWhere((x) => x.id == record.id);
      if (idx >= 0) {
        final newRecord = _records[idx].copyWith(
          status: currentStatus,
          description: descCtrl.text.trim(),
          isCash: isCash,
          isInstallment: isInstallment,
          cashStages: stages,
          installmentCount: installmentCount,
          documentNote: docNoteCtrl.text.trim(),
        );

        if (Backend.ready) {
          String statusDb = 'overdue';
          if (currentStatus.contains('پرداخت‌شده')) statusDb = 'paid';
          if (currentStatus.contains('انتظار')) statusDb = 'pending';

          await Backend.client
              .from('tuition_records')
              .update({
                'status': statusDb,
                'description': descCtrl.text.trim(),
              })
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
          details: '${newRecord.studentName} • ${newRecord.feeTitle} • ${newRecord.status}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ مشخصات و تنظیمات پرداخت به روزرسانی شد.'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  /// باز کردن دایالوگ/پوشه جامع صورت‌حساب مالی نوآموز
  void _showStudentFinancialDetailsModal(String studentName, List<TuitionRecord> studentRecords) {
    if (studentRecords.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => StudentFinancialDetailsDialog(
        studentName: studentName,
        allRecords: _records,
        canManageLedger: _canManageLedger,
        onSaveFinancialData: _saveFinancialData,
        onEditRecord: (record) async {
          await _editRecordDialog(record);
          setState(() {});
        },
        onAddInvoice: _showAddInvoiceDialog,
      ),
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
    if (!_canManageLedger) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شما اجازهٔ ثبت رکورد مالی را ندارید'), backgroundColor: Colors.red),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: prefilledStudent ?? '');

    // لیست کلاس‌های ممکن جهت جلوگیری از خطای نبود value در DropdownButton
    final classOptions = <String>{
      if (prefilledClass != null && prefilledClass.isNotEmpty) prefilledClass,
      'پیش‌دبستانی آفتاب ☀️',
      'اول دبستان ستاره 🌟',
      'دوم دبستان مهتاب 🌙',
      ...kClassNames.map((name) => classLabel(name)),
    }.toList();

    String selectedClass = (prefilledClass != null && classOptions.contains(prefilledClass))
        ? prefilledClass
        : classOptions.first;

    final amountCtrl = TextEditingController();
    String selectedStatus = 'پرداخت‌شده 🟢';
    String selectedFeeType = 'شهریه';
    final feeTitleCtrl = TextEditingController(text: 'شهریه ماهانه');
    final descCtrl = TextEditingController();
    final receiptCtrl = TextEditingController(text: 'RC-${DateTime.now().millisecond}');
    bool isIncluded = true;
    bool isCash = true;
    bool isInstallment = false;

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
                    Row(
                      children: [
                        Checkbox(
                          value: isIncluded,
                          onChanged: (v) => setDialogState(() => isIncluded = v ?? true),
                        ),
                        const Text('شمول این هزینه در کل صورت‌حساب نوآموز', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                          items: classOptions.map((cName) {
                            return DropdownMenuItem<String>(
                              value: cName,
                              child: Text(cName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedClass = val);
                            }
                          },
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
                                  DropdownMenuItem(value: 'شهریه', child: Text('شهریه سالانه')),
                                  DropdownMenuItem(value: 'ناهار', child: Text('ناهار')),
                                  DropdownMenuItem(value: 'میان‌وعده', child: Text('میان‌وعده')),
                                  DropdownMenuItem(value: 'نگهداری', child: Text('نگهداری اضافه')),
                                  DropdownMenuItem(value: 'اردو', child: Text('اردو و فوق‌برنامه')),
                                  DropdownMenuItem(value: 'سرویس', child: Text('سرویس')),
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
                    Row(
                      children: [
                        Checkbox(value: isCash, onChanged: (v) => setDialogState(() => isCash = v ?? false)),
                        const Text('پرداخت نقدی'),
                        const SizedBox(width: 12),
                        Checkbox(value: isInstallment, onChanged: (v) => setDialogState(() => isInstallment = v ?? false)),
                        const Text('پرداخت اقساطی'),
                      ],
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
                  if (!_canManageLedger) {
                    Navigator.pop(ctx);
                    return;
                  }
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
                      isIncluded: isIncluded,
                      isCash: isCash,
                      isInstallment: isInstallment,
                    );

                    if (Backend.ready) {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ServerDirectory.ensureLoaded();
                        final sid = ServerDirectory.studentId(newRecord.studentName, newRecord.className);
                        if (sid == null) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('نوآموز در سرور پیدا نشد؛ ثبت انجام نشد'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        String dbStatus = 'overdue';
                        if (selectedStatus.contains('پرداخت‌شده')) dbStatus = 'paid';
                        if (selectedStatus.contains('انتظار')) dbStatus = 'pending';
                        await Backend.client.from('tuition_records').insert({
                          'student_id': sid,
                          'amount': newRecord.amount,
                          'status': dbStatus,
                          'receipt_no': newRecord.receiptNo,
                          'jalali_date': newRecord.date,
                          'fee_type': newRecord.feeType,
                          'fee_title': newRecord.feeTitle,
                          'description': newRecord.description,
                        });
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('ثبت در سرور انجام نشد: $e'), backgroundColor: Colors.red),
                        );
                        return;
                      }
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

                    if (ctx.mounted) {
                      final messenger = ScaffoldMessenger.of(ctx);
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('✅ بند مالی جدید با موفقیت ثبت شد!'), backgroundColor: Colors.green),
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
      if (r.isIncluded && r.status.contains('پرداخت‌شده')) sum += r.amount;
    }
    return sum;
  }

  int get _totalPending {
    int sum = 0;
    for (var r in _records) {
      if (r.isIncluded && (r.status.contains('بدهکار') || r.status.contains('معوقه') || r.status.contains('انتظار'))) sum += r.amount;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    if (!_canReadLedger) {
      return Scaffold(
        appBar: AppBar(title: const Text('امور مالی و حسابداری شهریه')),
        body: const Center(child: Text('شما اجازهٔ مشاهدهٔ دفتر مالی را ندارید.')),
      );
    }

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
                headers: ['نام نوآموز', 'کلاس', 'شمول', 'بخش هزینه', 'عنوان هزینه', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                rows: _records
                    .map((r) => [
                          r.studentName,
                          r.className,
                          r.isIncluded ? 'شامل' : 'غیرشمول',
                          r.feeType,
                          r.feeTitle,
                          r.amount,
                          r.status,
                          r.date,
                          r.receiptNo,
                          r.description
                        ])
                    .toList(),
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
                headers: ['نام نوآموز', 'کلاس', 'شمول', 'عنوان هزینه', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                rows: _records
                    .map((r) => [
                          r.studentName,
                          r.className,
                          r.isIncluded ? 'بله' : 'خیر',
                          r.feeTitle,
                          r.amount,
                          r.status,
                          r.date,
                          r.receiptNo,
                          r.description
                        ])
                    .toList(),
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
                headers: ['نام نوآموز', 'کلاس', 'شمول', 'عنوان هزینه', 'مبلغ (تومان)', 'وضعیت', 'تاریخ', 'شماره فیش', 'توضیحات'],
                rows: _records
                    .map((r) => [
                          r.studentName,
                          r.className,
                          r.isIncluded ? 'بله' : 'خیر',
                          r.feeTitle,
                          r.amount,
                          r.status,
                          r.date,
                          r.receiptNo,
                          r.description
                        ])
                    .toList(),
                fileName: 'financial_report_all_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _canManageLedger ? () => _showAddInvoiceDialog() : null,
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
                                const Text('کل درآمد وصول‌شده (شامل‌شده)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
                                const Text('مجموع معوقات و در انتظار (شامل‌شده)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
                        'لیست نوآموزان و وضعیت حساب مالی (جهت مشاهده جدول صورت‌حساب کلیک کنید):',
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

                                final includedItems = studentRecords.where((r) => r.isIncluded).toList();
                                final total = includedItems.fold(0, (sum, r) => sum + r.amount);
                                final paid = includedItems
                                    .where((r) => r.status.contains('پرداخت‌شده'))
                                    .fold(0, (sum, r) => sum + r.amount);
                                final pending = total - paid;
                                final hasPending = pending > 0 || includedItems.any((r) => r.status.contains('انتظار'));

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
                                                'کل بندها: ${studentRecords.length} (شمول: ${includedItems.length}) • کل: ${_formatNumber(total)} تومان | واریزی: ${_formatNumber(paid)} تومان',
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
                                                Text('مشاهده جدول صورت‌حساب', style: TextStyle(fontSize: 11, color: Color(0xFF01579B), fontWeight: FontWeight.bold)),
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

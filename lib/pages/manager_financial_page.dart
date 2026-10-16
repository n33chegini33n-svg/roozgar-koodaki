import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/export_helper.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../utils/jalali.dart';
import '../models/school_classes.dart';
import '../services/backend.dart';

/// مدل مرحله پرداخت نقدی (حداکثر ۳ مرحله)
class CashStage {
  final String title; // مرحله اول، مرحله دوم، مرحله سوم
  final int amount;
  final String dueDate;
  final bool isSettled;

  CashStage({
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isSettled = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'amount': amount,
        'dueDate': dueDate,
        'isSettled': isSettled,
      };

  factory CashStage.fromJson(Map<String, dynamic> json) => CashStage(
        title: json['title'] ?? 'مرحله پرداخت',
        amount: json['amount'] ?? 0,
        dueDate: json['dueDate'] ?? JalaliDate.now().formatted,
        isSettled: json['isSettled'] ?? false,
      );

  CashStage copyWith({
    String? title,
    int? amount,
    String? dueDate,
    bool? isSettled,
  }) {
    return CashStage(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

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

  // ویژگی‌های جدید جهت صورت‌حساب اختصاصی
  final bool isIncluded; // تیک شمول هزینه
  final bool isCash; // پرداخت نقدی
  final bool isInstallment; // پرداخت اقساطی
  final List<CashStage> cashStages; // مراحل پرداخت نقدی (حداکثر ۳ مرحله)
  final int installmentCount; // تعداد اقساط (۱ تا ۱۰ قسط)
  final List<bool> installmentSettled; // وضعیت تسویه تک‌تک اقساط
  final String documentNote; // مستندات و چک/فیش

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
    this.isIncluded = true,
    this.isCash = true,
    this.isInstallment = false,
    List<CashStage>? cashStages,
    this.installmentCount = 1,
    List<bool>? installmentSettled,
    this.documentNote = '',
  })  : cashStages = cashStages ?? [
          CashStage(title: 'مرحله اول', amount: amount, dueDate: date, isSettled: status.contains('پرداخت‌شده')),
          CashStage(title: 'مرحله دوم', amount: 0, dueDate: date, isSettled: false),
          CashStage(title: 'مرحله سوم', amount: 0, dueDate: date, isSettled: false),
        ],
        installmentSettled = installmentSettled ?? List.generate(installmentCount > 0 ? installmentCount : 1, (i) => status.contains('پرداخت‌شده'));

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
        'isIncluded': isIncluded,
        'isCash': isCash,
        'isInstallment': isInstallment,
        'cashStages': cashStages.map((e) => e.toJson()).toList(),
        'installmentCount': installmentCount,
        'installmentSettled': installmentSettled,
        'documentNote': documentNote,
      };

  factory TuitionRecord.fromJson(Map<String, dynamic> json) {
    List<CashStage> stages = [];
    if (json['cashStages'] != null && json['cashStages'] is List) {
      stages = (json['cashStages'] as List).map((e) => CashStage.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    final amt = json['amount'] ?? 0;
    final dt = json['date'] ?? JalaliDate.now().formatted;
    final st = json['status'] ?? 'پرداخت‌شده 🟢';
    if (stages.isEmpty) {
      stages = [
        CashStage(title: 'مرحله اول', amount: amt, dueDate: dt, isSettled: st.contains('پرداخت‌شده')),
        CashStage(title: 'مرحله دوم', amount: 0, dueDate: dt, isSettled: false),
        CashStage(title: 'مرحله سوم', amount: 0, dueDate: dt, isSettled: false),
      ];
    }
    final instCount = json['installmentCount'] ?? 1;
    List<bool> instSettled = [];
    if (json['installmentSettled'] != null && json['installmentSettled'] is List) {
      instSettled = List<bool>.from(json['installmentSettled']);
    } else {
      instSettled = List.generate(instCount, (_) => st.contains('پرداخت‌شده'));
    }

    return TuitionRecord(
      id: json['id'] ?? '',
      studentName: json['studentName'] ?? '',
      className: normalizeClassName(((json['className']) ?? '').toString()),
      amount: amt,
      status: st,
      date: dt,
      receiptNo: json['receiptNo'] ?? 'REC-001',
      feeType: json['feeType'] ?? 'شهریه',
      feeTitle: json['feeTitle'] ?? 'شهریه',
      description: json['description'] ?? '',
      isIncluded: json['isIncluded'] ?? true,
      isCash: json['isCash'] ?? true,
      isInstallment: json['isInstallment'] ?? false,
      cashStages: stages,
      installmentCount: instCount,
      installmentSettled: instSettled,
      documentNote: json['documentNote'] ?? '',
    );
  }

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
    bool? isIncluded,
    bool? isCash,
    bool? isInstallment,
    List<CashStage>? cashStages,
    int? installmentCount,
    List<bool>? installmentSettled,
    String? documentNote,
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
      isIncluded: isIncluded ?? this.isIncluded,
      isCash: isCash ?? this.isCash,
      isInstallment: isInstallment ?? this.isInstallment,
      cashStages: cashStages ?? this.cashStages,
      installmentCount: installmentCount ?? this.installmentCount,
      installmentSettled: installmentSettled ?? this.installmentSettled,
      documentNote: documentNote ?? this.documentNote,
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
    if (!PermissionService.instance.can(Session.role, Perm.viewFinancial)) return;
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
                                .map((num) => DropdownMenuItem(value: num, child: Text('$num قسط ماهانه')))
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

    if (updated == true) {
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
    final className = studentRecords.first.className;

    showDialog(
      context: context,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // دریافت آخرین رکوردهای این نوآموز
            final currentStudentRecords = _records.where((r) => r.studentName == studentName).toList();

            // فقط هزینه‌های شمول یافته (isIncluded == true) در محاسبات آورده می‌شوند
            final includedRecords = currentStudentRecords.where((item) => item.isIncluded).toList();
            int totalCharges = includedRecords.fold(0, (sum, item) => sum + item.amount);
            int paidCharges = includedRecords
                .where((item) => item.status.contains('پرداخت‌شده'))
                .fold(0, (sum, item) => sum + item.amount);
            int pendingCharges = totalCharges - paidCharges;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  width: 1000,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                                    'جدول صورت‌حساب مالی نوآموز: $studentName',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                                  ),
                                  Text('کلاس: $className • تعداد بندهای هزینه: ${currentStudentRecords.length}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                      const SizedBox(height: 14),

                      // خلاصه سریع صورت‌حساب این نوآموز
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryChip('جمع کل هزینه‌های شمول‌یافته', '${_formatNumber(totalCharges)} تومان', Colors.blue.shade900),
                            _summaryChip('کل پرداخت‌شده', '${_formatNumber(paidCharges)} تومان', Colors.green.shade800),
                            _summaryChip('مانده / بدهکار', '${_formatNumber(pendingCharges)} تومان', pendingCharges > 0 ? Colors.red.shade800 : Colors.green.shade800),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

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
                                title: 'صورت‌حساب رسمی مالی $studentName ($className)',
                                headers: ['شمول هزینه', 'بخش/عنوان', 'مبلغ (تومان)', 'نوع پرداخت', 'وضعیت', 'تاریخ', 'فیش/سند', 'توضیحات و مستندات'],
                                rows: currentStudentRecords
                                    .map((r) => [
                                          r.isIncluded ? 'شامل ✅' : 'عدم شمول ❌',
                                          '${r.feeType} - ${r.feeTitle}',
                                          r.amount,
                                          '${r.isCash ? "نقد " : ""}${r.isInstallment ? "اقساط (${r.installmentCount})" : ""}',
                                          r.status,
                                          r.date,
                                          r.receiptNo,
                                          '${r.description} ${r.documentNote.isNotEmpty ? " | سند: ${r.documentNote}" : ""}'
                                        ])
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
                                title: 'صورت‌حساب رسمی مالی $studentName ($className)',
                                headers: ['شمول', 'عنوان هزینه', 'مبلغ (تومان)', 'نوع پرداخت', 'وضعیت', 'تاریخ', 'توضیحات و مستندات'],
                                rows: currentStudentRecords
                                    .map((r) => [
                                          r.isIncluded ? 'بله' : 'خیر',
                                          '${r.feeType} - ${r.feeTitle}',
                                          r.amount,
                                          '${r.isCash ? "نقدی" : ""}${r.isCash && r.isInstallment ? " / " : ""}${r.isInstallment ? "اقساطی" : ""}',
                                          r.status,
                                          r.date,
                                          '${r.description} ${r.documentNote.isNotEmpty ? " | سند: ${r.documentNote}" : ""}'
                                        ])
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
                                headers: ['شمول', 'عنوان هزینه', 'مبلغ (تومان)', 'نوع پرداخت', 'وضعیت', 'تاریخ', 'توضیحات و مستندات'],
                                rows: currentStudentRecords
                                    .map((r) => [
                                          r.isIncluded ? 'بله' : 'خیر',
                                          '${r.feeType} - ${r.feeTitle}',
                                          r.amount,
                                          '${r.isCash ? "نقدی" : ""}${r.isCash && r.isInstallment ? " / " : ""}${r.isInstallment ? "اقساطی" : ""}',
                                          r.status,
                                          r.date,
                                          '${r.description} ${r.documentNote.isNotEmpty ? " | سند: ${r.documentNote}" : ""}'
                                        ])
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
                            label: const Text('افزودن هزینه جدید'),
                            onPressed: () async {
                              await _showAddInvoiceDialog(prefilledStudent: studentName, prefilledClass: className);
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // جدول اصلی صورت‌حساب نوآموز (DataTable)
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
                                columnSpacing: 16,
                                headingRowHeight: 48,
                                dataRowMaxHeight: 88,
                                dataRowMinHeight: 70,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF01579B).withOpacity(0.08)),
                                columns: const [
                                  DataColumn(label: SizedBox(width: 100, child: Text('تیک شمول هزینه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center))),
                                  DataColumn(label: SizedBox(width: 150, child: Text('عنوان هزینه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                                  DataColumn(label: SizedBox(width: 120, child: Text('مبلغ (تومان)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                                  DataColumn(label: SizedBox(width: 220, child: Text('نوع پرداخت (نقد / اقساط)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                                  DataColumn(label: SizedBox(width: 140, child: Text('وضعیت و واریز والد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                                  DataColumn(label: SizedBox(width: 180, child: Text('توضیحات و مستندات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                                  DataColumn(label: SizedBox(width: 70, child: Text('عملیات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center))),
                                ],
                                rows: currentStudentRecords.map((rec) {
                                  // محاسبه مراحل پرداخت نقدی (۳ مرحله)
                                  List<CashStage> stages = List.from(rec.cashStages);
                                  while (stages.length < 3) {
                                    final numName = stages.length == 0 ? 'مرحله اول' : (stages.length == 1 ? 'مرحله دوم' : 'مرحله سوم');
                                    stages.add(CashStage(title: numName, amount: 0, dueDate: rec.date));
                                  }

                                  // محاسبه اقساط (تا ۱۰ قسط)
                                  final instCount = rec.installmentCount > 0 ? rec.installmentCount : 1;
                                  List<bool> instSettled = List.from(rec.installmentSettled);
                                  if (instSettled.length < instCount) {
                                    instSettled.addAll(List.generate(instCount - instSettled.length, (_) => false));
                                  } else if (instSettled.length > instCount) {
                                    instSettled = instSettled.sublist(0, instCount);
                                  }

                                  return DataRow(
                                    color: WidgetStateProperty.resolveWith((states) {
                                      return rec.isIncluded ? null : Colors.grey.shade100;
                                    }),
                                    cells: [
                                      // ۱. چک‌باکس شمول هزینه
                                      DataCell(
                                        SizedBox(
                                          width: 100,
                                          child: Center(
                                            child: Checkbox(
                                              value: rec.isIncluded,
                                              activeColor: const Color(0xFF01579B),
                                              onChanged: (val) async {
                                                final updatedValue = val ?? false;
                                                final idx = _records.indexWhere((x) => x.id == rec.id);
                                                if (idx >= 0) {
                                                  setState(() {
                                                    _records[idx] = _records[idx].copyWith(isIncluded: updatedValue);
                                                  });
                                                  await _saveFinancialData();
                                                  setModalState(() {});
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ۲. عنوان هزینه
                                      DataCell(
                                        SizedBox(
                                          width: 150,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                rec.feeTitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  decoration: rec.isIncluded ? null : TextDecoration.lineThrough,
                                                  color: rec.isIncluded ? Colors.black87 : Colors.grey,
                                                ),
                                              ),
                                              Text('بخش: ${rec.feeType}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ۳. مبلغ (تومان) - قابل ویرایش جهت تغییرات تورمی توسط مدیر
                                      DataCell(
                                        SizedBox(
                                          width: 120,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${_formatNumber(rec.amount)} تومان',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    decoration: rec.isIncluded ? null : TextDecoration.lineThrough,
                                                    color: rec.isIncluded ? Colors.blue.shade900 : Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () async {
                                                  final controller = TextEditingController(text: '${rec.amount}');
                                                  final newAmt = await showDialog<int>(
                                                    context: context,
                                                    builder: (c) => Directionality(
                                                      textDirection: TextDirection.rtl,
                                                      child: AlertDialog(
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                        title: Text('ویرایش مبلغ ${rec.feeTitle}'),
                                                        content: TextField(
                                                          controller: controller,
                                                          keyboardType: TextInputType.number,
                                                          autofocus: true,
                                                          decoration: const InputDecoration(
                                                            labelText: 'مبلغ جدید (تومان)',
                                                            border: OutlineInputBorder(),
                                                          ),
                                                        ),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('انصراف')),
                                                          ElevatedButton(
                                                            onPressed: () => Navigator.pop(c, int.tryParse(controller.text.trim())),
                                                            child: const Text('ثبت مبلغ'),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                  if (newAmt != null && newAmt >= 0) {
                                                    final idx = _records.indexWhere((x) => x.id == rec.id);
                                                    if (idx >= 0) {
                                                      setState(() {
                                                        _records[idx] = _records[idx].copyWith(amount: newAmt);
                                                      });
                                                      await _saveFinancialData();
                                                      setModalState(() {});
                                                    }
                                                  }
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.all(2.0),
                                                  child: Icon(Icons.edit_rounded, size: 16, color: Colors.blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ۴. نوع پرداخت (نقد / اقساط) + چک‌باکس‌های تعاملی مراحل
                                      DataCell(
                                        SizedBox(
                                          width: 220,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  FilterChip(
                                                    visualDensity: VisualDensity.compact,
                                                    labelStyle: const TextStyle(fontSize: 10),
                                                    label: Text('نقد', style: TextStyle(color: rec.isCash ? Colors.green.shade900 : Colors.black54)),
                                                    selected: rec.isCash,
                                                    selectedColor: Colors.green.shade100,
                                                    onSelected: (val) async {
                                                      final idx = _records.indexWhere((x) => x.id == rec.id);
                                                      if (idx >= 0) {
                                                        setState(() {
                                                          _records[idx] = _records[idx].copyWith(isCash: val);
                                                        });
                                                        await _saveFinancialData();
                                                        setModalState(() {});
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(width: 4),
                                                  FilterChip(
                                                    visualDensity: VisualDensity.compact,
                                                    labelStyle: const TextStyle(fontSize: 10),
                                                    label: Text(
                                                      'اقساط',
                                                      style: TextStyle(color: rec.isInstallment ? Colors.purple.shade900 : Colors.black54),
                                                    ),
                                                    selected: rec.isInstallment,
                                                    selectedColor: Colors.purple.shade100,
                                                    onSelected: (val) async {
                                                      final idx = _records.indexWhere((x) => x.id == rec.id);
                                                      if (idx >= 0) {
                                                        setState(() {
                                                          _records[idx] = _records[idx].copyWith(
                                                            isInstallment: val,
                                                            installmentCount: 10,
                                                          );
                                                        });
                                                        await _saveFinancialData();
                                                        setModalState(() {});
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),

                                              // اگر پرداخت نقدی فعال باشد: ۳ مربعی کوچیک زیرش
                                              if (rec.isCash)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: List.generate(3, (stageIdx) {
                                                    final isChecked = stages[stageIdx].isSettled;
                                                    return InkWell(
                                                      onTap: () async {
                                                        final idx = _records.indexWhere((x) => x.id == rec.id);
                                                        if (idx >= 0) {
                                                          final updatedStages = List<CashStage>.from(stages);
                                                          updatedStages[stageIdx] = updatedStages[stageIdx].copyWith(isSettled: !isChecked);

                                                          // بررسی وضعیت جدید
                                                          final allSettled = updatedStages.every((st) => st.isSettled);
                                                          final anySettled = updatedStages.any((st) => st.isSettled);
                                                          String newStatus = allSettled
                                                              ? 'پرداخت‌شده 🟢'
                                                              : (anySettled ? 'در انتظار تأیید 🟡' : 'معوقه / بدهکار 🔴');

                                                          setState(() {
                                                            _records[idx] = _records[idx].copyWith(
                                                              cashStages: updatedStages,
                                                              status: newStatus,
                                                            );
                                                          });
                                                          await _saveFinancialData();
                                                          setModalState(() {});
                                                        }
                                                      },
                                                      child: Container(
                                                        margin: const EdgeInsets.only(left: 4, top: 2),
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: isChecked ? Colors.green.shade600 : Colors.grey.shade200,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: isChecked ? Colors.green.shade800 : Colors.grey.shade400),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                                              size: 12,
                                                              color: isChecked ? Colors.white : Colors.black54,
                                                            ),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                              'مرحله ${stageIdx + 1}',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                                                color: isChecked ? Colors.white : Colors.black87,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ),

                                              // اگر پرداخت اقساطی فعال باشد: ۱۰ مربع کوچک تحت عنوان اقساط
                                              if (rec.isInstallment)
                                                Wrap(
                                                  spacing: 2,
                                                  runSpacing: 2,
                                                  children: List.generate(instCount, (instIdx) {
                                                    final isChecked = instSettled[instIdx];
                                                    return InkWell(
                                                      onTap: () async {
                                                        final idx = _records.indexWhere((x) => x.id == rec.id);
                                                        if (idx >= 0) {
                                                          final updatedSettled = List<bool>.from(instSettled);
                                                          updatedSettled[instIdx] = !isChecked;

                                                          final allSettled = updatedSettled.every((st) => st);
                                                          final anySettled = updatedSettled.any((st) => st);
                                                          String newStatus = allSettled
                                                              ? 'پرداخت‌شده 🟢'
                                                              : (anySettled ? 'در انتظار تأیید 🟡' : 'معوقه / بدهکار 🔴');

                                                          setState(() {
                                                            _records[idx] = _records[idx].copyWith(
                                                              installmentSettled: updatedSettled,
                                                              status: newStatus,
                                                            );
                                                          });
                                                          await _saveFinancialData();
                                                          setModalState(() {});
                                                        }
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: isChecked ? Colors.purple.shade700 : Colors.purple.shade50,
                                                          borderRadius: BorderRadius.circular(3),
                                                          border: Border.all(color: isChecked ? Colors.purple.shade900 : Colors.purple.shade200),
                                                        ),
                                                        child: Text(
                                                          'ق${instIdx + 1}',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                                            color: isChecked ? Colors.white : Colors.purple.shade900,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ۵. وضعیت و واریز والد
                                      DataCell(
                                        SizedBox(
                                          width: 140,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(rec.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              Text('فیش/پیگیری: ${rec.receiptNo}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ۶. توضیحات و مستندات / پیوست
                                      DataCell(
                                        SizedBox(
                                          width: 180,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                rec.description.isEmpty ? 'بدون یادداشت' : rec.description,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                              if (rec.documentNote.isNotEmpty)
                                                Row(
                                                  children: [
                                                    const Icon(Icons.attach_file, size: 12, color: Colors.blue),
                                                    Expanded(
                                                      child: Text(
                                                        rec.documentNote,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // ۷. عملیات
                                      DataCell(
                                        SizedBox(
                                          width: 70,
                                          child: Center(
                                            child: IconButton(
                                              icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF01579B)),
                                              tooltip: 'پیکربندی اقساط/مراحل و مستندات',
                                              onPressed: () async {
                                                await _editRecordDialog(rec);
                                                setModalState(() {});
                                                setState(() {});
                                              },
                                            ),
                                          ),
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

    // لیست کلاس‌های ممکن جهت جلوگیری از خطای نبود value در DropdownButton
    final classOptions = [
      if (prefilledClass != null && prefilledClass.isNotEmpty) prefilledClass,
      'پیش‌دبستانی آفتاب ☀️',
      'اول دبستان ستاره 🌟',
      'دوم دبستان مهتاب 🌙',
      ...kClassNames.map((name) => classLabel(name)),
    ].toSet().toList();

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

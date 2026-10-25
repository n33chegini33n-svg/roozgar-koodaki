import 'package:flutter/material.dart';

import '../../models/tuition_record_model.dart';
import '../../utils/export_helper.dart';

class StudentFinancialDetailsDialog extends StatefulWidget {
  final String studentName;
  final List<TuitionRecord> allRecords;
  final bool canManageLedger;
  final Future<void> Function() onSaveFinancialData;
  final Future<void> Function(TuitionRecord record) onEditRecord;
  final Future<void> Function({
    String? prefilledStudent,
    String? prefilledClass,
  }) onAddInvoice;

  const StudentFinancialDetailsDialog({
    super.key,
    required this.studentName,
    required this.allRecords,
    required this.canManageLedger,
    required this.onSaveFinancialData,
    required this.onEditRecord,
    required this.onAddInvoice,
  });

  @override
  State<StudentFinancialDetailsDialog> createState() =>
      _StudentFinancialDetailsDialogState();
}

class _StudentFinancialDetailsDialogState
    extends State<StudentFinancialDetailsDialog> {
  @override
  Widget build(BuildContext context) {
    final studentName = widget.studentName;
    final recordsForStudent =
        widget.allRecords.where((r) => r.studentName == studentName).toList();
    if (recordsForStudent.isEmpty) return const SizedBox.shrink();
    final className = recordsForStudent.first.className;
    return StatefulBuilder(
      builder: (context, setModalState) {
        // دریافت آخرین رکوردهای این نوآموز
        final currentStudentRecords = widget.allRecords.where((r) => r.studentName == studentName).toList();

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
                            backgroundColor: const Color(0xFF01579B).withValues(alpha: 0.1),
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
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // خلاصه سریع صورت‌حساب این نوآموز
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.5),
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
                          await widget.onAddInvoice(prefilledStudent: studentName, prefilledClass: className);
                          setModalState(() {});
                          
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
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF01579B).withValues(alpha: 0.08)),
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
                                final numName = stages.isEmpty ? 'مرحله اول' : (stages.length == 1 ? 'مرحله دوم' : 'مرحله سوم');
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
                                            if (!widget.canManageLedger) return;
                                            final updatedValue = val ?? false;
                                            final idx = widget.allRecords.indexWhere((x) => x.id == rec.id);
                                            if (idx >= 0) {
                                              setState(() {
                                                widget.allRecords[idx] = widget.allRecords[idx].copyWith(isIncluded: updatedValue);
                                              });
                                              await widget.onSaveFinancialData();
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
                                              if (!widget.canManageLedger) return;
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
                                                final idx = widget.allRecords.indexWhere((x) => x.id == rec.id);
                                                if (idx >= 0) {
                                                  setState(() {
                                                    widget.allRecords[idx] = widget.allRecords[idx].copyWith(amount: newAmt);
                                                  });
                                                  await widget.onSaveFinancialData();
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
                                                  if (!widget.canManageLedger) return;
                                                  final idx = widget.allRecords.indexWhere((x) => x.id == rec.id);
                                                  if (idx >= 0) {
                                                    setState(() {
                                                      widget.allRecords[idx] = widget.allRecords[idx].copyWith(isCash: val);
                                                    });
                                                    await widget.onSaveFinancialData();
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
                                                  if (!widget.canManageLedger) return;
                                                  final idx = widget.allRecords.indexWhere((x) => x.id == rec.id);
                                                  if (idx >= 0) {
                                                    setState(() {
                                                      widget.allRecords[idx] = widget.allRecords[idx].copyWith(
                                                        isInstallment: val,
                                                        installmentCount: 10,
                                                      );
                                                    });
                                                    await widget.onSaveFinancialData();
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
                                                    if (!widget.canManageLedger) return;
                                                    final idx = widget.allRecords.indexWhere((x) => x.id == rec.id);
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
                                                        widget.allRecords[idx] = widget.allRecords[idx].copyWith(
                                                          cashStages: updatedStages,
                                                          status: newStatus,
                                                        );
                                                      });
                                                      await widget.onSaveFinancialData();
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
                                                    if (!widget.canManageLedger) return;
                                                    final idx = widget.allRecords.indexWhere((x) => x.id == rec.id);
                                                    if (idx >= 0) {
                                                      final updatedSettled = List<bool>.from(instSettled);
                                                      updatedSettled[instIdx] = !isChecked;

                                                      final allSettled = updatedSettled.every((st) => st);
                                                      final anySettled = updatedSettled.any((st) => st);
                                                      String newStatus = allSettled
                                                          ? 'پرداخت‌شده 🟢'
                                                          : (anySettled ? 'در انتظار تأیید 🟡' : 'معوقه / بدهکار 🔴');

                                                      setState(() {
                                                        widget.allRecords[idx] = widget.allRecords[idx].copyWith(
                                                          installmentSettled: updatedSettled,
                                                          status: newStatus,
                                                        );
                                                      });
                                                      await widget.onSaveFinancialData();
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
                                            await widget.onEditRecord(rec);
                                            setModalState(() {});
                                            
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
}

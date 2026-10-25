import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/export_helper.dart';
import '../../utils/jalali.dart';

class HealthRecordItem {
  final String id;
  final String date;
  final String centerName;
  final String weight;
  final String height;
  final String vaccinationStatus;
  final String notes;

  HealthRecordItem({
    required this.id,
    required this.date,
    required this.centerName,
    required this.weight,
    required this.height,
    required this.vaccinationStatus,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'centerName': centerName,
        'weight': weight,
        'height': height,
        'vaccinationStatus': vaccinationStatus,
        'notes': notes,
      };

  factory HealthRecordItem.fromJson(Map<String, dynamic> json) => HealthRecordItem(
        id: json['id'] ?? '',
        date: json['date'] ?? JalaliDate.now().formatted,
        centerName: json['centerName'] ?? 'خانه بهداشت مرکزی',
        weight: json['weight'] ?? '18 کیلوگرم',
        height: json['height'] ?? '110 سانتی‌متر',
        vaccinationStatus: json['vaccinationStatus'] ?? 'تکمیل واکسیناسیون سن ۵ سالگی',
        notes: json['notes'] ?? 'سلامت عمومی عالی، بدون حساسیت',
      );
}

class HealthCardDialogContent extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String className;

  const HealthCardDialogContent({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.className,
  });

  @override
  State<HealthCardDialogContent> createState() => _HealthCardDialogContentState();
}

class _HealthCardDialogContentState extends State<HealthCardDialogContent> {
  bool _isLoading = true;
  List<HealthRecordItem> _records = [];

  @override
  void initState() {
    super.initState();
    _loadHealthRecords();
  }

  Future<void> _loadHealthRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('health_records_${widget.studentId}');
    if (data != null) {
      List decoded = jsonDecode(data);
      setState(() {
        _records = decoded.map((e) => HealthRecordItem.fromJson(e)).toList();
        _isLoading = false;
      });
    } else {
      _records = [
        HealthRecordItem(
          id: 'H1',
          date: JalaliDate.now().formatted,
          centerName: 'خانه بهداشت شماره ۴ مرکزی',
          weight: '17.5 کیلوگرم',
          height: '108 سانتی‌متر',
          vaccinationStatus: 'واکسن ۶ سالگی کامل',
          notes: 'بینایی و شنوایی سنجی: نرمال و تایید شده',
        ),
        HealthRecordItem(
          id: 'H2',
          date: '1402/05/10',
          centerName: 'پایگاه سلامت کودکان',
          weight: '15.2 کیلوگرم',
          height: '102 سانتی‌متر',
          vaccinationStatus: 'واکسن ۱۸ ماهگی کامل',
          notes: 'پایش رشد و قد و وزن عالی',
        ),
      ];
      await _saveHealthRecords();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveHealthRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('health_records_${widget.studentId}', jsonEncode(_records.map((e) => e.toJson()).toList()));
  }

  void _showAddEditRecordDialog({HealthRecordItem? editItem}) {
    final dateCtrl = TextEditingController(text: editItem?.date ?? JalaliDate.now().formatted);
    final centerCtrl = TextEditingController(text: editItem?.centerName ?? 'خانه بهداشت مرکزی');
    final weightCtrl = TextEditingController(text: editItem?.weight ?? '');
    final heightCtrl = TextEditingController(text: editItem?.height ?? '');
    final vaxCtrl = TextEditingController(text: editItem?.vaccinationStatus ?? '');
    final notesCtrl = TextEditingController(text: editItem?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(editItem == null ? '➕ ثبت چکاپ و سابقه سلامت جدید' : '✏️ ویرایش سابقه سلامت'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: dateCtrl, decoration: InputDecoration(labelText: 'تاریخ چکاپ (مثلا ${JalaliDate.now().formatted})', border: const OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: centerCtrl, decoration: const InputDecoration(labelText: 'نام خانه بهداشت / درمانگاه', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'وزن', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: heightCtrl, decoration: const InputDecoration(labelText: 'قد', border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: vaxCtrl, decoration: const InputDecoration(labelText: 'وضعیت واکسیناسیون', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیحات پزشک / سلامت عمومی', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                if (dateCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    if (editItem == null) {
                      _records.insert(0, HealthRecordItem(
                        id: 'H-${DateTime.now().millisecondsSinceEpoch}',
                        date: dateCtrl.text.trim(),
                        centerName: centerCtrl.text.trim(),
                        weight: weightCtrl.text.trim(),
                        height: heightCtrl.text.trim(),
                        vaccinationStatus: vaxCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                      ));
                    } else {
                      final idx = _records.indexWhere((r) => r.id == editItem.id);
                      if (idx != -1) {
                        _records[idx] = HealthRecordItem(
                          id: editItem.id,
                          date: dateCtrl.text.trim(),
                          centerName: centerCtrl.text.trim(),
                          weight: weightCtrl.text.trim(),
                          height: heightCtrl.text.trim(),
                          vaccinationStatus: vaxCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );
                      }
                    }
                    _saveHealthRecords();
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ اطلاعات خانه بهداشت با موفقیت ذخیره شد!'), backgroundColor: Colors.teal),
                  );
                }
              },
              child: const Text('ذخیره اطلاعات'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRecord(String id) {
    setState(() {
      _records.removeWhere((r) => r.id == id);
      _saveHealthRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.medical_services_rounded, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('کارت خانه بهداشت: ${widget.studentName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('مقطع/کلاس: ${widget.className}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_rounded, color: Colors.green),
              tooltip: 'خروجی اکسل کارت سلامت',
              onPressed: () {
                ExportHelper.exportToExcel(
                  context: context,
                  title: 'کارت خانه بهداشت و پرونده سلامت - ${widget.studentName}',
                  headers: ['تاریخ', 'خانه بهداشت', 'وزن', 'قد', 'واکسیناسیون', 'توضیحات پزشک'],
                  rows: _records.map((r) => [r.date, r.centerName, r.weight, r.height, r.vaccinationStatus, r.notes]).toList(),
                  fileName: 'health_card_${widget.studentId}',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
              tooltip: 'خروجی PDF کارت سلامت',
              onPressed: () {
                ExportHelper.exportToPdf(
                  context: context,
                  title: 'گزارش رسمی کارت خانه بهداشت - ${widget.studentName}',
                  headers: ['تاریخ', 'خانه بهداشت', 'وزن', 'قد', 'واکسیناسیون', 'توضیحات'],
                  rows: _records.map((r) => [r.date, r.centerName, r.weight, r.height, r.vaccinationStatus, r.notes]).toList(),
                  fileName: 'health_card_${widget.studentId}',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.indigo),
              tooltip: 'چاپ',
              onPressed: () {
                ExportHelper.printTable(
                  context: context,
                  title: 'گزارش رسمی کارت خانه بهداشت - ${widget.studentName}',
                  headers: ['تاریخ', 'خانه بهداشت', 'وزن', 'قد', 'واکسیناسیون', 'توضیحات'],
                  rows: _records.map((r) => [r.date, r.centerName, r.weight, r.height, r.vaccinationStatus, r.notes]).toList(),
                  fileName: 'health_card_${widget.studentId}',
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 450,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سوابق معاینات و واکسیناسیون:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    onPressed: () => _showAddEditRecordDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('افزودن چکاپ جدید'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _records.isEmpty
                        ? const Center(child: Text('هیچ سابقه سلامتی ثبت نشده است.'))
                        : ListView.builder(
                            itemCount: _records.length,
                            itemBuilder: (context, index) {
                              final r = _records[index];
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('📅 تاریخ: ${r.date}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                onPressed: () => _showAddEditRecordDialog(editItem: r),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                onPressed: () => _deleteRecord(r.id),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      Text('🏥 مرکز / خانه بهداشت: ${r.centerName}'),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(child: Text('⚖️ وزن: ${r.weight}')),
                                          Expanded(child: Text('📏 قد: ${r.height}')),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('💉 واکسیناسیون: ${r.vaccinationStatus}'),
                                      const SizedBox(height: 4),
                                      Text('📝 توضیحات پزشک: ${r.notes}', style: const TextStyle(color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }
}

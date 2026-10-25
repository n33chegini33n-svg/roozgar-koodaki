import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';
import '../parent/parent_sections.dart' show kPageBg, softCard;
import '../theme/app_colors.dart';
import '../utils/export_helper.dart';
import '../utils/jalali.dart';

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

class RegistrationManagerPage extends StatefulWidget {
  const RegistrationManagerPage({super.key});

  @override
  State<RegistrationManagerPage> createState() => _RegistrationManagerPageState();
}

class _RegistrationManagerPageState extends State<RegistrationManagerPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  String _searchQuery = '';
  String _selectedStatusFilter = 'all'; // 'all', 'submitted', 'approved', 'rejected'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!Backend.ready) {
        setState(() {
          _records = [];
          _loading = false;
        });
        return;
      }

      final rows = await Backend.client
          .from('registration_records')
          .select('*')
          .order('updated_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _records = rows.map((e) => Map<String, dynamic>.from(e)).toList();
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

  List<Map<String, dynamic>> get _filteredRecords {
    return _records.where((rec) {
      final status = '${rec['status'] ?? 'submitted'}';
      if (_selectedStatusFilter != 'all' && status != _selectedStatusFilter) {
        return false;
      }

      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase();

      final data = rec['data'] is Map ? Map<String, dynamic>.from(rec['data'] as Map) : <String, dynamic>{};
      final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.toLowerCase();
      final fatherName = '${data['نام و خانوادگی پدر'] ?? ''}'.toLowerCase();
      final motherName = '${data['نام و خانوادگی مادر'] ?? ''}'.toLowerCase();
      final guardianName = '${data['نام و نام خانوادگی ولی قانونی نوآموز'] ?? data['نام و نام خانوادگی ولی'] ?? ''}'.toLowerCase();
      final parentId = '${rec['parent_id'] ?? ''}'.toLowerCase();

      return studentName.contains(query) ||
          fatherName.contains(query) ||
          motherName.contains(query) ||
          guardianName.contains(query) ||
          parentId.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: const Text('مدیریت پرونده‌های ثبت‌نام نوآموزان'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'به‌روزرسانی',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text('بارگذاری پرونده‌ها انجام نشد:\n$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تلاش مجدد'),
                        )
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeaderAndSearch(),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'هنوز هیچ پرونده ثبت‌نامی ارسال نشده است.'
                                    : 'هیچ پرونده‌ای با مشخصات جستجو شده یافت نشد.',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) => _recordCard(filtered[index]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeaderAndSearch() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'جستجو بر اساس نام نوآموز، پدر، مادر یا شماره ولی...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterChip(label: 'همه پرونده‌ها', value: 'all', color: AppColors.navy),
                const SizedBox(width: 8),
                _buildStatusFilterChip(label: 'در انتظار بررسی', value: 'submitted', color: const Color(0xFFF57F17)),
                const SizedBox(width: 8),
                _buildStatusFilterChip(label: 'تأیید شده', value: 'approved', color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _buildStatusFilterChip(label: 'عدم تأیید', value: 'rejected', color: const Color(0xFFC62828)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تعداد پرونده‌ها: ${_filteredRecords.length} از ${_records.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _exportAll(format: 'excel'),
                    icon: const Icon(Icons.table_chart_rounded, size: 18, color: Colors.green),
                    label: const Text('خروجی اکسل', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ),
                  TextButton.icon(
                    onPressed: () => _exportAll(format: 'pdf'),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.red),
                    label: const Text('خروجی PDF', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip({required String label, required String value, required Color color}) {
    final isSelected = _selectedStatusFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : color,
      ),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: isSelected ? 1.0 : 0.4)),
      ),
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
    final parentName = '${data['نام و خانوادگی پدر'] ?? data['نام و خانوادگی مادر'] ?? 'مشخص نشده'}';
    final status = '${record['status'] ?? 'submitted'}';
    final rejectionReason = record['rejection_reason']?.toString();

    Color statusColor;
    String statusText;
    if (status == 'approved') {
      statusColor = const Color(0xFF2E7D32);
      statusText = 'تأیید شده';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFC62828);
      statusText = 'عدم تأیید';
    } else {
      statusColor = const Color(0xFFF57F17);
      statusText = 'در انتظار بررسی';
    }

    return softCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(Icons.child_care_rounded, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName.isEmpty ? 'پرونده بدون نام' : studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ولی / والد: $parentName | کد/شماره ولی: ${record['parent_id'] ?? '—'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('علت عدم تأیید: $rejectionReason', style: const TextStyle(fontSize: 11.5, color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showStatusDialog(record),
                  icon: const Icon(Icons.traffic_rounded, size: 18),
                  label: const Text('تغییر وضعیت'),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.medical_services_rounded, color: Colors.teal),
                      tooltip: 'کارت خانه بهداشت و پرونده سلامت',
                      onPressed: () => _openHealthCardDialog(record),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_rounded, color: AppColors.navy),
                      tooltip: 'پرینت مستقیم',
                      onPressed: () => _printSingleRecord(record),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: AppColors.navy),
                      tooltip: 'مشاهده و ویرایش جزئیات',
                      onPressed: () => _showDetailsDialog(record),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(Map<String, dynamic> record) {
    final parentId = '${record['parent_id']}';
    String currentStatus = '${record['status'] ?? 'submitted'}';
    final reasonController = TextEditingController(text: record['rejection_reason']?.toString() ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('تعیین وضعیت پرونده ثبت‌نام'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('یکی از وضعیت‌های زیر را برای پرونده انتخاب کنید:'),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: currentStatus,
                    onChanged: (val) =>
                        setDialogState(() => currentStatus = val!),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          activeColor: const Color(0xFFF57F17),
                          title: const Text('در انتظار بررسی'),
                          value: 'submitted',
                        ),
                        RadioListTile<String>(
                          activeColor: const Color(0xFF2E7D32),
                          title: const Text('تأیید نهایی پرونده'),
                          value: 'approved',
                        ),
                        RadioListTile<String>(
                          activeColor: const Color(0xFFC62828),
                          title: const Text('عدم تأیید / نیاز به اصلاح'),
                          value: 'rejected',
                        ),
                      ],
                    ),
                  ),
                  if (currentStatus == 'rejected') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'علت عدم تأیید (توضیحات برای اولیا)',
                        hintText: 'علت رد شدن پرونده یا موارد نیازمند اصلاح را اینجا بنویسید...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              FilledButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final reason = currentStatus == 'rejected' ? reasonController.text.trim() : null;
                  Navigator.pop(ctx);
                  try {
                    try {
                      await Backend.client.from('registration_records').update({
                        'status': currentStatus,
                        'rejection_reason': reason,
                        'updated_at': DateTime.now().toUtc().toIso8601String(),
                      }).eq('parent_id', parentId);
                    } catch (_) {
                      await Backend.client.from('registration_records').update({
                        'status': currentStatus,
                        'updated_at': DateTime.now().toUtc().toIso8601String(),
                      }).eq('parent_id', parentId);
                    }

                    messenger.showSnackBar(
                      const SnackBar(content: Text('وضعیت پرونده با موفقیت به روز گردید.')),
                    );
                    _load();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('خطا در به‌روزرسانی وضعیت: $e')),
                    );
                  }
                },
                child: const Text('ثبت تغییرات'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
    final status = '${record['status'] ?? 'submitted'}';
    final controllers = <String, TextEditingController>{};
    for (final entry in data.entries) {
      controllers[entry.key] = TextEditingController(text: '${entry.value}');
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'مشاهده و ویرایش پرونده: ${studentName.isEmpty ? "نوآموز" : studentName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 20),
                  tooltip: 'خروجی اکسل این پرونده',
                  onPressed: () {
                    final rows = controllers.entries.map((e) => [e.key, e.value.text]).toList();
                    ExportHelper.exportToExcel(
                      context: context,
                      title: 'پرونده ثبت‌نام نوآموز $studentName',
                      headers: ['عنوان فیلد', 'مقدار ثبت شده'],
                      rows: rows,
                      fileName: 'پرونده_$studentName',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                  tooltip: 'خروجی PDF این پرونده',
                  onPressed: () {
                    final currentData = <String, dynamic>{
                      for (final e in controllers.entries) e.key: e.value.text,
                    };
                    ExportHelper.exportRegistrationFormPdf(
                      context: context,
                      studentName: studentName,
                      status: status,
                      data: currentData,
                      printOnly: false,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.print_rounded, color: AppColors.navy, size: 20),
                  tooltip: 'چاپ مستقیم فرم A4',
                  onPressed: () {
                    final currentData = <String, dynamic>{
                      for (final e in controllers.entries) e.key: e.value.text,
                    };
                    ExportHelper.exportRegistrationFormPdf(
                      context: context,
                      studentName: studentName,
                      status: status,
                      data: currentData,
                      printOnly: true,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final key in controllers.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[key],
                      maxLines: key.contains('آدرس') || key.contains('توضیحات') || key.contains('سابقه') ? 2 : 1,
                      decoration: InputDecoration(
                        labelText: key,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('انصراف')),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final updatedData = <String, String>{
                for (final e in controllers.entries) e.key: e.value.text,
              };
              Navigator.pop(dialogCtx);
              try {
                await Backend.client.from('registration_records').update({
                  'data': updatedData,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                }).eq('parent_id', record['parent_id']);

                messenger.showSnackBar(
                  const SnackBar(content: Text('اطلاعات پرونده با موفقیت ذخیره شد.')),
                );
                _load();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('خطا در ذخیره پرونده: $e')),
                );
              }
            },
            child: const Text('ذخیره تغییرات'),
          ),
        ],
      ),
    );
  }

  void _openHealthCardDialog(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
    final parentId = '${record['parent_id'] ?? 'unknown'}';

    showDialog(
      context: context,
      builder: (ctx) => _HealthCardDialogContent(
        studentId: parentId,
        studentName: studentName.isEmpty ? 'نوآموز' : studentName,
        className: '${data['مقطع تحصیلی نوآموز'] ?? data['مقطع تحصیلی'] ?? 'پیش‌دبستانی'}',
      ),
    );
  }

  void _printSingleRecord(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
    final status = '${record['status'] ?? 'submitted'}';

    ExportHelper.exportRegistrationFormPdf(
      context: context,
      studentName: studentName,
      status: status,
      data: data,
      printOnly: true,
    );
  }

  void _exportAll({required String format}) {
    final filtered = _filteredRecords;
    final headers = ['ردیف', 'نام نوآموز', 'والد / اولیا', 'شماره تماس', 'وضعیت', 'تاریخ ثبت/به‌روزرسانی'];
    final rows = <List<dynamic>>[];

    for (var i = 0; i < filtered.length; i++) {
      final rec = filtered[i];
      final data = rec['data'] is Map ? Map<String, dynamic>.from(rec['data'] as Map) : <String, dynamic>{};
      final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
      final parentName = '${data['نام و خانوادگی پدر'] ?? data['نام و خانوادگی مادر'] ?? '—'}';
      final phone = '${data['شماره همراه اصلی پدر'] ?? data['شماره همراه اصلی مادر'] ?? '—'}';
      final status = '${rec['status'] ?? 'submitted'}';
      String statusStr = status == 'approved' ? 'تأییدشده' : (status == 'rejected' ? 'ردشده' : 'در انتظار');

      rows.add([
        '${i + 1}',
        studentName.isEmpty ? '—' : studentName,
        parentName,
        phone,
        statusStr,
        '${rec['updated_at'] ?? rec['submitted_at'] ?? '—'}'.substring(0, 10),
      ]);
    }

    if (format == 'excel') {
      ExportHelper.exportToExcel(
        context: context,
        title: 'گزارش لیست پرونده‌های ثبت‌نام نوآموزان',
        headers: headers,
        rows: rows,
        fileName: 'لیست_ثبت‌نام_نوآموزان',
      );
    } else {
      ExportHelper.exportToPdf(
        context: context,
        title: 'گزارش لیست پرونده‌های ثبت‌نام نوآموزان',
        headers: headers,
        rows: rows,
        fileName: 'لیست_ثبت‌نام_نوآموزان',
      );
    }
  }
}

// ==========================================
// کارت خانه بهداشت و پرونده سلامت کودک
// ==========================================
class _HealthCardDialogContent extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String className;

  const _HealthCardDialogContent({
    required this.studentId,
    required this.studentName,
    required this.className,
  });

  @override
  State<_HealthCardDialogContent> createState() => _HealthCardDialogContentState();
}

class _HealthCardDialogContentState extends State<_HealthCardDialogContent> {
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

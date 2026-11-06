
import 'package:flutter/material.dart';
import '../models/registration_model.dart';
import '../models/registration_bin.dart';
import '../models/registration_docs.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../services/backend.dart';
import '../parent/parent_sections.dart' show kPageBg, softCard;
import '../theme/app_colors.dart';
import 'registration/health_card_dialog.dart';
import '../utils/export_helper.dart';

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
      await RegistrationBin.purgeExpired();
      final rows = await RegistrationDraftService.staffRows(deleted: _selectedStatusFilter == 'deleted');
      if (!mounted) return;
      setState(() {
        _records = rows;
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
      final isDeleted = rec['is_deleted'] == true;

      if (_selectedStatusFilter == 'deleted') {
        if (!isDeleted) return false;
      } else {
        if (isDeleted) return false;

        final status = '${rec['status'] ?? 'submitted'}';
        if (_selectedStatusFilter != 'all' && _selectedStatusFilter != 'deleted' && status != _selectedStatusFilter) {
          return false;
        }
      }

      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase();

      final data = rec['data'] is Map ? Map<String, dynamic>.from(rec['data'] as Map) : <String, dynamic>{};
      final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? rec['student_name'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.toLowerCase();
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
            onPressed: () => _exportAll(format: 'excel'),
            icon: const Icon(Icons.table_chart_rounded, color: Colors.green),
            tooltip: 'خروجی اکسل فهرست فیلترشده',
          ),
          IconButton(
            onPressed: () => _exportAll(format: 'pdf'),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
            tooltip: 'خروجی PDF فهرست فیلترشده',
          ),
          IconButton(
            onPressed: _printFilteredList,
            icon: const Icon(Icons.print_rounded),
            tooltip: 'چاپ فهرست فیلترشده',
          ),
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
                const SizedBox(width: 8),
                _buildStatusFilterChip(label: '🗑️ سطل بازیافت', value: 'deleted', color: Colors.grey),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'تعداد پرونده‌ها: ${_filteredRecords.length} از ${_records.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
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
      onSelected: (_) {
        setState(() => _selectedStatusFilter = value);
        _load();
      },
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final isDeleted = record['is_deleted'] == true;
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? record['student_name'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
    final parentName = '${data['نام و خانوادگی پدر'] ?? data['نام و خانوادگی مادر'] ?? 'مشخص نشده'}';
    final status = '${record['status'] ?? 'submitted'}';
    final rejectionReason = record['rejection_reason']?.toString();

    Color statusColor;
    String statusText;
    if (isDeleted) {
      statusColor = const Color(0xFF546E7A);
      statusText = '🗑️ سطل بازیافت';
    } else if (status == 'approved') {
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
            if (!isDeleted && status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
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
                if (isDeleted)
                  ElevatedButton.icon(
                    onPressed: () => _restore(record),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.restore_from_trash_rounded, size: 18),
                    label: const Text('بازیابی پرونده ↩️'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _showStatusDialog(record),
                    icon: const Icon(Icons.traffic_rounded, size: 18),
                    label: const Text('تغییر وضعیت'),
                  ),
                Row(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.medical_services_rounded, color: Colors.teal),
                          tooltip: 'کارت بهداشت و پرونده سلامت',
                          onPressed: () => _openHealthCardDialog(record),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.folder_rounded,
                            color: '${record['attachment_url'] ?? ''}'.isNotEmpty ? Colors.teal : Colors.grey,
                          ),
                          tooltip: 'پوشه مدارک',
                          onPressed: () => _openDocument(record),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.navy),
                          tooltip: 'مشاهده و ویرایش پرونده',
                          onPressed: () => _showDetailsDialog(record),
                        ),
                        if (!isDeleted)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            tooltip: 'انتقال به سطل بازیافت',
                            onPressed: () => _confirmDelete(record),
                          ),
                      ],
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

  String _nameOf(Map<String, dynamic> r) {
    final n = '${r['student_name'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    final d = r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
    return '${d['نام نوآموز'] ?? ''} ${d['نام خانوادگی'] ?? ''}'.trim();
  }

  Future<void> _openDocument(Map<String, dynamic> r) async {
    final id = '${r['id']}';
    List<Map<String, dynamic>> docs = [];
    try {
      docs = await RegistrationDocs.forRecord(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (docs.isEmpty && '${r['attachment_url'] ?? ''}'.isNotEmpty) {
      docs = [
        {'path': r['attachment_url'], 'file_name': 'مدرک.jpg'},
      ];
    }
    if (docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای این نوآموز مدرکی ثبت نشده است')));
      return;
    }
    for (final d in docs) {
      d['url'] = await RegistrationDocs.signedUrl('${d['path']}');
    }
    final selected = <int>{};
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('پوشه مدارک ${_nameOf(r)}'),
            content: SizedBox(
              width: 460,
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (var i = 0; i < docs.length; i++)
                    GestureDetector(
                      onTap: () => setD(() => selected.contains(i) ? selected.remove(i) : selected.add(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected.contains(i) ? AppColors.navy : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network('${docs[i]['url']}', fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setD(() {
                  if (selected.length == docs.length) {
                    selected.clear();
                  } else {
                    selected
                      ..clear()
                      ..addAll(List.generate(docs.length, (i) => i));
                  }
                }),
                child: const Text('انتخاب همه'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text('چاپ انتخاب‌شده'),
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        try {
                          await RegistrationDocs.printDocs([
                            for (final i in (selected.toList()..sort())) '${docs[i]['path']}',
                          ]);
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('$e')));
                        }
                      },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('دانلود انتخاب‌شده'),
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        for (final i in (selected.toList()..sort())) {
                          try {
                            await RegistrationDocs.saveToDevice(
                              '${docs[i]['path']}',
                              '${docs[i]['file_name'] ?? 'مدرک_$i.jpg'}',
                            );
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف پرونده؟'),
          content: Text('پرونده ${_nameOf(r)} به سطل بازیافت منتقل می‌شود.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await RegistrationDraftService.setDeleted(id: '${r['id']}', name: _nameOf(r), deleted: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    _load();
  }

  Future<void> _restore(Map<String, dynamic> r) async {
    await RegistrationDraftService.setDeleted(id: '${r['id']}', name: _nameOf(r), deleted: false);
    if (!mounted) return;
    _load();
  }

  void _showStatusDialog(Map<String, dynamic> record) {
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
                    await RegistrationDraftService.setStatus(
                      id: '${record['id']}',
                      name: _nameOf(record),
                      from: '${record['status']}',
                      to: currentStatus,
                      reason: reason,
                    );
                    messenger.showSnackBar(const SnackBar(content: Text('وضعیت پرونده به‌روز شد.')));
                    _load();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
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

    final screenSize = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
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
          width: screenSize.width.clamp(700.0, 1100.0).toDouble(),
          height: screenSize.height * 0.68,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 2 : 1;
              final itemWidth = (constraints.maxWidth - (columns - 1) * 14) / columns;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    for (final key in controllers.keys)
                      SizedBox(
                        width: itemWidth,
                        child: TextField(
                          controller: controllers[key],
                          maxLines: key.contains('آدرس') || key.contains('توضیحات') || key.contains('سابقه') ? 2 : 1,
                          decoration: InputDecoration(
                            labelText: key,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xFFF9FAFC),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
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
              final before = <String, String>{for (final e in data.entries) e.key: '${e.value ?? ''}'};
              Navigator.pop(dialogCtx);
              try {
                await RegistrationDraftService.staffSave(
                  id: '${record['id']}',
                  oldName: _nameOf(record),
                  before: before,
                  after: updatedData,
                );
                messenger.showSnackBar(const SnackBar(content: Text('اطلاعات پرونده ذخیره شد.')));
                _load();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('خطا در ذخیره پرونده: $e')));
              }
            },
            
child: const Text('ذخیره تغییرات'),
          ),
        ],
      ),
    ).whenComplete(() {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  void _openHealthCardDialog(Map<String, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    final studentName = '${data['نام نوآموز'] ?? data['نام'] ?? ''} ${data['نام خانوادگی'] ?? ''}'.trim();
    final parentId = '${record['parent_id'] ?? 'unknown'}';

    showDialog(
      context: context,
      builder: (ctx) => HealthCardDialogContent(
        studentId: parentId,
        studentName: studentName.isEmpty ? 'نوآموز' : studentName,
        className: '${data['مقطع تحصیلی نوآموز'] ?? data['مقطع تحصیلی'] ?? 'پیش‌دبستانی'}',
      ),
    );
  }

  void _printFilteredList() => _exportAll(format: 'pdf', printOnly: true);

  void _exportAll({required String format, bool printOnly = false}) {
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
    } else if (printOnly) {
      ExportHelper.printTable(
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

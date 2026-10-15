import 'dart:async';
import 'package:flutter/material.dart';
import '../models/attendance_archive_model.dart';
import '../models/audit_log_model.dart';
import '../models/permissions.dart';
import '../utils/export_helper.dart';
import '../models/school_classes.dart';

class ManagerAttendanceArchivePage extends StatefulWidget {
  final AppRole role;
  const ManagerAttendanceArchivePage({super.key, this.role = AppRole.manager});

  @override
  State<ManagerAttendanceArchivePage> createState() => _ManagerAttendanceArchivePageState();
}

class _ManagerAttendanceArchivePageState extends State<ManagerAttendanceArchivePage> {
  static const int _maxPdfRows = 1500;
  static const List<String> _months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  bool _isLoading = true;
  List<AttendanceRecord> _allRecords = [];
  List<AttendanceRecord> _filteredRecords = [];

  // مقادیر فیلترها فقط یک بار بعد از بارگذاری محاسبه می‌شوند (نه در هر build)
  List<int> _years = [];
  List<String> _classes = [];

  int? _selectedYear;
  String? _selectedMonth;
  String? _selectedClass;
  String? _selectedStatus;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool force = false}) async {
    if (force) setState(() => _isLoading = true);
    var records = await AttendanceArchiveService.getRecords(forceReload: force);
    // دامنهٔ «کلاس خودش»: فقط رکوردهای کلاس همان کاربر
    final scope = PermissionService.instance.scopeOf(widget.role, Perm.viewAttendance);
    if (scope == Scope.none) records = [];
    if (scope == Scope.own) {
      records = records.where((r) => sameClass(r.className, Session.className)).toList();
    }
    if (!mounted) return;
    setState(() {
      _allRecords = records;
      _years = (records.map((e) => e.year).toSet().toList()..sort((a, b) => b.compareTo(a)));
      _classes = records.map((e) => e.className).toSet().toList()..sort();
      _isLoading = false;
    });
    _applyFilters();
  }

  void _onSearchChanged(String _) {
    // جستجو بعد از ۳۰۰ میلی‌ثانیه توقف تایپ اجرا می‌شود، نه با هر حرف
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _applyFilters);
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final result = _allRecords.where((r) {
      if (_selectedYear != null && r.year != _selectedYear) return false;
      if (_selectedMonth != null && r.month != _selectedMonth) return false;
      if (_selectedClass != null && r.className != _selectedClass) return false;
      if (_selectedStatus != null && !r.status.contains(_selectedStatus!)) return false;
      if (query.isNotEmpty) {
        return r.studentName.toLowerCase().contains(query) ||
            r.teacherName.toLowerCase().contains(query) ||
            r.date.contains(query);
      }
      return true;
    }).toList();
    if (!mounted) return;
    setState(() => _filteredRecords = result);
  }

  void _resetFilters() {
    _searchController.clear();
    _selectedYear = null;
    _selectedMonth = null;
    _selectedClass = null;
    _selectedStatus = null;
    _applyFilters();
  }

  bool get _canExport => PermissionService.instance.can(widget.role, Perm.exportReports);

  List<List<dynamic>> get _exportRows => _filteredRecords
      .map((r) => [r.studentName, r.className, r.status, r.year, r.month, r.day, r.date, r.teacherName])
      .toList();

  static const List<String> _exportHeaders = [
    'نام نوآموز', 'کلاس', 'وضعیت', 'سال', 'ماه', 'روز', 'تاریخ دقیق', 'مربی ثبت‌کننده'
  ];

  void _exportExcel() {
    ExportHelper.exportToExcel(
      context: context,
      title: 'بایگانی جامع حضور و غیاب',
      headers: _exportHeaders,
      rows: _exportRows,
      fileName: 'attendance_archive_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void _exportPdf() {
    if (_filteredRecords.length > _maxPdfRows) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('برای PDF حداکثر $_maxPdfRows رکورد مجاز است. فیلتر را محدودتر کنید یا خروجی اکسل بگیرید.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    ExportHelper.exportToPdf(
      context: context,
      title: 'گزارش بایگانی جامع حضور و غیاب',
      headers: _exportHeaders,
      rows: _exportRows,
      fileName: 'attendance_archive_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void _printTable() {
    if (_filteredRecords.length > _maxPdfRows) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('برای PDF حداکثر $_maxPdfRows رکورد مجاز است. فیلتر را محدودتر کنید یا خروجی اکسل بگیرید.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    ExportHelper.printTable(
      context: context,
      title: 'گزارش بایگانی جامع حضور و غیاب',
      headers: _exportHeaders,
      rows: _exportRows,
      fileName: 'attendance_archive_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // اصلاح مستقیم فقط برای مدیر و ادمین؛ معاون از مسیر «درخواست اصلاح» (با تأیید) می‌رود
  bool get _canDirectEdit => widget.role == AppRole.manager || widget.role == AppRole.admin;

  Future<void> _showEditRecordDialog(AttendanceRecord record) async {
    if (!_canDirectEdit) return;
    String newStatus = record.status;
    final reasonCtrl = TextEditingController();
    const options = ['حاضر 🟢', 'تأخیر 🟡', 'غایب 🔴', 'مرخصی 🟡'];

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF01579B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('اصلاح مستقیم حضور ${record.studentName}',
                    style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تاریخ: ${record.date} • کلاس: ${record.className}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'دلیل اصلاح (الزامی)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              const Text('وضعیت جدید را انتخاب کنید:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx, setLocalState) => Wrap(
                  spacing: 8,
                  children: [
                    for (final opt in options)
                      ChoiceChip(
                        label: Text(opt),
                        selected: newStatus == opt,
                        onSelected: (_) => setLocalState(() => newStatus = opt),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF01579B)),
              onPressed: () => Navigator.pop(ctx, newStatus),
              child: const Text('ثبت تغییرات', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    final reason = reasonCtrl.text.trim();
    if (updated != null && updated != record.status && reason.length < 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('دلیل اصلاح را کامل‌تر بنویسید؛ تغییری اعمال نشد'), backgroundColor: Colors.orange.shade800),
      );
      return;
    }
    if (updated != null && updated != record.status) {
      final success = await AttendanceArchiveService.updateStatus(record.id, updated);
      if (success) {
        await AuditLogService.log(
          actor: Session.userName,
          role: Session.role.label,
          action: 'اصلاح مستقیم رکورد قفل‌شده',
          details: '${record.studentName} (${record.date}): ${record.status} ← $updated • دلیل: $reason',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('وضعیت نوآموز با موفقیت اصلاح شد'), backgroundColor: Colors.green),
        );
        _loadData(force: true);
      }
    }
  }

  Widget _dropdown<T>({
    required double width,
    required String label,
    required T? value,
    required String allLabel,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            items: [DropdownMenuItem<T>(value: null, child: Text(allLabel)), ...items],
            onChanged: (v) {
              onChanged(v);
              _applyFilters();
            },
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    if (s.contains('غایب')) return const Color(0xFFE5484D);
    if (s.contains('تأخیر') || s.contains('مرخصی')) return const Color(0xFFF59E0B);
    return const Color(0xFF2E9E6B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بایگانی جامع حضور و غیاب'),
        backgroundColor: const Color(0xFF01579B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'بارگذاری مجدد',
            onPressed: () => _loadData(force: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('🔍 فیلترهای پیشرفته بایگانی',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF01579B))),
                              TextButton.icon(
                                onPressed: _resetFilters,
                                icon: const Icon(Icons.clear_all_rounded, size: 18),
                                label: const Text('حذف فیلترها'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _dropdown<int>(
                                  width: 120,
                                  label: 'سال',
                                  value: _selectedYear,
                                  allLabel: 'همه سال‌ها',
                                  items: [for (final y in _years) DropdownMenuItem(value: y, child: Text('$y'))],
                                  onChanged: (v) => _selectedYear = v,
                                ),
                                const SizedBox(width: 10),
                                _dropdown<String>(
                                  width: 140,
                                  label: 'ماه',
                                  value: _selectedMonth,
                                  allLabel: 'همه ماه‌ها',
                                  items: [for (final m in _months) DropdownMenuItem(value: m, child: Text(m))],
                                  onChanged: (v) => _selectedMonth = v,
                                ),
                                const SizedBox(width: 10),
                                _dropdown<String>(
                                  width: 190,
                                  label: 'کلاس',
                                  value: _selectedClass,
                                  allLabel: 'همه کلاس‌ها',
                                  items: [for (final c in _classes) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))],
                                  onChanged: (v) => _selectedClass = v,
                                ),
                                const SizedBox(width: 10),
                                _dropdown<String>(
                                  width: 140,
                                  label: 'وضعیت',
                                  value: _selectedStatus,
                                  allLabel: 'همه وضعیت‌ها',
                                  items: const [
                                    DropdownMenuItem(value: 'حاضر', child: Text('حاضر 🟢')),
                                    DropdownMenuItem(value: 'تأخیر', child: Text('تأخیر 🟡')),
                                    DropdownMenuItem(value: 'غایب', child: Text('غایب 🔴')),
                                    DropdownMenuItem(value: 'مرخصی', child: Text('مرخصی 🟡')),
                                  ],
                                  onChanged: (v) => _selectedStatus = v,
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 210,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      labelText: 'جستجوی نوآموز، مربی یا تاریخ',
                                      prefixIcon: Icon(Icons.search_rounded),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 6,
                    spacing: 8,
                    children: [
                      Text('تعداد رکوردها: ${_filteredRecords.length} از ${_allRecords.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF01579B), fontSize: 14)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                            onPressed: (_filteredRecords.isEmpty || !_canExport) ? null : _exportExcel,
                            icon: const Icon(Icons.table_chart_rounded, size: 18),
                            label: const Text('اکسل'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                            onPressed: (_filteredRecords.isEmpty || !_canExport) ? null : _exportPdf,
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: const Text('PDF'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white),
                            onPressed: (_filteredRecords.isEmpty || !_canExport) ? null : _printTable,
                            icon: const Icon(Icons.print_rounded, size: 18),
                            label: const Text('چاپ'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // لیست «تنبل»: فقط ردیف‌های قابل‌مشاهده ساخته می‌شوند (جایگزین DataTable)
                  Expanded(
                    child: _filteredRecords.isEmpty
                        ? const Center(child: Text('هیچ رکوردی با فیلترهای انتخاب‌شده یافت نشد.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _filteredRecords.length,
                            itemExtent: 76,
                            itemBuilder: (context, i) {
                              final r = _filteredRecords[i];
                              final color = _statusColor(r.status);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 44,
                                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.studentName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text('${r.className} • ${r.teacherName}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(r.status, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text('${r.day} ${r.date}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                        ],
                                      ),
                                      if (_canDirectEdit) ...[
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF01579B), size: 22),
                                          tooltip: 'اصلاح مستقیم رکورد',
                                          onPressed: () => _showEditRecordDialog(r),
                                        ),
                                      ],
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
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/export_helper.dart';
import '../models/audit_log_model.dart';
import '../services/backend.dart';
import '../services/backend_directory.dart';
import 'create_account_dialog.dart';
import '../utils/jalali.dart';
import '../models/permissions.dart';
import '../models/user_directory.dart';
import '../models/school_classes.dart';

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

class ManagerUserManagementPage extends StatefulWidget {
  const ManagerUserManagementPage({super.key});

  @override
  State<ManagerUserManagementPage> createState() => _ManagerUserManagementPageState();
}

class _ManagerUserManagementPageState extends State<ManagerUserManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final list = await UserDirectory.load();
    if (!mounted) return;
    setState(() {
      _users = List<UserModel>.from(list);
      _isLoading = false;
    });
  }

  Future<void> _saveUsers() => UserDirectory.save(_users);

  void _showAddUserDialog({UserModel? editUser}) {
    if (Backend.ready) {
      // حالت سرور: ساخت حساب واقعی با تابع سمت سرور
      if (editUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ویرایش حساب‌های موجود فعلاً از داشبورد سرور انجام می‌شود')),
        );
        return;
      }
      showCreateAccountDialog(context).then((created) {
        if (created) {
          UserDirectory.clearCache();
          ServerDirectory.reset();
          _loadUsers();
        }
      });
      return;
    }
    if (!PermissionService.instance.can(Session.role, Perm.manageUsers)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شما اجازهٔ مدیریت کاربران را ندارید'), backgroundColor: Colors.red),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: editUser?.name ?? '');
    String selectedRole = editUser?.role ?? 'student';
    
    const validClasses = [...kClassNames, 'والدین و اولیاء', 'مدیریت'];
    String selectedClass = (editUser != null && validClasses.contains(normalizeClassName(editUser.className)))
        ? normalizeClassName(editUser.className)
        : kClassNames.first;
    final studentNames = _users.where((u) => u.role == 'student').map((u) => u.name).toList();
    String linkedStudent = (editUser != null && studentNames.contains(editUser.linkedStudent))
        ? editUser.linkedStudent
        : (studentNames.isEmpty ? '' : studentNames.first);

    final phoneCtrl = TextEditingController(text: editUser?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(editUser == null ? '➕ ثبت‌نام / افزودن کاربر جدید' : '✏️ ویرایش مشخصات کاربر'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'نام و نام خانوادگی', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'نقش کاربر', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isDense: true,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'student', child: Text('دانش‌آموز / نوآموز 🎒')),
                            DropdownMenuItem(value: 'teacher', child: Text('مربی / معلم 👩‍🏫')),
                            DropdownMenuItem(value: 'parent', child: Text('اولیاء (والدین) 👨‍👩‍👦')),
                            DropdownMenuItem(value: 'deputy', child: Text('معاون / ناظم 🧑‍💼')),
                          ],
                          onChanged: (val) => setDialogState(() => selectedRole = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'کلاس / بخش مربوطه', border: OutlineInputBorder()),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedClass,
                          isDense: true,
                          isExpanded: true,
                          items: [
                            for (final c in kClassNames) DropdownMenuItem(value: c, child: Text(classLabel(c))),
                            const DropdownMenuItem(value: 'والدین و اولیاء', child: Text('والدین و اولیاء')),
                            const DropdownMenuItem(value: 'مدیریت', child: Text('مدیریت')),
                          ],
                          onChanged: (val) => setDialogState(() => selectedClass = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'شماره تماس / همراه', border: OutlineInputBorder()),
                    ),
                    if (selectedRole == 'parent' && studentNames.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'فرزند این ولی', border: OutlineInputBorder()),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: linkedStudent,
                            isDense: true,
                            isExpanded: true,
                            items: [for (final n in studentNames) DropdownMenuItem(value: n, child: Text(n))],
                            onChanged: (val) => setDialogState(() => linkedStudent = val ?? linkedStudent),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
                onPressed: () {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    final isEdit = editUser != null;
                    AuditLogService.log(
                      actor: Session.userName,
                      role: Session.role.label,
                      action: isEdit ? 'ویرایش کاربر' : 'افزودن کاربر',
                      details: '${nameCtrl.text.trim()} • نقش: $selectedRole • $selectedClass',
                    );
                    setState(() {
                      if (editUser == null) {
                        _users.add(UserModel(
                          id: 'U-${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim(),
                          role: selectedRole,
                          className: selectedClass,
                          phone: phoneCtrl.text.trim(),
                          linkedStudent: selectedRole == 'parent' ? linkedStudent : '',
                        ));
                      } else {
                        final idx = _users.indexWhere((u) => u.id == editUser.id);
                        if (idx != -1) {
                          _users[idx] = editUser.copyWith(
                            name: nameCtrl.text.trim(),
                            role: selectedRole,
                            className: selectedClass,
                            phone: phoneCtrl.text.trim(),
                            linkedStudent: selectedRole == 'parent' ? linkedStudent : '',
                          );
                        }
                      }
                    });
                    _saveUsers();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ اطلاعات کاربر با موفقیت ذخیره شد!'), backgroundColor: Colors.green),
                    );
                  }
                },
                child: const Text('ذخیره و ثبت'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openHealthCardDialog(UserModel student) {
    showDialog(
      context: context,
      builder: (ctx) => _HealthCardDialogContent(student: student),
    );
  }

  void _deleteUser(String id) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ حذف کاربر'),
          content: const Text('آیا از حذف این کاربر از سیستم اطمینان دارید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final removed = _users.where((u) => u.id == id).toList();
                if (removed.isNotEmpty) {
                  AuditLogService.log(
                    actor: Session.userName,
                    role: Session.role.label,
                    action: 'حذف کاربر',
                    details: '${removed.first.name} • نقش: ${removed.first.role}',
                  );
                }
                setState(() {
                  _users.removeWhere((u) => u.id == id);
                  _saveUsers();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🗑️ کاربر با موفقیت حذف شد.'), backgroundColor: Colors.red),
                );
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<UserModel> students = _users.where((u) => u.role == 'student').toList();
    List<UserModel> teachers = _users.where((u) => u.role == 'teacher' || u.role == 'deputy' || u.role == 'manager').toList();
    List<UserModel> parents = _users.where((u) => u.role == 'parent').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت کاربران و نقش‌ها'),
        backgroundColor: const Color(0xFF01579B),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [
            Tab(text: 'دانش‌آموزان (${students.length})', icon: const Icon(Icons.child_care_rounded)),
            Tab(text: 'مربیان و کادر (${teachers.length})', icon: const Icon(Icons.badge_rounded)),
            Tab(text: 'والدین (${parents.length})', icon: const Icon(Icons.family_restroom_rounded)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'خروجی اکسل',
            onPressed: () {
              ExportHelper.exportToExcel(
                context: context,
                title: 'لیست جامع کاربران مهدکودک',
                headers: ['نام', 'نقش', 'کلاس / بخش', 'شماره تماس'],
                rows: _users.map((u) => [u.name, _roleLabel(u.role), u.className, u.phone]).toList(),
                fileName: 'users_list_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'خروجی PDF',
            onPressed: () {
              ExportHelper.exportToPdf(
                context: context,
                title: 'گزارش رسمی لیست کاربران مهدکودک',
                headers: ['نام', 'نقش', 'کلاس / بخش', 'شماره تماس'],
                rows: _users.map((u) => [u.name, u.role == 'student' ? 'دانش‌آموز' : (u.role == 'teacher' ? 'مربی' : 'ولی'), u.className, u.phone]).toList(),
                fileName: 'users_list_${DateTime.now().millisecondsSinceEpoch}',
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
                title: 'گزارش رسمی لیست کاربران مهدکودک',
                headers: ['نام', 'نقش', 'کلاس / بخش', 'شماره تماس'],
                rows: _users.map((u) => [u.name, u.role == 'student' ? 'دانش‌آموز' : (u.role == 'teacher' ? 'مربی' : 'ولی'), u.className, u.phone]).toList(),
                fileName: 'users_list_${DateTime.now().millisecondsSinceEpoch}',
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        backgroundColor: const Color(0xFF0288D1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('افزودن کاربر جدید'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(students),
                _buildUserList(teachers),
                _buildUserList(parents),
              ],
            ),
    );
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'student':
        return 'دانش‌آموز';
      case 'teacher':
        return 'مربی';
      case 'deputy':
        return 'معاون / ناظم';
      case 'manager':
        return 'مدیر';
      case 'admin':
        return 'ادمین';
    }
    return 'ولی';
  }

  Widget _buildUserList(List<UserModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text('کاربری ثبت نشده است.', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final u = list[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.role == 'student' ? Colors.orange.shade100 : (u.role == 'teacher' ? Colors.purple.shade100 : Colors.blue.shade100),
              child: Icon(
                u.role == 'student' ? Icons.child_care : (u.role == 'teacher' ? Icons.badge : Icons.person),
                color: u.role == 'student' ? Colors.orange : (u.role == 'teacher' ? Colors.purple : Colors.blue),
              ),
            ),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(u.role == 'parent' && u.linkedStudent.isNotEmpty ? 'ولی ${u.linkedStudent}' : 'بخش/کلاس: ${u.className}'),
                Text('تلفن: ${u.phone}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Health Card button (only for students)
                if (u.role == 'student')
                  IconButton(
                    icon: const Icon(Icons.medical_services_rounded, color: Colors.teal),
                    tooltip: 'کارت خانه بهداشت و پرونده سلامت',
                    onPressed: () => _openHealthCardDialog(u),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                  tooltip: 'ویرایش مشخصات',
                  onPressed: () => _showAddUserDialog(editUser: u),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  tooltip: 'حذف کاربر',
                  onPressed: () => _deleteUser(u.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// کارت خانه بهداشت و پرونده سلامت کودک
// ==========================================
class _HealthCardDialogContent extends StatefulWidget {
  final UserModel student;
  const _HealthCardDialogContent({required this.student});

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
    final String? data = prefs.getString('health_records_${widget.student.id}');
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
    await prefs.setString('health_records_${widget.student.id}', jsonEncode(_records.map((e) => e.toJson()).toList()));
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
                  Text('کارت خانه بهداشت: ${widget.student.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('کلاس: ${widget.student.className}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_rounded, color: Colors.green),
              tooltip: 'خروجی اکسل کارت سلامت',
              onPressed: () {
                ExportHelper.exportToExcel(
                  context: context,
                  title: 'کارت خانه بهداشت و پرونده سلامت - ${widget.student.name}',
                  headers: ['تاریخ', 'خانه بهداشت', 'وزن', 'قد', 'واکسیناسیون', 'توضیحات پزشک'],
                  rows: _records.map((r) => [r.date, r.centerName, r.weight, r.height, r.vaccinationStatus, r.notes]).toList(),
                  fileName: 'health_card_${widget.student.id}',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
              tooltip: 'خروجی PDF کارت سلامت',
              onPressed: () {
                ExportHelper.exportToPdf(
                  context: context,
                  title: 'گزارش رسمی کارت خانه بهداشت - ${widget.student.name}',
                  headers: ['تاریخ', 'خانه بهداشت', 'وزن', 'قد', 'واکسیناسیون', 'توضیحات'],
                  rows: _records.map((r) => [r.date, r.centerName, r.weight, r.height, r.vaccinationStatus, r.notes]).toList(),
                  fileName: 'health_card_${widget.student.id}',
                );
              },
            ),
            /*print*/
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.red),
              tooltip: 'چاپ',
              onPressed: () {
                ExportHelper.printTable(
                  context: context,
                  title: 'گزارش رسمی کارت خانه بهداشت - ${widget.student.name}',
                  headers: ['تاریخ', 'خانه بهداشت', 'وزن', 'قد', 'واکسیناسیون', 'توضیحات'],
                  rows: _records.map((r) => [r.date, r.centerName, r.weight, r.height, r.vaccinationStatus, r.notes]).toList(),
                  fileName: 'health_card_${widget.student.id}',
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

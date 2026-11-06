import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import '../models/permissions.dart';
import '../services/purchase_service.dart';
import '../utils/jalali.dart';
import '../utils/export_helper.dart';

const Color _navy = Color(0xFF01579B);
const List<String> _units = ['عدد', 'کیلو', 'گرم', 'لیتر', 'بسته', 'کارتن', 'دست', 'سرویس'];
const int _maxBytes = 8 * 1024 * 1024;

String _err(Object e) => '$e'.replaceFirst('Exception: ', '');

void _snack(BuildContext context, String msg, [Color? color]) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
}

String _statusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'در انتظار تأیید';
    case 'needs_fix':
      return 'نیاز به اصلاح';
    case 'approved':
      return 'تأیید شده';
    case 'purchase_pending':
      return 'منتظر تأیید خرید';
    case 'purchased':
      return 'خرید انجام شد';
    case 'rejected':
      return 'رد شده';
    default:
      return 'پیش‌نویس';
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'pending':
      return const Color(0xFFF59E0B);
    case 'needs_fix':
      return const Color(0xFFE67E22);
    case 'approved':
      return const Color(0xFF2E9E6B);
    case 'purchase_pending':
      return const Color(0xFF1473C9);
    case 'purchased':
      return const Color(0xFF2E9E6B);
    case 'rejected':
      return const Color(0xFFE5484D);
    default:
      return const Color(0xFF5D6B7A);
  }
}

bool _isEditable(String s) => s == 'draft' || s == 'needs_fix';

String _date(DateTime? d) => d == null ? '—' : JalaliDate.fromDateTime(d.toLocal()).formatted;

String _dateTime(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${_date(l)} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

String _roleLabel(String r) {
  if (r == 'kitchen') return 'آشپزخانه';
  if (r == 'teacher') return 'مربی';
  if (r == 'deputy') return 'معاون';
  return r;
}

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? 'jpg' : name.substring(i + 1).toLowerCase();
}

String _mimeOf(String name) {
  switch (_ext(name)) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'image/jpeg';
  }
}

String _kb(int bytes) => '${(bytes / 1024).round()} KB';


/// خروجی اکسل یا چاپ جدول اقلام یک فرم
Future<void> _exportForm(BuildContext context, String formId, {required bool print}) async {
  try {
    final f = await PurchaseService.form(formId);
    final items = await PurchaseService.items(formId);
    final catTitle = await PurchaseService.categoryTitles();
    const headers = ['ردیف', 'نام کالا یا خدمت', 'تعداد', 'واحد', 'دسته', 'توضیح'];
    final rows = <List<dynamic>>[
      for (var i = 0; i < items.length; i++)
        [
          '${i + 1}',
          items[i].name,
          '${items[i].quantity}',
          items[i].unit,
          catTitle[items[i].categoryId] ?? '',
          items[i].note,
        ],
    ];
    final title =
        '${f.formNo} • ${f.title.isEmpty ? 'بدون عنوان' : f.title} • ${f.requesterName} • ${_date(f.createdAt)}';
    final fileName = 'form_${f.formNo}';
    if (!context.mounted) return;
    if (print) {
      await ExportHelper.printTable(context: context, title: title, headers: headers, rows: rows, fileName: fileName);
    } else {
      await ExportHelper.exportToExcel(context: context, title: title, headers: headers, rows: rows, fileName: fileName);
    }
  } catch (e) {
    _snack(context, _err(e), Colors.red);
  }
}

Widget _exportBar(BuildContext context, String formId) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _exportForm(context, formId, print: false),
              icon: const Icon(Icons.table_chart_rounded),
              label: const Text('خروجی اکسل'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _exportForm(context, formId, print: true),
              icon: const Icon(Icons.print_rounded),
              label: const Text('چاپ'),
            ),
          ),
        ],
      ),
    );

Future<bool> _confirm(BuildContext context, String title, String body, String okText) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(okText)),
        ],
      ),
    ),
  );
  return ok == true;
}

// =====================================================================
// فهرست فرم‌های خود کاربر (آشپز و مربی)
// =====================================================================
class PurchaseFormPage extends StatefulWidget {
  const PurchaseFormPage({super.key});

  @override
  State<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
  bool _loading = true;
  List<PurchaseForm> _forms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await PurchaseService.myForms();
    if (!mounted) return;
    setState(() {
      _forms = f;
      _loading = false;
    });
  }

  Future<void> _open(String? id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseEditorPage(formId: id)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('فرم درخواست کالا و خدمات'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(null),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('فرم جدید'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _forms.isEmpty
                ? const Center(child: Text('هنوز فرمی ثبت نشده است.', style: TextStyle(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: _forms.length,
                      itemBuilder: (_, i) {
                        final f = _forms[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            onTap: () => _open(f.id),
                            title: Text(
                              '${f.formNo} • ${f.title.isEmpty ? 'بدون عنوان' : f.title}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              f.status == 'needs_fix' && f.decisionNote.isNotEmpty
                                  ? '${_date(f.createdAt)}\nیادداشت مدیر: ${f.decisionNote}'
                                  : _date(f.createdAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                            isThreeLine: f.status == 'needs_fix' && f.decisionNote.isNotEmpty,
                            trailing: Text(
                              _statusLabel(f.status),
                              style: TextStyle(color: _statusColor(f.status), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

// =====================================================================
// ویرایشگر فرم: اقلام، پیوست‌ها، ارسال مجدد خطاها
// =====================================================================
class _Row {
  PurchaseCategory? category;
  String unit = _units.first;
  final TextEditingController name = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController note = TextEditingController();

  void dispose() {
    name.dispose();
    qty.dispose();
    note.dispose();
  }
}

/// فایلی که هنوز روی سرور نیست؛ اگر آپلود خطا بدهد، همین‌جا می‌ماند تا دوباره فرستاده شود
class _PendingFile {
  final String name;
  final Uint8List bytes;
  final String mime;
  String? path;
  String status = 'ready'; // ready | sending | failed
  String error = '';
  _PendingFile({required this.name, required this.bytes, required this.mime});
}

class PurchaseEditorPage extends StatefulWidget {
  final String? formId;
  const PurchaseEditorPage({super.key, this.formId});

  @override
  State<PurchaseEditorPage> createState() => _PurchaseEditorPageState();
}

class _PurchaseEditorPageState extends State<PurchaseEditorPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();
  DateTime? _needBy;
  bool _urgent = false;
  final List<_Row> _rows = [];
  List<PurchaseCategory> _cats = [];

  String? _formId;
  String _formNo = '';
  String _status = 'draft';
  String _returnNote = '';
  List<PurchaseAttachment> _files = [];
  List<PurchaseUploadError> _errors = [];
  final List<_PendingFile> _pending = [];

  bool _loading = true;
  bool _busy = false;

  bool get _editable => _formId == null || _isEditable(_status);
  bool get _canAttach => _formId != null && _isEditable(_status);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final cats = await PurchaseService.categories();
    _cats = cats;
    final id = widget.formId;
    if (id != null) {
      final f = await PurchaseService.form(id);
      final items = await PurchaseService.items(id);
      _formId = f.id;
      _formNo = f.formNo;
      _status = f.status;
      _returnNote = f.decisionNote;
      _title.text = f.title;
      _note.text = f.note;
      _needBy = f.needBy;
      _urgent = f.isUrgent;
      for (final it in items) {
        final r = _Row();
        for (final c in cats) {
          if (c.id == it.categoryId) r.category = c;
        }
        r.unit = _units.contains(it.unit) ? it.unit : _units.first;
        r.name.text = it.name;
        r.qty.text = '${it.quantity}';
        r.note.text = it.note;
        _rows.add(r);
      }
    }
    if (_rows.isEmpty) _rows.add(_Row());
    await _refreshFiles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshFiles() async {
    final id = _formId;
    if (id == null) return;
    final files = await PurchaseService.attachments(id);
    final errs = await PurchaseService.uploadErrors(id);
    if (!mounted) return;
    setState(() {
      _files = files;
      _errors = errs;
    });
  }

  Future<void> _reloadForm() async {
    final id = _formId;
    if (id == null) return;
    final f = await PurchaseService.form(id);
    if (!mounted) return;
    setState(() {
      _formNo = f.formNo;
      _status = f.status;
      _returnNote = f.decisionNote;
    });
  }

  List<Map<String, dynamic>>? _buildItems() {
    final out = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final cat = r.category;
      final name = r.name.text.trim();
      final qty = num.tryParse(r.qty.text.trim());
      if (cat == null) {
        _snack(context, 'برای همهٔ اقلام، دسته را انتخاب کنید', Colors.orange);
        return null;
      }
      if (name.isEmpty) {
        _snack(context, 'نام همهٔ اقلام را وارد کنید', Colors.orange);
        return null;
      }
      if (qty == null || qty <= 0) {
        _snack(context, 'تعداد هر قلم باید بیشتر از صفر باشد', Colors.orange);
        return null;
      }
      out.add({
        'category_id': cat.id,
        'kind': cat.scope == 'shared' ? 'service' : 'item',
        'name': name,
        'unit': r.unit,
        'quantity': qty,
        'note': r.note.text.trim(),
      });
    }
    return out;
  }

  Future<bool> _save() async {
    final items = _buildItems();
    if (items == null) return false;
    setState(() => _busy = true);
    try {
      final id = await PurchaseService.saveDraft(
        id: _formId,
        title: _title.text.trim(),
        needBy: _needBy,
        urgent: _urgent,
        note: _note.text.trim(),
        items: items,
      );
      _formId = id;
      await _reloadForm();
      await _refreshFiles();
      _snack(context, '✅ پیش‌نویس ذخیره شد', Colors.green);
      return true;
    } catch (e) {
      _snack(context, _err(e), Colors.red);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final ok = await _save();
    if (!ok || _formId == null) return;
    if (!mounted) return;
    final confirmed = await _confirm(
      context,
      'ارسال برای تأیید مدیر؟',
      'بعد از ارسال، تا زمانی که مدیر نیاز به اصلاح نزند، این فرم قابل ویرایش نیست.',
      'ارسال',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await PurchaseService.submit(_formId!);
      if (!mounted) return;
      _snack(context, '✅ فرم برای تأیید مدیر ارسال شد', Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _needBy ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _needBy = d);
  }

  Future<void> _addFile(ImageSource source) async {
    if (_formId == null) return;
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > _maxBytes) {
      _snack(context, 'حجم فایل بیشتر از ۸ مگابایت است', Colors.orange);
      return;
    }
    final p = _PendingFile(name: x.name, bytes: bytes, mime: _mimeOf(x.name));
    setState(() => _pending.add(p));
    await _sendPending(p);
  }

  /// آپلود یک فایل. در صورت خطا، فایل در پوشهٔ ارسال مجدد می‌ماند و خطا برای مدیر ثبت می‌شود.
  Future<void> _sendPending(_PendingFile p) async {
    final id = _formId;
    if (id == null) return;
    p.path ??= '$id/${DateTime.now().millisecondsSinceEpoch}.${_ext(p.name)}';
    setState(() {
      p.status = 'sending';
      p.error = '';
    });
    try {
      await PurchaseService.uploadAttachment(
        requestId: id,
        path: p.path!,
        fileName: p.name,
        bytes: p.bytes,
        mime: p.mime,
      );
      if (!mounted) return;
      setState(() => _pending.remove(p));
      _snack(context, '✅ فایل ارسال شد', Colors.green);
      await _refreshFiles();
    } catch (e) {
      final msg = _err(e);
      try {
        await PurchaseService.reportUploadError(requestId: id, fileName: p.name, error: msg);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        p.status = 'failed';
        p.error = msg;
      });
      await _refreshFiles();
    }
  }

  Future<void> _deleteServerFile(PurchaseAttachment f) async {
    final ok = await _confirm(context, 'حذف فایل؟', f.fileName, 'حذف');
    if (!ok) return;
    try {
      await PurchaseService.deleteAttachment(f.id);
      await _refreshFiles();
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    }
  }

  Widget _itemCard(int index, _Row r) {
    final enabled = _editable;
    return Card(
      key: ObjectKey(r),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('قلم ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                const Spacer(),
                if (enabled && _rows.length > 1)
                  IconButton(
                    tooltip: 'حذف قلم',
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE5484D)),
                    onPressed: () => setState(() {
                      r.dispose();
                      _rows.remove(r);
                    }),
                  ),
              ],
            ),
            DropdownButtonFormField<PurchaseCategory>(
              initialValue: r.category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'دسته', border: OutlineInputBorder(), isDense: true),
              items: [for (final c in _cats) DropdownMenuItem(value: c, child: Text(c.title, overflow: TextOverflow.ellipsis))],
              onChanged: enabled ? (v) => setState(() => r.category = v) : null,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: r.name,
              enabled: enabled,
              decoration: const InputDecoration(labelText: 'نام کالا یا خدمت', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: r.unit,
                    decoration: const InputDecoration(labelText: 'واحد', border: OutlineInputBorder(), isDense: true),
                    items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(u))],
                    onChanged: enabled ? (v) => setState(() => r.unit = v ?? r.unit) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: r.qty,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'تعداد', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: r.note,
              enabled: enabled,
              decoration: const InputDecoration(labelText: 'توضیح (اختیاری)', border: OutlineInputBorder(), isDense: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachments() {
    if (_formId == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('برای افزودن عکس یا فاکتور، ابتدا پیش‌نویس را ذخیره کنید.',
            style: TextStyle(color: Colors.black54)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_canAttach)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addFile(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('از گالری'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addFile(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('عکس بگیرید'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        for (final p in _pending)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            color: p.status == 'failed' ? const Color(0xFFFFEBEE) : null,
            child: ListTile(
              dense: true,
              leading: Icon(
                p.status == 'failed' ? Icons.error_outline_rounded : Icons.upload_file_rounded,
                color: p.status == 'failed' ? const Color(0xFFE5484D) : _navy,
              ),
              title: Text(p.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                p.status == 'failed'
                    ? 'ارسال نشد: ${p.error}'
                    : (p.status == 'sending' ? 'در حال ارسال...' : 'آماده ارسال'),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: p.status == 'failed'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: () => _sendPending(p), child: const Text('ارسال مجدد')),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _pending.remove(p)),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        for (final f in _files)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.attach_file_rounded, color: _navy),
              title: Text(f.fileName, style: const TextStyle(fontSize: 13)),
              subtitle: Text(_kb(f.size), style: const TextStyle(fontSize: 12)),
              trailing: _canAttach
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE5484D)),
                      onPressed: () => _deleteServerFile(f),
                    )
                  : null,
            ),
          ),
        if (_files.isEmpty && _pending.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('هنوز مدرکی پیوست نشده است.', style: TextStyle(color: Colors.black54)),
          ),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('خطاهای ثبت‌شده برای مدیر: ${_errors.length}',
              style: const TextStyle(color: Color(0xFFE5484D), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: Text(_formNo.isEmpty ? 'فرم جدید' : _formNo),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_formId != null) _exportBar(context, _formId!),
                  if (_formId != null)
                    Card(
                      color: _statusColor(_status).withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('وضعیت: ${_statusLabel(_status)}',
                                style: TextStyle(color: _statusColor(_status), fontWeight: FontWeight.bold)),
                            if (_status == 'needs_fix' && _returnNote.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('یادداشت مدیر: $_returnNote', style: const TextStyle(fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _title,
                            enabled: _editable,
                            decoration: const InputDecoration(
                              labelText: 'عنوان یا هدف درخواست (مثلاً: مواد هفتهٔ آینده)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _editable ? _pickDate : null,
                                  icon: const Icon(Icons.event_rounded),
                                  label: Text(_needBy == null
                                      ? 'تاریخ نیاز'
                                      : 'نیاز تا: ${JalaliDate.fromDateTime(_needBy!).formatted}'),
                                ),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('فوری است'),
                            value: _urgent,
                            onChanged: _editable ? (v) => setState(() => _urgent = v) : null,
                          ),
                          TextField(
                            controller: _note,
                            enabled: _editable,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'توضیح کلی (دلیل نیاز)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('اقلام درخواست',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _rows.length; i++) _itemCard(i, _rows[i]),
                  if (_editable)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _rows.add(_Row())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('افزودن قلم'),
                    ),
                  const SizedBox(height: 16),
                  const Text('پیوست‌ها و مدارک',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
                  const SizedBox(height: 6),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(padding: const EdgeInsets.all(12), child: _attachments()),
                  ),
                  if (_editable) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _save(),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('ذخیرهٔ پیش‌نویس'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(backgroundColor: _navy),
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: const Text('ارسال برای تأیید مدیر'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}

// =====================================================================
// مدیر: فهرست فرم‌ها
// =====================================================================
class PurchaseManagerPage extends StatefulWidget {
  const PurchaseManagerPage({super.key});

  @override
  State<PurchaseManagerPage> createState() => _PurchaseManagerPageState();
}

class _PurchaseManagerPageState extends State<PurchaseManagerPage> {
  bool _onlyPending = true;
  bool _loading = true;
  List<PurchaseForm> _forms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final f = await PurchaseService.allForms(onlyPending: _onlyPending);
    if (!mounted) return;
    setState(() {
      _forms = f;
      _loading = false;
    });
  }

  Future<void> _open(PurchaseForm f) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => _PurchaseDetailPage(form: f)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('درخواست‌های کالا و خدمات'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('در انتظار تأیید'),
                    selected: _onlyPending,
                    onSelected: (_) {
                      setState(() => _onlyPending = true);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('همه'),
                    selected: !_onlyPending,
                    onSelected: (_) {
                      setState(() => _onlyPending = false);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _forms.isEmpty
                      ? const Center(child: Text('فرمی نیست.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: _forms.length,
                          itemBuilder: (_, i) {
                            final f = _forms[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                onTap: () => _open(f),
                                title: Text('${f.formNo} • ${f.title.isEmpty ? 'بدون عنوان' : f.title}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(
                                  '${f.requesterName} (${_roleLabel(f.requesterRole)}) • ${_date(f.createdAt)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  _statusLabel(f.status),
                                  style: TextStyle(color: _statusColor(f.status), fontWeight: FontWeight.bold, fontSize: 12),
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

// =====================================================================
// مدیر: جزئیات فرم، مدارک، دانلود و چاپ، تصمیم
// =====================================================================
class _PurchaseDetailPage extends StatefulWidget {
  final PurchaseForm form;
  const _PurchaseDetailPage({required this.form});

  @override
  State<_PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<_PurchaseDetailPage> {
  late PurchaseForm _form;
  bool _loading = true;
  bool _busy = false;
  Map<String, String> _catTitle = {};
  List<PurchaseItemRow> _items = [];
  List<PurchaseAttachment> _files = [];
  List<PurchaseUploadError> _errors = [];
  final Set<String> _selected = {};
  bool _isRecipient = false;
  int _sentCount = 0;

  @override
  void initState() {
    super.initState();
    _form = widget.form;
    _load();
  }

  Future<void> _load() async {
    final catTitles = await PurchaseService.categoryTitles();
    final isRec = await PurchaseService.isRecipient(_form.id);
    final sentIds = await PurchaseService.recipientIds(_form.id);
    final items = await PurchaseService.items(_form.id);
    final files = await PurchaseService.attachments(_form.id);
    final errs = await PurchaseService.uploadErrors(_form.id);
    if (!mounted) return;
    setState(() {
      _catTitle = catTitles;
      _isRecipient = isRec;
      _sentCount = sentIds.length;
      _items = items;
      _files = files;
      _errors = errs;
      _selected.removeWhere((id) => !files.any((f) => f.id == id));
      _loading = false;
    });
  }

  Future<void> _exportSelected({required bool print}) async {
    final chosen = _files.where((f) => _selected.contains(f.id)).toList();
    if (chosen.isEmpty) {
      _snack(context, 'ابتدا یک یا چند فایل را انتخاب کنید', Colors.orange);
      return;
    }
    setState(() => _busy = true);
    try {
      final data = <PurchaseFileData>[];
      for (final f in chosen) {
        final bytes = await PurchaseService.download(f.path);
        data.add(PurchaseFileData(name: f.fileName, bytes: bytes, mime: f.mime));
      }
      final pdf = await PurchaseService.buildPdf(data);
      final name = '${_form.formNo}.pdf';
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => pdf, name: name);
      } else {
        await Printing.sharePdf(bytes: pdf, filename: name);
      }
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ذخیرهٔ فایل‌های اصلی (عکس یا مدرک) همان‌طور که آپلود شده‌اند
  Future<void> _saveOriginals(List<PurchaseAttachment> files) async {
    if (files.isEmpty) {
      _snack(context, 'ابتدا یک یا چند فایل را انتخاب کنید', Colors.orange);
      return;
    }
    setState(() => _busy = true);
    try {
      for (final f in files) {
        final bytes = await PurchaseService.download(f.path);
        final base = f.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        await FileSaver.instance.saveFile(
          name: '${_form.formNo}_$base',
          bytes: bytes,
          fileExtension: _ext(f.fileName),
          mimeType: MimeType.other,
        );
      }
      _snack(context, '✅ فایل‌ها ذخیره شد', Colors.green);
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(String action) async {
    String note = '';
    if (action == 'needs_fix') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('نیاز به اصلاح'),
            content: TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'یادداشت کوتاه برای درخواست‌دهنده',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ثبت')),
            ],
          ),
        ),
      );
      note = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true) return;
      if (note.isEmpty) {
        _snack(context, 'برای نیاز به اصلاح، یادداشت بنویسید', Colors.orange);
        return;
      }
    } else {
      final ok = await _confirm(
        context,
        action == 'approve' ? 'تأیید فرم؟' : 'رد فرم؟',
        'این کار را انجام می‌دهید؟',
        action == 'approve' ? 'تأیید' : 'رد',
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      await PurchaseService.decide(id: _form.id, action: action, note: note);
      if (!mounted) return;
      _snack(context, '✅ ثبت شد', Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canSend => PermissionService.instance.can(Session.role, Perm.approveRequests);

  Future<void> _addProof(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2000);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > _maxBytes) {
      _snack(context, 'حجم فایل بیشتر از ۸ مگابایت است', Colors.orange);
      return;
    }
    setState(() => _busy = true);
    try {
      final path = '${_form.id}/${DateTime.now().millisecondsSinceEpoch}.${_ext(x.name)}';
      await PurchaseService.uploadProof(
        requestId: _form.id,
        path: path,
        fileName: x.name,
        bytes: bytes,
        mime: _mimeOf(x.name),
      );
      _snack(context, '✅ فایل اضافه شد', Colors.green);
      await _load();
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markDone() async {
    final ok = await _confirm(
      context,
      'ثبت خرید؟',
      'بعد از ثبت، این فرم بسته می‌شود و در فهرست «خریدهای انجام‌شده» مدیر ثبت می‌شود.',
      'ارسال',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await PurchaseService.markPurchaseDone(_form.id);
      if (!mounted) return;
      _snack(context, '✅ خرید ثبت شد', Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRecipients() async {
    final staff = await PurchaseService.staffList();
    final current = await PurchaseService.recipientIds(_form.id);
    if (!mounted) return;
    final chosen = <String>{...current};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('ارسال فرم به'),
            content: SizedBox(
              width: 400,
              child: staff.isEmpty
                  ? const Text('کادری برای انتخاب پیدا نشد.')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final s in staff)
                          CheckboxListTile(
                            dense: true,
                            value: chosen.contains(s.id),
                            title: Text(s.name),
                            subtitle: Text(_roleLabel(s.role)),
                            onChanged: (v) => setD(() {
                              if (v == true) {
                                chosen.add(s.id);
                              } else {
                                chosen.remove(s.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ذخیره')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (chosen.isEmpty) {
      _snack(context, 'حداقل یک نفر را انتخاب کنید', Colors.orange);
      return;
    }
    setState(() => _busy = true);
    try {
      await PurchaseService.setRecipients(_form.id, chosen.toList());
      if (mounted) setState(() => _sentCount = chosen.length);
      _snack(context, '✅ فرم برای افراد انتخاب‌شده ارسال شد', Colors.green);
    } catch (e) {
      _snack(context, _err(e), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final f = _form;
    final allSelected = _files.isNotEmpty && _selected.length == _files.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: Text(f.formNo),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _exportBar(context, f.id),
                  _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.title.isEmpty ? 'بدون عنوان' : f.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
                      const SizedBox(height: 6),
                      Text('درخواست‌دهنده: ${f.requesterName} (${_roleLabel(f.requesterRole)})'),
                      Text('تاریخ ثبت: ${_date(f.createdAt)}'),
                      Text('تاریخ نیاز: ${_date(f.needBy)}'),
                      if (f.isUrgent)
                        const Text('فوری', style: TextStyle(color: Color(0xFFE5484D), fontWeight: FontWeight.bold)),
                      if (f.note.isNotEmpty) Text('توضیح: ${f.note}'),
                      const SizedBox(height: 6),
                      Text('وضعیت: ${_statusLabel(f.status)}',
                          style: TextStyle(color: _statusColor(f.status), fontWeight: FontWeight.bold)),
                      if (f.status == 'purchased')
                        Text('خریدار: ${f.buyerName}\nزمان خرید: ${_dateTime(f.purchasedAt)}',
                            style: const TextStyle(fontSize: 13)),
                    ],
                  )),
                  if (_errors.isNotEmpty)
                    _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('خطاهای آپلود گزارش‌شده',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5484D))),
                        const SizedBox(height: 4),
                        for (final e in _errors)
                          Text('• ${e.fileName}: ${e.errorText}', style: const TextStyle(fontSize: 12)),
                      ],
                    )),
                  _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('اقلام', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                      const SizedBox(height: 6),
                      for (var i = 0; i < _items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${i + 1}. ${_items[i].name} • ${_items[i].quantity} ${_items[i].unit} '
                            '• ${_catTitle[_items[i].categoryId] ?? ''}'
                            '${_items[i].note.isEmpty ? '' : ' • ${_items[i].note}'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  )),
                  _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مدارک پیوست', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                      if (_files.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('مدرکی پیوست نشده است.', style: TextStyle(color: Colors.black54)),
                        ),
                      for (final file in _files)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selected.contains(file.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(file.id);
                            } else {
                              _selected.remove(file.id);
                            }
                          }),
                          title: Text(file.fileName, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(_kb(file.size), style: const TextStyle(fontSize: 12)),
                          secondary: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => _AttachmentViewerPage(file: file, formNo: f.formNo)),
                                ),
                                child: file.isImage
                                    ? _AttachmentThumb(path: file.path)
                                    : const Icon(Icons.description_rounded, color: _navy, size: 48),
                              ),
                              IconButton(
                                tooltip: 'دانلود فایل اصلی',
                                icon: const Icon(Icons.download_rounded, color: _navy),
                                onPressed: _busy ? null : () => _saveOriginals([file]),
                              ),
                            ],
                          ),
                        ),
                      if (_files.isNotEmpty) ...[
                        const Divider(),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => setState(() {
                                if (allSelected) {
                                  _selected.clear();
                                } else {
                                  _selected.addAll(_files.map((x) => x.id));
                                }
                              }),
                              icon: const Icon(Icons.select_all_rounded),
                              label: Text(allSelected ? 'لغو انتخاب همه' : 'انتخاب همه'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _exportSelected(print: true),
                              icon: const Icon(Icons.print_rounded),
                              label: const Text('چاپ انتخاب‌شده'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _saveOriginals(_files.where((x) => _selected.contains(x.id)).toList()),
                              icon: const Icon(Icons.download_for_offline_rounded),
                              label: const Text('دانلود اصلی انتخاب‌شده'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )),
                  if (_isRecipient && f.status == 'approved') ...[
                    _card(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('فاکتور یا عکس خرید',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : () => _addProof(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded),
                                label: const Text('از گالری'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : () => _addProof(ImageSource.camera),
                                icon: const Icon(Icons.photo_camera_rounded),
                                label: const Text('عکس بگیرید'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )),
                  ],
                  if (_isRecipient && f.status == 'approved') ...[
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _markDone,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E9E6B)),
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text('خرید انجام شد'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (f.status == 'approved' && _canSend) ...[
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: (_busy || _sentCount > 0) ? null : _openRecipients,
                        style: FilledButton.styleFrom(backgroundColor: _navy),
                        icon: Icon(_sentCount > 0 ? Icons.check_circle_rounded : Icons.send_rounded),
                        label: Text(_sentCount > 0
                            ? 'فرم ارسال شد ($_sentCount نفر)'
                            : 'ارسال فرم به مربیان و کادر'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (f.status == 'pending') ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _busy ? null : () => _decide('reject'),
                          child: const Text('رد'),
                        ),
                        OutlinedButton(
                          onPressed: _busy ? null : () => _decide('needs_fix'),
                          child: const Text('نیاز به اصلاح'),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : () => _decide('approve'),
                          style: FilledButton.styleFrom(backgroundColor: _navy),
                          child: const Text('تأیید'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }
}

// =====================================================================
// مشاهدهٔ یک فایل با دانلود و چاپ
// =====================================================================
class _AttachmentViewerPage extends StatefulWidget {
  final PurchaseAttachment file;
  final String formNo;
  const _AttachmentViewerPage({required this.file, required this.formNo});

  @override
  State<_AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<_AttachmentViewerPage> {
  Uint8List? _bytes;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await PurchaseService.download(widget.file.path);
      if (!mounted) return;
      setState(() => _bytes = b);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _err(e));
    }
  }

  Future<void> _saveOriginal() async {
    final b = _bytes;
    if (b == null) return;
    final base = widget.file.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    await FileSaver.instance.saveFile(
      name: '${widget.formNo}_$base',
      bytes: b,
      fileExtension: _ext(widget.file.fileName),
      mimeType: MimeType.other,
    );
  }

  Future<void> _print() async {
    final b = _bytes;
    if (b == null) return;
    final pdf = await PurchaseService.buildPdf([
      PurchaseFileData(name: widget.file.fileName, bytes: b, mime: widget.file.mime),
    ]);
    await Printing.layoutPdf(onLayout: (_) async => pdf, name: '${widget.formNo}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.file.fileName, style: const TextStyle(fontSize: 14)),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
        ),
        body: _error.isNotEmpty
            ? Center(child: Text(_error, style: const TextStyle(color: Colors.white)))
            : b == null
                ? const Center(child: CircularProgressIndicator())
                : widget.file.isImage
                    ? InteractiveViewer(child: Center(child: Image.memory(b)))
                    : const Center(
                        child: Text('پیش‌نمایش برای این نوع فایل نیست', style: TextStyle(color: Colors.white)),
                      ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: b == null ? null : _saveOriginal,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('دانلود اصلی'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: b == null ? null : _print,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('چاپ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// بندانگشتی عکس مدرک در فهرست مدیر
// =====================================================================
class _AttachmentThumb extends StatelessWidget {
  final String path;
  const _AttachmentThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: PurchaseService.signedUrl(path),
      builder: (context, snap) {
        final url = snap.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 72,
            height: 72,
            child: url == null
                ? const ColoredBox(
                    color: Color(0xFFE3EAF2),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const ColoredBox(
                      color: Color(0xFFE3EAF2),
                      child: Icon(Icons.broken_image_rounded, color: _navy),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// آشپز و مربی: فرم‌های تأییدشده که مدیر برای آنها ارسال کرده

// =====================================================================
// خریدها: فهرست خریدهای در جریان و انجام‌شده (مدیر و خریدار)
// =====================================================================
class PurchaseBuyingPage extends StatefulWidget {
  final bool managerView;
  const PurchaseBuyingPage({super.key, required this.managerView});

  @override
  State<PurchaseBuyingPage> createState() => _PurchaseBuyingPageState();
}

class _PurchaseBuyingPageState extends State<PurchaseBuyingPage> {
  bool _loading = true;
  List<PurchaseForm> _inProgress = [];
  List<PurchaseForm> _done = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<PurchaseForm> inProgress;
    List<PurchaseForm> done;
    if (widget.managerView) {
      inProgress = await PurchaseService.inProgressForms();
      done = await PurchaseService.purchasedForms();
    } else {
      final all = await PurchaseService.assignedForms();
      inProgress = all.where((f) => f.status == 'approved').toList();
      done = all.where((f) => f.status == 'purchased').toList();
    }
    if (!mounted) return;
    setState(() {
      _inProgress = inProgress;
      _done = done;
      _loading = false;
    });
  }

  Future<void> _open(PurchaseForm f) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _PurchaseDetailPage(form: f)));
    _load();
  }

  Widget _list(List<PurchaseForm> items, String empty, {required bool isDone}) {
    if (items.isEmpty) {
      return Center(child: Text(empty, style: const TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final f = items[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              onTap: () => _open(f),
              isThreeLine: isDone,
              title: Text(
                '${f.formNo} • ${f.title.isEmpty ? 'بدون عنوان' : f.title}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                isDone
                    ? 'خریدار: ${f.buyerName.isEmpty ? '—' : f.buyerName}\n${_dateTime(f.purchasedAt)}'
                    : '${f.requesterName} (${_roleLabel(f.requesterRole)}) • ${_date(f.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                _statusLabel(f.status),
                style: TextStyle(color: _statusColor(f.status), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F8FF),
          appBar: AppBar(
            title: Text(widget.managerView ? 'خریدها' : 'خریدهای من'),
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'در جریان (${_inProgress.length})'),
                Tab(text: 'انجام‌شده (${_done.length})'),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _list(_inProgress, 'خریدی در جریان نیست', isDone: false),
                    _list(_done, 'خریدی انجام نشده است', isDone: true),
                  ],
                ),
        ),
      ),
    );
  }
}

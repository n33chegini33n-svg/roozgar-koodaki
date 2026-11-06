import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/registration_model.dart';
import '../models/registration_docs.dart';
import '../utils/jalali.dart';
import '../parent/parent_sections.dart' show kPageBg, softCard;
import '../theme/app_colors.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  List<RegistrationDraft> _children = [];
  int _active = 0;
  int _step = 0;
  bool _loading = true;
  bool _editing = false;
  bool _busy = false;
  bool _uploading = false;
  final List<({Uint8List bytes, String ext, String name})> _pending = [];
  List<Map<String, dynamic>> _archive = [];
  int _doneCount = 0;
  final Set<String> _selArchive = {};

  static const _titles = [
    '۱. مشخصات فردی و شناختی نوآموز',
    '۲. اطلاعات اولیا و راه‌های ارتباط اضطراری',
    '۳. پرونده پزشکی، سلامت و ایمنی (حیاتی)',
    '۴. ملاحظات رفتاری، عاطفی و الگوی زیستی',
    '۵. افراد مجاز تحویل و نکات خاص اولیا',
    '۶. تعهدنامه و تأیید صحت اطلاعات',
  ];

  static const List<List<String>> _stepKeys = [
    ['نام نوآموز', 'نام خانوادگی', 'نام محبوب در خانه', 'کد ملی نوآموز', 'تاریخ دقیق تولد (روز/ماه/سال)', 'مقطع تحصیلی نوآموز', 'محل تولد', 'تعداد فرزندان خانواده', 'فرزند چندم خانواده'],
    ['نام و خانوادگی پدر', 'شغل و محل کار پدر', 'مدرک تحصیلی پدر', 'شماره همراه اصلی پدر', 'شماره همراه شبکه مجازی پدر (ایتا/واتساپ)', 'نام و خانوادگی مادر', 'شغل و محل کار مادر', 'مدرک تحصیلی مادر', 'شماره همراه اصلی مادر', 'شماره همراه شبکه مجازی مادر (ایتا/واتساپ)', 'نام و نسبت تماس اضطراری دوم', 'شماره همراه تماس اضطراری دوم', 'آدرس دقیق منزل', 'کد پستی منزل', 'وضعیت سکونت'],
    ['گروه خونی و RH', 'استفاده از وسیله کمکی', 'سابقه بیماری خاص (آسم، صرع، قلب، دیابت، تشنج و...)', 'حساسیت و آلرژی (غذایی، دارویی، فصلی)', 'داروی مصرفی خاص در ساعات حضور در مرکز'],
    ['سابقه حضور در مهدکودک یا پیش‌دبستانی', 'وضعیت استقلال در دستشویی رفتن', 'ترس‌های شناخته‌شده کودک', 'علاقه‌مندی‌های ویژه، اسباب‌بازی یا بازی‌های محبوب', 'بهترین روش آرام کردن کودک هنگام بی‌قراری یا گریه'],
    ['نام و خانوادگی فرد مجاز اول', 'نسبت فرد مجاز اول با کودک', 'شماره همراه فرد مجاز اول', 'نام و خانوادگی فرد مجاز دوم', 'نسبت فرد مجاز دوم با کودک', 'شماره همراه فرد مجاز دوم', 'توضیحات منحصر به‌فرد اولیا'],
    ['نام و نام خانوادگی ولی قانونی نوآموز', 'تاریخ تکمیل فرم'],
  ];

  static final List<String> _allKeys = [for (final s in _stepKeys) ...s];

  RegistrationDraft? get _cur => _children.isEmpty ? null : _children[_active];
  String get _status => _cur?.status ?? 'draft';
  String? get _rejectionReason => _cur?.rejectionReason;
  bool get _canEditFields =>
      _cur != null && (_status == 'draft' || _status == 'rejected' || (_status == 'submitted' && _editing));

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String key) => _controllers.putIfAbsent(key, () => TextEditingController());

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Map<String, String> _values() => {for (final e in _controllers.entries) e.key: e.value.text.trim()};

  void _retireControllers() {
    final old = _controllers.values.toList();
    _controllers.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }

  void _bindChild(int i) {
    _retireControllers();
    _active = i;
    _step = 0;
    _editing = false;
    _pending.clear();
    final vals = _children[i].values;
    for (final k in _allKeys) {
      _controllers[k] = TextEditingController(text: vals[k] ?? '');
    }
  }

  /// select: null = همان فعلی، -1 = آخرین فرزند، عدد = همان اندیس
  Future<void> _loadChildren({int? select}) async {
    final list = await RegistrationDraftService.myChildren();
    if (!mounted) return;
    setState(() {
      _children = list;
      _loading = false;
      if (list.isEmpty) {
        _retireControllers();
        _active = 0;
        return;
      }
      final want = select == null ? _active : (select < 0 ? list.length - 1 : select);
      _bindChild(want.clamp(0, list.length - 1).toInt());
    });
    _loadArchive();
  }

  int? _missingStep() {
    for (var s = 0; s < _stepKeys.length; s++) {
      for (final k in _stepKeys[s]) {
        if ((_controllers[k]?.text.trim() ?? '').isEmpty) return s;
      }
    }
    return null;
  }

  Future<void> _saveProgress() async {
    final cur = _cur;
    if (cur == null || cur.status == 'submitted' || cur.status == 'approved') return;
    try {
      final v = _values();
      await RegistrationDraftService.saveDraft(cur, v);
      _children[_active] = cur.copyWith(values: {...cur.values, ...v}, studentName: v[kRegNameKey] ?? cur.studentName);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _next() async {
    final cur = _cur;
    if (cur == null) {
      _snack('ابتدا یک فرزند ثبت کنید');
      return;
    }
    final last = _step == _titles.length - 1;
    if (!_canEditFields) {
      if (!last) {
        setState(() => _step++);
      } else {
        _snack('این پرونده در حال حاضر قابل ارسال نیست');
      }
      return;
    }
    if (_stepKeys[_step].any((k) => (_controllers[k]?.text.trim() ?? '').isEmpty)) {
      _snack('لطفاً تمام فیلدهای این مرحله را تکمیل فرمایید');
      return;
    }
    await _saveProgress();
    if (!last) {
      setState(() => _step++);
    } else {
      await _submit();
    }
  }

  Future<bool?> _confirmCovenant() {
    var tick = false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأیید تعهدنامه'),
            content: CheckboxListTile(
              value: tick,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setD(() => tick = v ?? false),
              title: const Text('تعهدنامه را مطالعه کرده‌ام و صحت اطلاعات را تأیید می‌کنم.'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
              FilledButton(
                onPressed: tick ? () => Navigator.pop(ctx, true) : null,
                child: const Text('ارسال'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final cur = _cur;
    if (cur == null || _busy) return;
    if (!_canEditFields) {
      _snack('این پرونده در حال حاضر قابل ارسال نیست');
      return;
    }
    final miss = _missingStep();
    if (miss != null) {
      setState(() => _step = miss);
      _snack('لطفاً تمام فیلدهای این مرحله را تکمیل فرمایید');
      return;
    }
    final ok = await _confirmCovenant();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await RegistrationDraftService.submitRecord(cur, _values(), confirmed: true);
      _editing = false;
      _snack('پرونده برای بررسی مدیریت ارسال شد');
      await _loadChildren();
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startEdit() {
    setState(() => _editing = true);
    _snack('ویرایش فعال شد؛ با ارسال، سهمیه یک‌بار ویرایش مصرف می‌شود');
  }

  Future<void> _addChild() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ثبت فرزند جدید'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'نام و نام خانوادگی نوآموز', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('ثبت')),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await RegistrationDraftService.createChild(name);
      await _loadChildren(select: -1);
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _removeChild(int i) async {
    final d = _children[i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف پرونده فرزند؟'),
          content: Text('پرونده ${d.studentName} حذف می‌شود.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await RegistrationDraftService.setDeleted(id: d.id, name: d.studentName, deleted: true);
      await _loadChildren();
      _snack('پرونده حذف شد');
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _loadArchive() async {
    final cur = _cur;
    if (cur == null) {
      if (mounted) setState(() => _archive = []);
      return;
    }
    try {
      final list = await RegistrationDocs.forRecord(cur.id);
      final withUrls = <Map<String, dynamic>>[];
      for (final d in list) {
        final url = await RegistrationDocs.signedUrl('${d['path']}');
        withUrls.add({...d, 'url': url});
      }
      if (mounted) setState(() => _archive = withUrls);
    } catch (_) {}
  }

  void _toggleArchive(String id) {
    setState(() {
      if (!_selArchive.add(id)) _selArchive.remove(id);
    });
  }

  Future<void> _resendSelected() async {
    final cur = _cur;
    if (cur == null || _selArchive.isEmpty) return;
    final chosen = _archive.where((d) => _selArchive.contains('${d['id']}')).toList();
    var current = cur;
    setState(() => _uploading = true);
    try {
      for (final d in chosen) {
        final path = '${d['path']}';
        await RegistrationDocs.reattach(
          recordId: current.id,
          path: path,
          values: current.values,
        );
        current = current.copyWith(attachmentUrl: path, values: {...current.values, kRegAttachKey: path});
      }
      if (!mounted) return;
      setState(() {
        _children[_active] = current;
        _selArchive.clear();
      });
      _snack('مدرک(های) انتخاب‌شده دوباره ارسال شد');
      await _loadArchive();
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDocs() async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (files.isEmpty) return;
    final items = <({Uint8List bytes, String ext, String name})>[];
    for (final x in files) {
      final bytes = await x.readAsBytes();
      final dot = x.name.lastIndexOf('.');
      items.add((bytes: bytes, ext: dot >= 0 ? x.name.substring(dot + 1).toLowerCase() : 'jpg', name: x.name));
    }
    setState(() {
      _pending
        ..clear()
        ..addAll(items);
      _doneCount = 0;
    });
  }

  Future<void> _uploadDocs() async {
    final cur = _cur;
    if (cur == null || _pending.isEmpty || _uploading) return;
    setState(() {
      _uploading = true;
      _doneCount = 0;
    });
    var current = cur;
    try {
      for (final f in List.of(_pending)) {
        current = await RegistrationDraftService.uploadDocument(current, f.bytes, f.ext);
        await RegistrationDocs.archive(
          recordId: current.id,
          parentId: current.parentId,
          path: current.attachmentUrl ?? '',
          fileName: f.name,
        );
        if (!mounted) return;
        setState(() {
          _children[_active] = current;
          _doneCount++;
        });
      }
      if (!mounted) return;
      setState(() => _pending.clear());
      _snack('مدارک ارسال شد');
      await _loadArchive();
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _badge(String s) => switch (s) {
        'approved' => '🟢 تأیید شده',
        'submitted' => '🟡 در انتظار',
        'rejected' => '🔴 نیاز به اصلاح',
        _ => '⚪ پیش‌نویس',
      };

  Widget _childrenBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _children.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(
                    label: Text('${_children[i].studentName.isEmpty ? 'بدون نام' : _children[i].studentName} ${_badge(_children[i].status)}'),
                    selected: i == _active,
                    onSelected: (_) {
                      if (i != _active) {
                    setState(() => _bindChild(i));
                    _loadArchive();
                  }
                    },
                  ),
                  if (_children[i].status != 'approved')
                    IconButton(
                      tooltip: 'حذف پرونده',
                      icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                      onPressed: () => _removeChild(i),
                    ),
                ],
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('ثبت فرزند جدید'),
            onPressed: _addChild,
          ),
        ],
      ),
    );
  }

  Widget _docBox() {
    final cur = _cur;
    return softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مدارک شناسایی نوآموز (تصویر شناسنامه)',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 8),
          for (final f in _pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(f.bytes, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          if (_uploading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(value: _pending.isEmpty ? null : _doneCount / _pending.length),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (cur == null || _uploading) ? null : _pickDocs,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('انتخاب چند عکس'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_pending.isEmpty || _uploading || cur == null) ? null : _uploadDocs,
                  icon: const Icon(Icons.upload_rounded),
                  label: Text('ارسال ${_pending.isEmpty ? '' : faDigits(_pending.length)} مدرک'),
                ),
              ),
            ],
          ),
          if (_archive.isNotEmpty) ...[
            const Divider(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text('بانک مدارک (برای ارسال دوباره، انتخاب کنید)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                ),
                if (_selArchive.isNotEmpty)
                  FilledButton.icon(
                    onPressed: (_uploading || cur == null) ? null : _resendSelected,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text('ارسال مجدد ${faDigits(_selArchive.length)}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _archive)
                  GestureDetector(
                    onTap: () => _toggleArchive('${d['id']}'),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selArchive.contains('${d['id']}') ? AppColors.navy : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network('${d['url']}', width: 76, height: 76, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                                width: 76, height: 76, child: Icon(Icons.broken_image_rounded))),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _topActionBar() {
    final cur = _cur!;
    String? label;
    IconData icon = Icons.send_rounded;
    VoidCallback? action = _submit;
    if (_status == 'draft') {
      label = 'ارسال نهایی پرونده 📤';
    } else if (_status == 'rejected') {
      label = 'ارسال مجدد به مدیریت 📤';
    } else if (_status == 'submitted' && _editing) {
      label = 'ثبت ویرایش و ارسال 📤';
    } else if (_status == 'submitted' && cur.editCount < 1) {
      label = 'ویرایش اطلاعات پرونده ✏️ (تنها ۱ بار مجاز)';
      icon = Icons.edit_rounded;
      action = _startEdit;
    }
    if (label == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: _busy ? null : action,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final cur = _cur;
    final last = _step == _titles.length - 1;
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: const Text('پرونده جامع ثبت‌نام نوآموز'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _headerCard(),
            const SizedBox(height: 12),
            _childrenBar(),
            const SizedBox(height: 12),
            _docBox(),
            const SizedBox(height: 12),
            if (cur == null)
              softCard(
                child: const Text('هنوز فرزندی ثبت نشده است. با دکمهٔ «ثبت فرزند جدید» شروع کنید.'),
              )
            else ...[
              _statusBannerCard(),
              const SizedBox(height: 8),
              _topActionBar(),
              const SizedBox(height: 12),
              _stepBar(),
              const SizedBox(height: 14),
              softCard(
                child: AbsorbPointer(
                  absorbing: !_canEditFields,
                  child: _buildSectionContent(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('مرحله قبل'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.navy,
                      ),
                      icon: Icon(last ? Icons.send_rounded : Icons.arrow_back_rounded),
                      label: Text(last ? 'ارسال نهایی پرونده' : 'مرحله بعد'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE1F3FF), Color(0xFFF8FCFF)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFB7E2F8)),
        ),
        child: const Column(
          children: [
            Icon(Icons.child_care_rounded, size: 44, color: Color(0xFF0288D1)),
            SizedBox(height: 6),
            Text(
              'مجموعه آموزشی دخترانه روزگار کودکی',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            SizedBox(height: 4),
            Text(
              'مهدکودک • پیش‌دبستانی • دبستان | پرونده ثبت‌نام و سلامت نوآموز',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );

  Widget _statusBannerCard() {
    Color c;
    IconData ic;
    String t;
    String d;
    if (_status == 'approved') {
      c = const Color(0xFF2E7D32);
      ic = Icons.check_circle_rounded;
      t = 'وضعیت: تأیید شده توسط مدیریت';
      d = 'پرونده ثبت‌نام این نوآموز توسط مدیریت تأیید شده است.';
    } else if (_status == 'rejected') {
      c = const Color(0xFFC62828);
      ic = Icons.error_rounded;
      t = '⚠️ پرونده نیازمند اصلاح است';
      d = (_rejectionReason ?? '').isNotEmpty ? 'علت: $_rejectionReason' : 'لطفاً موارد اعلام‌شده را اصلاح و دوباره ارسال کنید.';
    } else if (_status == 'submitted') {
      c = const Color(0xFFF57F17);
      ic = Icons.hourglass_bottom_rounded;
      t = 'وضعیت: در انتظار بررسی مدیریت';
      d = 'اطلاعات ارسال شده و در صف بررسی است.';
    } else {
      c = const Color(0xFF546E7A);
      ic = Icons.edit_note_rounded;
      t = 'وضعیت: پیش‌نویس';
      d = 'تکمیل مراحل و ارسال نهایی پرونده.';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ic, color: c, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
                const SizedBox(height: 4),
                Text(d, style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBar() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('مرحله ${_step + 1} از ${_titles.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
              Flexible(child: Text(_titles[_step], style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < _titles.length; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: i <= _step ? AppColors.navy : const Color(0xFFDCEAF2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );

  Widget _buildSectionContent() {
    switch (_step) {
      case 0:
        return _sectionStudentInfo();
      case 1:
        return _sectionParentsInfo();
      case 2:
        return _sectionMedicalInfo();
      case 3:
        return _sectionBehavioralInfo();
      case 4:
        return _sectionAuthorizedPickupAndNotes();
      case 5:
        return _sectionAgreement();
      default:
        return const SizedBox();
    }
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
      );

  Widget _input(String key, {String? hint, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controller(key),
        maxLines: maxLines,
        keyboardType: keyboardType,
        enabled: _canEditFields,
        decoration: InputDecoration(
          labelText: key,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _sectionStudentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_titles[0]),
        _input('نام نوآموز'),
        _input('نام خانوادگی'),
        _input('نام محبوب در خانه'),
        _input('کد ملی نوآموز', keyboardType: TextInputType.number),
        _input('تاریخ دقیق تولد (روز/ماه/سال)', hint: 'مثال: ۱۴۰۰/۰۲/۱۵'),
        _input('مقطع تحصیلی نوآموز', hint: 'مهدکودک / پیش‌دبستانی / دبستان'),
        _input('محل تولد'),
        _input('تعداد فرزندان خانواده', keyboardType: TextInputType.number),
        _input('فرزند چندم خانواده', keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _sectionParentsInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_titles[1]),
        const Text('• مشخصات پدر:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        _input('نام و خانوادگی پدر'),
        _input('شغل و محل کار پدر'),
        _input('مدرک تحصیلی پدر'),
        _input('شماره همراه اصلی پدر', keyboardType: TextInputType.phone),
        _input('شماره همراه شبکه مجازی پدر (ایتا/واتساپ)', keyboardType: TextInputType.phone),
        const Divider(height: 24),
        const Text('• مشخصات مادر:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        _input('نام و خانوادگی مادر'),
        _input('شغل و محل کار مادر'),
        _input('مدرک تحصیلی مادر'),
        _input('شماره همراه اصلی مادر', keyboardType: TextInputType.phone),
        _input('شماره همراه شبکه مجازی مادر (ایتا/واتساپ)', keyboardType: TextInputType.phone),
        const Divider(height: 24),
        const Text('• تماس اضطراری دوم (غیر از والدین):', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        _input('نام و نسبت تماس اضطراری دوم'),
        _input('شماره همراه تماس اضطراری دوم', keyboardType: TextInputType.phone),
        _input('آدرس دقیق منزل', maxLines: 2),
        _input('کد پستی منزل', keyboardType: TextInputType.number),
        _input('وضعیت سکونت', hint: 'شخصی / استیجاری'),
      ],
    );
  }

  Widget _sectionMedicalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_titles[2]),
        _input('گروه خونی و RH', hint: 'مثال: +O / -A / +AB'),
        _input('استفاده از وسیله کمکی', hint: 'عینک / سمعک / هیچ‌کدام'),
        _input('سابقه بیماری خاص (آسم، صرع، قلب، دیابت، تشنج و...)', maxLines: 2, hint: 'در صورت عدم وجود عبارت «ندارد» درج شود'),
        _input('حساسیت و آلرژی (غذایی، دارویی، فصلی)', maxLines: 2, hint: 'عنوان دقیق حساسیت یا «ندارد»'),
        _input('داروی مصرفی خاص در ساعات حضور در مرکز', maxLines: 2, hint: 'نام دارو و زمان مصرف یا «ندارد»'),
      ],
    );
  }

  Widget _sectionBehavioralInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_titles[3]),
        _input('سابقه حضور در مهدکودک یا پیش‌دبستانی', hint: 'خیر (بار اول است) / بله (مدت زمان)'),
        _input('وضعیت استقلال در دستشویی رفتن', hint: 'کاملاً مستقل / نیاز به یادآوری مربی / نیاز به کمک مربی'),
        _input('ترس‌های شناخته‌شده کودک', hint: 'تاریکی / صدای بلند / حیوانات / جدایی از والدین / سایر'),
        _input('علاقه‌مندی‌های ویژه، اسباب‌بازی یا بازی‌های محبوب', maxLines: 2),
        _input('بهترین روش آرام کردن کودک هنگام بی‌قراری یا گریه', maxLines: 2),
      ],
    );
  }

  Widget _sectionAuthorizedPickupAndNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_titles[4]),
        const Text('• فرد مجاز اول (به غیر از پدر و مادر):', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        _input('نام و خانوادگی فرد مجاز اول'),
        _input('نسبت فرد مجاز اول با کودک'),
        _input('شماره همراه فرد مجاز اول', keyboardType: TextInputType.phone),
        const Divider(height: 24),
        const Text('• فرد مجاز دوم (به غیر از پدر و مادر):', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 8),
        _input('نام و خانوادگی فرد مجاز دوم'),
        _input('نسبت فرد مجاز دوم با کودک'),
        _input('شماره همراه فرد مجاز دوم', keyboardType: TextInputType.phone),
        const Divider(height: 24),
        _input('توضیحات منحصر به‌فرد اولیا', hint: 'علت تغذیه، عادت خواب یا شرایط خاص کودک را در صورت وجود بنویسید.', maxLines: 3),
      ],
    );
  }

  Widget _sectionAgreement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_titles[5]),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Text(
            'تعهدنامه ولی نوآموز:\nاینجانب ولی قانونی نوآموز، صحت تمام اطلاعات فوق را تأیید می‌نمایم. همچنین متعهد می‌شوم در صورت بروز هرگونه تغییر در شماره‌های تماس، آدرس منزل یا وضعیت جسمی و دارویی نوآموز، مراتب را بلافاصله به مدیریت مرکز اطلاع دهم.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF1B5E20)),
          ),
        ),
        const SizedBox(height: 14),
        _input('نام و نام خانوادگی ولی قانونی نوآموز'),
        _input('تاریخ تکمیل فرم', hint: '۱۴۰۳/--/--'),
        const Text(
          'تأیید نهایی تعهدنامه هنگام ارسال پرونده، از شما پرسیده می‌شود.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../models/registration_model.dart';
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
  int _step = 0;
  bool _accepted = false;
  bool _loading = true;

  static const _titles = [
    'مشخصات فردی و شناختی نوآموز',
    'اطلاعات اولیا و راه‌های ارتباط اضطراری',
    'پرونده پزشکی، سلامت و ایمنی',
    'ملاحظات رفتاری، عاطفی و الگوی زیستی',
    'افراد مجاز برای تحویل گرفتن کودک',
    'تعهدنامه و تأیید صحت اطلاعات',
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final draft = await RegistrationDraftService.load();
    if (!mounted) return;
    if (draft != null) {
      for (final entry in draft.values.entries) {
        _controllers[entry.key] = TextEditingController(text: entry.value);
      }
      _accepted = draft.accepted;
    }
    setState(() => _loading = false);
  }

  TextEditingController _controller(String key) => _controllers.putIfAbsent(key, TextEditingController.new);

  Future<void> _save() async {
    await RegistrationDraftService.save(RegistrationDraft(
      values: {for (final e in _controllers.entries) e.key: e.value.text},
      accepted: _accepted,
    ));
  }

  Future<void> _next() async {
    if (_step == 0 && !(_formKey.currentState?.validate() ?? true)) return;
    await _save();
    if (!mounted) return;
    if (_step < _titles.length - 1) {
      setState(() => _step++);
    } else if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تأیید صحت اطلاعات الزامی است')));
    } else {
      try {
        await RegistrationDraftService.submit(
          RegistrationDraft(
            values: {for (final e in _controllers.entries) e.key: e.value.text},
            accepted: _accepted,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فرم برای بررسی مدیریت ارسال شد')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ارسال فرم انجام نشد: $e')));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(title: const Text('پرونده جامع ثبت‌نام'), centerTitle: true, backgroundColor: Colors.white, foregroundColor: AppColors.navy),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            const SizedBox(height: 14),
            _stepBar(),
            const SizedBox(height: 14),
            softCard(child: _stepContent()),
            const SizedBox(height: 14),
            Row(
              children: [
                if (_step > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('مرحله قبل'))),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(_step == _titles.length - 1 ? Icons.save_rounded : Icons.arrow_back_rounded),
                    label: Text(_step == _titles.length - 1 ? 'ذخیره نهایی' : 'مرحله بعد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE1F3FF), Color(0xFFF8FCFF)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFB7E2F8)),
        ),
        child: const Column(
          children: [
            Icon(Icons.child_care_rounded, size: 42, color: Color(0xFF0288D1)),
            SizedBox(height: 6),
            Text('مجموعه آموزشی دخترانه روزگار کودکی', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
            SizedBox(height: 4),
            Text('مهدکودک • پیش‌دبستانی • دبستان', textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _stepBar() => Row(
        children: [
          for (var i = 0; i < _titles.length; i++)
            Expanded(
              child: Container(
                height: 7,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                decoration: BoxDecoration(color: i <= _step ? const Color(0xFF0288D1) : const Color(0xFFDCEAF2), borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      );

  Widget _stepContent() {
    final fields = <String>[];
    switch (_step) {
      case 0:
        fields.addAll(['نام', 'نام خانوادگی', 'نام محبوب در خانه', 'کد ملی', 'تاریخ تولد', 'محل تولد', 'تعداد فرزندان', 'فرزند چندم خانواده']);
        break;
      case 1:
        fields.addAll(['نام و خانوادگی پدر', 'شماره همراه پدر', 'شغل و محل کار پدر', 'نام و خانوادگی مادر', 'شماره همراه مادر', 'شغل و محل کار مادر', 'تماس اضطراری دوم', 'شماره تماس اضطراری دوم', 'آدرس دقیق منزل', 'کد پستی']);
        break;
      case 2:
        fields.addAll(['گروه خونی', 'سابقه بیماری خاص', 'حساسیت و آلرژی', 'داروی مصرفی در مرکز']);
        break;
      case 3:
        fields.addAll(['سابقه مهد یا پیش‌دبستانی', 'استقلال در دستشویی رفتن', 'ترس‌های شناخته‌شده', 'علاقه‌مندی‌ها و بازی‌های محبوب', 'بهترین روش آرام کردن کودک']);
        break;
      case 4:
        fields.addAll(['نام فرد مجاز اول', 'نسبت فرد اول', 'شماره همراه فرد اول', 'نام فرد مجاز دوم', 'نسبت فرد دوم', 'شماره همراه فرد دوم', 'نکات یا توضیحات خاص اولیا']);
        break;
      case 5:
        return _agreement();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_titles[_step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 14),
        for (final field in fields) ...[
          TextFormField(
            controller: _controller(field),
            maxLines: field.contains('آدرس') || field.contains('توضیحات') || field.contains('روش') || field.contains('علاقه') ? 3 : 1,
            keyboardType: field.contains('شماره') || field.contains('کد') ? TextInputType.phone : TextInputType.text,
            validator: _step == 0 && (field == 'نام' || field == 'نام خانوادگی') ? (v) => v == null || v.trim().isEmpty ? 'این مورد الزامی است' : null : null,
            decoration: InputDecoration(labelText: field, border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _agreement() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_titles[_step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 14),
          const Text('تعهدنامه: اینجانب ولی قانونی نوآموز، صحت اطلاعات واردشده را تأیید می‌نمایم و متعهد می‌شوم تغییرات شماره تماس، نشانی یا وضعیت سلامت را به مدیریت اطلاع دهم.'),
          const SizedBox(height: 16),
          TextFormField(controller: _controller('نام و نام خانوادگی ولی'), decoration: const InputDecoration(labelText: 'نام و نام خانوادگی ولی', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controller('کد تأیید'),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'کد تأیید تعهدنامه',
              helperText: 'کد تأیید را از پیامک یا مدیریت مرکز وارد کنید.',
              border: OutlineInputBorder(),
            ),
          ),
          CheckboxListTile(
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
            title: const Text('تعهدنامه و صحت اطلاعات را می‌پذیرم'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Text('این تعهدنامه به‌تنهایی جایگزین مشاوره یا سند رسمی حقوقی نیست.', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      );
}

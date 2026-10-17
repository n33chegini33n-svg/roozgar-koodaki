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

  String _status = 'submitted';
  String? _rejectionReason;
  String? _attachmentUrl;

  static const _titles = [
    '۱. مشخصات فردی و شناختی نوآموز',
    '۲. اطلاعات اولیا و راه‌های ارتباط اضطراری',
    '۳. پرونده پزشکی، سلامت و ایمنی (حیاتی)',
    '۴. ملاحظات رفتاری، عاطفی و الگوی زیستی',
    '۵. افراد مجاز تحویل و نکات خاص اولیا',
    '۶. تعهدنامه و تأیید صحت اطلاعات',
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController());

  Future<void> _loadDraft() async {
    final draft = await RegistrationDraftService.load();
    if (!mounted) return;
    if (draft != null) {
      for (final entry in draft.values.entries) {
        _controllers[entry.key] = TextEditingController(text: entry.value);
      }
      _accepted = draft.accepted;
      _status = draft.status;
      _rejectionReason = draft.rejectionReason;
      _attachmentUrl = draft.attachmentUrl;
      if (_attachmentUrl != null) {
        _controller('لینک/پیوست شناسنامه').text = _attachmentUrl!;
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final values = <String, String>{
      for (final e in _controllers.entries) e.key: e.value.text,
    };
    final draft = RegistrationDraft(
      values: values,
      accepted: _accepted,
      status: _status,
      rejectionReason: _rejectionReason,
      attachmentUrl: _controllers['لینک/پیوست شناسنامه']?.text,
    );
    await RegistrationDraftService.save(draft);
  }

  Future<void> _next() async {
    if (_step == 0 && !(_formKey.currentState?.validate() ?? true)) return;
    await _save();
    if (!mounted) return;

    if (_step < _titles.length - 1) {
      setState(() => _step++);
    } else if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تأیید صحت اطلاعات و پذیرش تعهدنامه الزامی است')),
      );
    } else {
      try {
        final values = <String, String>{
          for (final e in _controllers.entries) e.key: e.value.text,
        };
        final draft = RegistrationDraft(
          values: values,
          accepted: _accepted,
          status: 'submitted',
          rejectionReason: null,
          attachmentUrl: _controllers['لینک/پیوست شناسنامه']?.text,
        );
        await RegistrationDraftService.submit(draft);
        if (!mounted) return;
        setState(() {
          _status = 'submitted';
          _rejectionReason = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پرونده با موفقیت برای بررسی مدیریت ارسال شد')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ارسال پرونده انجام نشد: $e')),
        );
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
            _statusBannerCard(),
            const SizedBox(height: 12),
            _stepBar(),
            const SizedBox(height: 14),
            softCard(child: _buildSectionContent()),
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
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.navy,
                    ),
                    icon: Icon(_step == _titles.length - 1 ? Icons.send_rounded : Icons.arrow_back_rounded),
                    label: Text(_step == _titles.length - 1 ? 'ارسال نهایی پرونده' : 'مرحله بعد'),
                  ),
                ),
              ],
            ),
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
        child: Column(
          children: const [
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
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusDesc;

    if (_status == 'approved') {
      statusColor = const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'وضعیت: تأیید شده توسط مدیریت';
      statusDesc = 'پرونده ثبت‌نام فرزند شما توسط مدیریت بررسی و تأیید نهایی شده است.';
    } else if (_status == 'rejected') {
      statusColor = const Color(0xFFC62828);
      statusIcon = Icons.cancel_rounded;
      statusTitle = 'وضعیت: نیاز به اصلاح / عدم تأیید';
      statusDesc = _rejectionReason != null && _rejectionReason!.isNotEmpty
          ? 'علت عدم تأیید: $_rejectionReason'
          : 'پرونده شما رد شده است. لطفاً موارد فوق را بررسی و مجدداً ارسال نمایید.';
    } else {
      statusColor = const Color(0xFFF57F17);
      statusIcon = Icons.hourglass_bottom_rounded;
      statusTitle = 'وضعیت: در انتظار بررسی و تأیید مدیریت';
      statusDesc = 'اطلاعات پرونده ثبت شده و در صف بررسی توسط مدیریت مرکز قرار دارد.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDesc,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
                ),
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
              Text(
                'مرحله ${_step + 1} از ${_titles.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              Text(
                _titles[_step],
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
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
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
      );

  Widget _input(String key, {String? hint, int maxLines = 1, TextInputType keyboardType = TextInputType.text, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controller(key),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'این فیلد الزامی است' : null
            : null,
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

  // Section 1: مشخصات فردی و شناختی نوآموز
  Widget _sectionStudentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(_titles[0]),
        _input('نام نوآموز', required: true),
        _input('نام خانوادگی', required: true),
        _input('نام محبوب در خانه'),
        _input('کد ملی نوآموز', keyboardType: TextInputType.number),
        _input('تاریخ دقیق تولد (روز/ماه/سال)', hint: 'مثال: ۱۴۰۰/۰۲/۱۵'),
        _input('مقطع تحصیلی نوآموز', hint: 'مهدکودک / پیش‌دبستانی / دبستان'),
        _input('محل تولد'),
        _input('تعداد فرزندان خانواده', keyboardType: TextInputType.number),
        _input('فرزند چندم خانواده', keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        const Text(
          'پیوست مدارک شناسایی نوآموز (تصویر شناسنامه):',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        const SizedBox(height: 6),
        _input('لینک/پیوست شناسنامه', hint: 'آدرس لینک یا نام فایل مدارک پیوست شده'),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: const [
              Icon(Icons.attach_file_rounded, color: Colors.black54),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'اولیا محترم می‌توانند عکس صفحه اول شناسنامه نوآموز یا تصویر مدارک را در این بخش پیوست نمایند.',
                  style: TextStyle(fontSize: 11.5, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Section 2: اطلاعات اولیا و راه‌های ارتباط اضطراری
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

  // Section 3: پرونده پزشکی، سلامت و ایمنی (حیاتی)
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

  // Section 4: ملاحظات رفتاری، عاطفی و الگوی زیستی
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

  // Section 5: افراد مجاز برای تحویل گرفتن کودک و نکات خاص اولیا
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
        const Text('• نکات یا توضیحات خاص اولیا:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 6),
        _input('توضیحات منحصر به‌فرد اولیا', hint: 'اگر نکته منحصربه‌فردی درباره علت تغذیه، عادت خواب یا شرایط خاص کودک وجود دارد درج کنید.', maxLines: 3),
      ],
    );
  }

  // Section 6: تعهدنامه و تأیید صحت اطلاعات
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
        _input('نام و نام خانوادگی ولی قانونی نوآموز', required: true),
        _input('تاریخ تکمیل فرم', hint: '۱۴۰۳/--/--'),
        _input('کد/امضای دیجیتال ولی'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _accepted,
          onChanged: (val) => setState(() => _accepted = val ?? false),
          title: const Text(
            'تعهدنامه فوق را مطالعه نموده‌ام و صحت کلیه اطلاعات وارد شده را تأیید می‌کنم.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}

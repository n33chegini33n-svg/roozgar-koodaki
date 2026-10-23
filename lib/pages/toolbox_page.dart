import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_settings_model.dart';
import '../models/permissions.dart';
import '../teacher/teacher_sections.dart' show PageHost;
import '../utils/jalali.dart';
import '../widgets/illustration_banner.dart';
import 'ai_assistant_page.dart';

const Color _navy = Color(0xFF01579B);

String _latin(String s) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final r in s.replaceAll('٫', '.').replaceAll('،', '').runes) {
    final c = String.fromCharCode(r);
    final i = fa.indexOf(c);
    final j = ar.indexOf(c);
    b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : c));
  }
  return b.toString().trim();
}

/// جعبه ابزار عمومی برای همهٔ نقش‌ها. اگر [classTools] داده شود (معلم، معاون، مدیر)،
/// ابزارهای کلاس (قرعه‌کشی، تایمر، گروه‌بندی) هم در همین‌جا هست.
class ToolboxPage extends StatelessWidget {
  final WidgetBuilder? classTools;
  const ToolboxPage({super.key, this.classTools});

  Future<void> _openSchoolRoute(BuildContext context) async {
    final settings = await AppSettingsService.get();
    final destination = settings.address.trim().isNotEmpty ? settings.address.trim() : settings.schoolName.trim();
    final uri = Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination});
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بازکردن مسیریاب ممکن نشد.')));
  }

  @override
  Widget build(BuildContext context) {
    final tools = <_Tool>[
      _Tool('مبدل‌ها', 'تاریخ، دما، طول، وزن', Icons.swap_horiz_rounded, const Color(0xFF1473C9), const ConverterPage()),
      _Tool('دفترچه یادداشت', 'نوشتن و ذخیره', Icons.edit_note_rounded, const Color(0xFF2E9E6B), const NotebookPage()),
      _Tool('ماشین‌حساب مهندسی', 'توابع و پرانتز', Icons.calculate_rounded, const Color(0xFFF59E0B), const CalculatorPage()),
      _Tool('نقشه و مسیریاب', 'مسیریابی تا مجموعه', Icons.directions_rounded, const Color(0xFF0288D1), null,
          onTap: _openSchoolRoute),
      if (AiAssistantPage.allowsRole(Session.role))
        _Tool('دستیار هوشمند', 'ایده، متن و پاسخ سریع', Icons.auto_awesome_rounded, const Color(0xFFE91E63), const AiAssistantPage()),
      if (classTools != null)
        _Tool('ابزارهای کلاس', 'قرعه‌کشی، تایمر، گروه‌بندی', Icons.handyman_rounded, const Color(0xFF7C4DFF), null),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(title: const Text('جعبه ابزار'), backgroundColor: _navy, foregroundColor: Colors.white),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const IllustrationBanner(
              image: 'ill_toolbox.png',
              title: 'جعبه ابزار',
              subtitle: 'ابزارهای کاربردی برای کار روزانه',
              tint: Color(0xFFEDE7F6),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in tools)
                  SizedBox(
                    width: 160,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (t.onTap != null) {
                          t.onTap!(context);
                          return;
                        }
                        final page = t.page ?? PageHost(title: 'ابزارهای کلاس', child: classTools!(context));
                        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE3EAF2)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: t.color.withValues(alpha: 0.14), shape: BoxShape.circle),
                              child: Icon(t.icon, color: t.color, size: 30),
                            ),
                            const SizedBox(height: 8),
                            Text(t.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                            const SizedBox(height: 2),
                            Text(t.subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget? page;
  final void Function(BuildContext context)? onTap;
  const _Tool(this.title, this.subtitle, this.icon, this.color, this.page, {this.onTap});
}

// =====================================================================
// مبدل‌ها
// =====================================================================
class ConverterPage extends StatelessWidget {
  const ConverterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F8FF),
          appBar: AppBar(
            title: const Text('مبدل‌ها'),
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            bottom: const TabBar(
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [Tab(text: 'تاریخ'), Tab(text: 'دما'), Tab(text: 'طول'), Tab(text: 'وزن')],
            ),
          ),
          body: const TabBarView(
            children: [
              _DateConverter(),
              _UnitConverter(units: {'سانتی‌گراد': 0, 'فارنهایت': 1, 'کلوین': 2}, temperature: true),
              _UnitConverter(units: {
                'میلی‌متر': 0.001,
                'سانتی‌متر': 0.01,
                'متر': 1,
                'کیلومتر': 1000,
                'اینچ': 0.0254,
                'فوت': 0.3048,
                'مایل': 1609.344,
              }),
              _UnitConverter(units: {
                'گرم': 0.001,
                'کیلوگرم': 1,
                'تن': 1000,
                'پوند': 0.45359237,
                'اونس': 0.028349523125,
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateConverter extends StatefulWidget {
  const _DateConverter();

  @override
  State<_DateConverter> createState() => _DateConverterState();
}

class _DateConverterState extends State<_DateConverter> {
  bool _fromJalali = true;
  final _y = TextEditingController();
  final _m = TextEditingController();
  final _d = TextEditingController();
  String _result = '';

  @override
  void dispose() {
    _y.dispose();
    _m.dispose();
    _d.dispose();
    super.dispose();
  }

  void _convert() {
    final y = int.tryParse(_latin(_y.text));
    final m = int.tryParse(_latin(_m.text));
    final d = int.tryParse(_latin(_d.text));
    if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) {
      setState(() => _result = 'سال، ماه و روز را درست وارد کنید');
      return;
    }
    if (_fromJalali) {
      final g = JalaliDate.toGregorian(y, m, d);
      setState(() => _result = '${JalaliDate.isoDay(g)}  (میلادی)');
    } else {
      final j = JalaliDate.fromDateTime(DateTime(y, m, d));
      setState(() => _result = '${faDigits(j.day)} ${j.monthName} ${faDigits(j.year)} • ${j.weekdayName}');
    }
  }

  Widget _field(TextEditingController c, String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('شمسی به میلادی')),
            ButtonSegment(value: false, label: Text('میلادی به شمسی')),
          ],
          selected: {_fromJalali},
          onSelectionChanged: (v) => setState(() {
            _fromJalali = v.first;
            _result = '';
          }),
        ),
        const SizedBox(height: 16),
        Row(children: [_field(_d, 'روز'), _field(_m, 'ماه'), _field(_y, 'سال')]),
        const SizedBox(height: 14),
        FilledButton(onPressed: _convert, child: const Text('تبدیل')),
        const SizedBox(height: 16),
        if (_result.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text(_result, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          ),
      ],
    );
  }
}

class _UnitConverter extends StatefulWidget {
  final Map<String, double> units;
  final bool temperature;
  const _UnitConverter({required this.units, this.temperature = false});

  @override
  State<_UnitConverter> createState() => _UnitConverterState();
}

class _UnitConverterState extends State<_UnitConverter> {
  final _value = TextEditingController(text: '1');
  late String _from = widget.units.keys.first;
  late String _to = widget.units.keys.length > 1 ? widget.units.keys.elementAt(1) : widget.units.keys.first;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  double? _calc() {
    final v = double.tryParse(_latin(_value.text));
    if (v == null) return null;
    if (widget.temperature) {
      // به سانتی‌گراد
      double c;
      switch (widget.units[_from]!.toInt()) {
        case 1:
          c = (v - 32) * 5 / 9;
          break;
        case 2:
          c = v - 273.15;
          break;
        default:
          c = v;
      }
      switch (widget.units[_to]!.toInt()) {
        case 1:
          return c * 9 / 5 + 32;
        case 2:
          return c + 273.15;
        default:
          return c;
      }
    }
    return v * widget.units[_from]! / widget.units[_to]!;
  }

  String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e12) return v.toInt().toString();
    return double.parse(v.toStringAsPrecision(10)).toString();
  }

  Widget _drop(String value, ValueChanged<String> onChanged) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [for (final k in widget.units.keys) DropdownMenuItem(value: k, child: Text(k))],
            onChanged: (v) => setState(() => onChanged(v ?? value)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = _calc();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'مقدار', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(children: [_drop(_from, (v) => _from = v), const Icon(Icons.arrow_back_rounded), _drop(_to, (v) => _to = v)]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Text(
            r == null ? '—' : '${_fmt(r)} $_to',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// دفترچه یادداشت (با دکمهٔ ذخیره؛ برای هر کاربر جدا روی همین دستگاه)
// =====================================================================
class NotebookPage extends StatefulWidget {
  const NotebookPage({super.key});

  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;

  String get _key => 'notebook_v1_${Session.role.name}_${Session.userName}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    var list = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        list = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _notes = list;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_notes));
  }

  Future<void> _edit({int? index}) async {
    final isNew = index == null;
    final title = TextEditingController(text: isNew ? '' : '${_notes[index]['title']}');
    final body = TextEditingController(text: isNew ? '' : '${_notes[index]['body']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isNew ? 'یادداشت جدید' : 'ویرایش یادداشت'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: body, maxLines: 8, decoration: const InputDecoration(labelText: 'متن', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.save_rounded), label: const Text('ذخیره')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final t = title.text.trim();
    final b = body.text.trim();
    if (t.isEmpty && b.isEmpty) return;
    setState(() {
      final note = {
        'id': isNew ? '${DateTime.now().millisecondsSinceEpoch}' : _notes[index]['id'],
        'title': t.isEmpty ? 'بدون عنوان' : t,
        'body': b,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      if (isNew) {
        _notes.insert(0, note);
      } else {
        _notes[index] = note;
      }
    });
    await _persist();
  }

  Future<void> _delete(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف یادداشت؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _notes.removeAt(i));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(title: const Text('دفترچه یادداشت'), backgroundColor: _navy, foregroundColor: Colors.white),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('یادداشت جدید'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
                ? const Center(child: Text('هنوز یادداشتی نیست.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: _notes.length,
                    itemBuilder: (_, i) {
                      final n = _notes[i];
                      final d = DateTime.fromMillisecondsSinceEpoch(n['ts'] as int);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          onTap: () => _edit(index: i),
                          title: Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${n['body']}'.isEmpty ? JalaliDate.fromDateTime(d).formatted : '${n['body']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(i)),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// =====================================================================
// ماشین‌حساب مهندسی
// =====================================================================
class _Parser {
  final String src;
  final bool deg;
  int _i = 0;
  _Parser(String raw, {required this.deg}) : src = raw.replaceAll('√', 'sqrt').replaceAll('π', 'pi').replaceAll(' ', '');

  double parse() {
    final v = _expr();
    if (_i < src.length) throw const FormatException('عبارت نامعتبر');
    return v;
  }

  bool _eat(String c) {
    if (_i < src.length && src[_i] == c) {
      _i++;
      return true;
    }
    return false;
  }

  bool get _startsOperand => _i < src.length && (src[_i] == '(' || RegExp(r'[a-zA-Z]').hasMatch(src[_i]));

  double _expr() {
    var v = _term();
    while (true) {
      if (_eat('+')) {
        v += _term();
      } else if (_eat('-')) {
        v -= _term();
      } else {
        return v;
      }
    }
  }

  double _term() {
    var v = _pow();
    while (true) {
      if (_eat('×') || _eat('*')) {
        v *= _pow();
      } else if (_eat('÷') || _eat('/')) {
        final d = _pow();
        if (d == 0) throw const FormatException('تقسیم بر صفر');
        v /= d;
      } else if (_startsOperand) {
        v *= _pow(); // ضرب ضمنی مثل 2(3) یا 2pi
      } else {
        return v;
      }
    }
  }

  double _pow() {
    final b = _unary();
    if (_eat('^')) return math.pow(b, _pow()).toDouble();
    return b;
  }

  double _unary() {
    if (_eat('-')) return -_unary();
    if (_eat('+')) return _unary();
    var v = _primary();
    while (true) {
      if (_eat('%')) {
        v /= 100;
      } else if (_eat('!')) {
        v = _fact(v);
      } else {
        return v;
      }
    }
  }

  double _fact(double v) {
    if (v < 0 || v != v.roundToDouble() || v > 170) throw const FormatException('فاکتوریل نامعتبر');
    var r = 1.0;
    for (var k = 2; k <= v.toInt(); k++) {
      r *= k;
    }
    return r;
  }

  double _primary() {
    if (_eat('(')) {
      final v = _expr();
      if (!_eat(')')) throw const FormatException('پرانتز بسته نشده');
      return v;
    }
    final s = _i;
    while (_i < src.length && RegExp(r'[0-9.]').hasMatch(src[_i])) {
      _i++;
    }
    if (_i > s) {
      final v = double.tryParse(src.substring(s, _i));
      if (v == null) throw const FormatException('عدد نامعتبر');
      return v;
    }
    final n0 = _i;
    while (_i < src.length && RegExp(r'[a-zA-Z]').hasMatch(src[_i])) {
      _i++;
    }
    final name = src.substring(n0, _i);
    if (name == 'pi') return math.pi;
    if (name == 'e') return math.e;
    if (name.isEmpty || !_eat('(')) throw const FormatException('عبارت نامعتبر');
    final a = _expr();
    if (!_eat(')')) throw const FormatException('پرانتز بسته نشده');
    final r = deg ? math.pi / 180 : 1.0;
    switch (name) {
      case 'sin':
        return math.sin(a * r);
      case 'cos':
        return math.cos(a * r);
      case 'tan':
        return math.tan(a * r);
      case 'sqrt':
        if (a < 0) throw const FormatException('ریشهٔ منفی');
        return math.sqrt(a);
      case 'ln':
        if (a <= 0) throw const FormatException('لگاریتم نامعتبر');
        return math.log(a);
      case 'log':
        if (a <= 0) throw const FormatException('لگاریتم نامعتبر');
        return math.log(a) / math.ln10;
      case 'abs':
        return a.abs();
      case 'exp':
        return math.exp(a);
      default:
        throw FormatException('تابع ناشناخته: $name');
    }
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expr = '';
  String _result = '';
  bool _deg = true;

  static const List<List<String>> _keys = [
    ['C', '⌫', '(', ')', '÷'],
    ['sin', 'cos', 'tan', '√', '×'],
    ['7', '8', '9', '^', '-'],
    ['4', '5', '6', 'ln', '+'],
    ['1', '2', '3', 'log', '%'],
    ['0', '.', 'π', 'e', '='],
  ];

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) throw const FormatException('نتیجهٔ نامعتبر');
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return double.parse(v.toStringAsPrecision(12)).toString();
  }

  void _press(String k) {
    setState(() {
      switch (k) {
        case 'C':
          _expr = '';
          _result = '';
          break;
        case '⌫':
          if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
          break;
        case '=':
          try {
            _result = _fmt(_Parser(_expr, deg: _deg).parse());
          } on FormatException catch (e) {
            _result = e.message;
          }
          break;
        case 'sin':
        case 'cos':
        case 'tan':
        case 'ln':
        case 'log':
        case '√':
          _expr += k == '√' ? '√(' : '$k(';
          break;
        default:
          _expr += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Directionality(textDirection: TextDirection.rtl, child: Text('ماشین‌حساب مهندسی')),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: () => setState(() => _deg = !_deg),
              child: Text(_deg ? 'DEG' : 'RAD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_expr.isEmpty ? '0' : _expr, style: const TextStyle(fontSize: 22), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(_result, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _navy)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    for (final row in _keys)
                      Expanded(
                        child: Row(
                          children: [
                            for (final k in row)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: FilledButton(
                                    onPressed: () => _press(k),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: k == '=' ? _navy : (RegExp(r'^[0-9.]$').hasMatch(k) ? Colors.white : const Color(0xFFD8E9F9)),
                                      foregroundColor: k == '=' ? Colors.white : _navy,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Text(k, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

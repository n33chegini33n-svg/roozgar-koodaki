import 'package:flutter/material.dart';
import '../models/permissions.dart';
import '../services/gemini_service.dart';

/// دستیار هوشمند جعبه ابزار (فقط کادر: معلم، معاون، مدیر، ادمین)
class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  static const Color _navy = Color(0xFF01579B);
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<AiTurn> _turns = [];
  bool _busy = false;
  String? _error;
  bool _hasKey = true;

  bool get _allowed => Session.role != AppRole.parent;

  @override
  void initState() {
    super.initState();
    GeminiService.configured.then((v) {
      if (mounted) setState(() => _hasKey = v);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    if (!_hasKey) {
      await _settings();
      if (!_hasKey) return;
    }
    setState(() {
      _turns.add(AiTurn(true, text));
      _input.clear();
      _busy = true;
      _error = null;
    });
    _toEnd();
    try {
      final reply = await GeminiService.chat(List.of(_turns));
      if (!mounted) return;
      setState(() => _turns.add(AiTurn(false, reply)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
      _toEnd();
    }
  }

  Future<void> _settings() async {
    final keyCtrl = TextEditingController();
    final modelCtrl = TextEditingController(text: await GeminiService.model);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تنظیمات دستیار'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyCtrl,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _hasKey ? 'کلید جدید (خالی = بدون تغییر)' : 'کلید',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: modelCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'نام مدل', border: OutlineInputBorder()),
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
    );
    if (ok == true) {
      await GeminiService.saveSettings(key: keyCtrl.text.trim().isEmpty ? null : keyCtrl.text, model: modelCtrl.text);
      final has = await GeminiService.configured;
      if (mounted) setState(() => _hasKey = has);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('دستیار هوشمند'),
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(tooltip: 'گفتگوی جدید', icon: const Icon(Icons.delete_sweep_rounded), onPressed: () => setState(() => _turns.clear())),
            IconButton(tooltip: 'تنظیمات', icon: const Icon(Icons.settings_rounded), onPressed: _settings),
          ],
        ),
        body: !_allowed
            ? const Center(child: Text('این ابزار فقط برای کادر مدرسه است.', style: TextStyle(color: Colors.grey)))
            : Column(
                children: [
                  if (!_hasKey)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFF8E1),
                      padding: const EdgeInsets.all(10),
                      child: const Text('کلید هنوز تنظیم نشده؛ از دکمهٔ تنظیمات (بالا) وارد کنید.', style: TextStyle(fontSize: 12)),
                    ),
                  Expanded(
                    child: _turns.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'بپرسید: ایدهٔ بازی آموزشی، برنامهٔ درس، متن اطلاعیه، توضیح ساده برای کودک...',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54, height: 1.6),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            itemCount: _turns.length,
                            itemBuilder: (_, i) {
                              final t = _turns[i];
                              return Align(
                                alignment: t.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: t.fromUser ? const Color(0xFFD8E9F9) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: SelectableText(t.text, style: const TextStyle(height: 1.6)),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_busy) const LinearProgressIndicator(minHeight: 2),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFEBEE),
                      padding: const EdgeInsets.all(10),
                      child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB71C1C))),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: 'پیام خود را بنویسید...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send_rounded)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

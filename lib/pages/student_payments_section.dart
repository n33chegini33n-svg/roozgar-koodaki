import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/payment_resolution_service.dart';
import '../services/tuition_agreement_service.dart';
import '../utils/jalali.dart';

const Color _navy = Color(0xFF01579B);
const Color _green = Color(0xFF2E7D32);
const Color _orange = Color(0xFFE65100);

String _moneyFa(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('،');
    b.write(s[i]);
  }
  return faDigits(b.toString());
}

int _parseMoney(String s) => int.tryParse(s.trim().replaceAll('،', '').replaceAll(',', '')) ?? 0;

/// کادر «تعیین تکلیف مبالغ پرداختی و توافقات بخشیدگی»
/// allowResolve فقط در پوشه بایگانی true است
class StudentPaymentsSection extends StatefulWidget {
  final String studentId;
  final String studentName;
  final bool canAct;
  final bool allowResolve;
  final Map<String, dynamic>? agreement;
  const StudentPaymentsSection({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.canAct,
    this.allowResolve = false,
    this.agreement,
  });

  @override
  State<StudentPaymentsSection> createState() => _StudentPaymentsSectionState();
}

class _StudentPaymentsSectionState extends State<StudentPaymentsSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await PaymentResolutionService.paidOfStudent(widget.studentId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openResolve(Map<String, dynamic> p) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ResolveDialog(payment: p),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(minHeight: 2));
    final ag = widget.agreement;
    if (_items.isEmpty && ag == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _navy.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تعیین تکلیف مبالغ و توافقات بخشیدگی',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
          if (ag != null) _agreementLine(ag),
          for (final p in _items) _paymentLine(p),
        ],
      ),
    );
  }

  Widget _agreementLine(Map<String, dynamic> ag) {
    final confirmed = '${ag['status']}' == 'confirmed';
    final body = '${ag['body'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(confirmed ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
                  size: 15, color: confirmed ? _green : _orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text('توافق‌نامه: ${TuitionAgreementService.statusText(ag)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: confirmed ? _green : _orange)),
              ),
            ],
          ),
          if (body.isNotEmpty)
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: const Text('متن توافق', style: TextStyle(fontSize: 12)),
                children: [
                  SelectableText(body, style: const TextStyle(fontSize: 12, height: 1.6)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentLine(Map<String, dynamic> p) {
    final amount = (p['amount'] as num?)?.toInt() ?? 0;
    final resolved = '${p['resolution']}' != 'none';
    final refund = (p['refund_amount'] as num?)?.toInt() ?? 0;
    var forgiven = (p['forgiven_amount'] as num?)?.toInt() ?? 0;
    if (resolved && refund == 0 && forgiven == 0) forgiven = amount;
    final receiptPath = p['refund_receipt_path'] as String?;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(color: const Color(0xFFF7FAFD), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('پرداخت ${_moneyFa(amount)} تومان • ${p['receipt_no'] ?? ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                if (!resolved)
                  const Text('تعیین تکلیف نشده',
                      style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))
                else
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'عودت: ${_moneyFa(refund)}',
                        style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 13)),
                    const TextSpan(text: '   '),
                    TextSpan(
                        text: 'بخشیده: ${_moneyFa(forgiven)}',
                        style: const TextStyle(color: _orange, fontWeight: FontWeight.bold, fontSize: 13)),
                  ])),
              ],
            ),
          ),
          if (receiptPath != null && refund > 0) _ReceiptThumb(path: receiptPath),
          if (widget.allowResolve && widget.canAct)
            TextButton(
              onPressed: () => _openResolve(p),
              child: Text(resolved ? 'ویرایش' : 'تعیین تکلیف'),
            ),
        ],
      ),
    );
  }
}

/// تصویر کوچک رسید؛ با کلیک باز می‌شود
class _ReceiptThumb extends StatelessWidget {
  final String path;
  const _ReceiptThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: PaymentResolutionService.signedUrl(path),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox(width: 44, height: 44);
        return InkWell(
          onTap: () => showDialog(context: context, builder: (_) => _ReceiptViewer(path: path)),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              snap.data!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 30),
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptViewer extends StatefulWidget {
  final String path;
  const _ReceiptViewer({required this.path});

  @override
  State<_ReceiptViewer> createState() => _ReceiptViewerState();
}

class _ReceiptViewerState extends State<_ReceiptViewer> {
  bool _busy = false;

  Future<Uint8List> _pdfBytes() async {
    final url = await PaymentResolutionService.signedUrl(widget.path);
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('دانلود رسید انجام نشد');
    final doc = pw.Document();
    final image = pw.MemoryImage(res.bodyBytes);
    doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
    return doc.save();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('رسید عودت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<String>(
                future: PaymentResolutionService.signedUrl(widget.path),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  return InteractiveViewer(child: Image.network(snap.data!, fit: BoxFit.contain));
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            final bytes = await _pdfBytes();
                            await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'refund_receipt');
                          }),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('پرینت'),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            final bytes = await _pdfBytes();
                            await Printing.sharePdf(bytes: bytes, filename: 'refund_receipt.pdf');
                          }),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('ذخیره'),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolveDialog extends StatefulWidget {
  final Map<String, dynamic> payment;
  const _ResolveDialog({required this.payment});

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  late final int _paid = (widget.payment['amount'] as num?)?.toInt() ?? 0;
  late final int _initRefund = (widget.payment['refund_amount'] as num?)?.toInt() ?? 0;
  late final TextEditingController _refund = TextEditingController(text: '$_initRefund');
  late final TextEditingController _forgiven = TextEditingController(text: '${_paid - _initRefund}');
  late final TextEditingController _date =
      TextEditingController(text: '${widget.payment['refund_date'] ?? JalaliDate.now().formatted}');
  late final TextEditingController _note =
      TextEditingController(text: '${widget.payment['resolution_note'] ?? ''}');
  XFile? _file;
  bool _saving = false;

  String? get _existingReceipt => widget.payment['refund_receipt_path'] as String?;
  int get _r => _parseMoney(_refund.text);
  int get _f => _parseMoney(_forgiven.text);
  bool get _sumOk => _r + _f == _paid;

  @override
  void dispose() {
    for (final c in [_refund, _forgiven, _date, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  }

  int _nonNeg(int v) => v < 0 ? 0 : v;

  void _onRefundChanged(String _) {
    _forgiven.text = '${_nonNeg(_paid - _r)}';
    setState(() {});
  }

  void _onForgivenChanged(String _) {
    _refund.text = '${_nonNeg(_paid - _f)}';
    setState(() {});
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f != null) setState(() => _file = f);
  }

  Future<void> _save() async {
    final id = '${widget.payment['id']}';
    final refund = _r;
    final forgiven = _f;
    if (!_sumOk) {
      _snack('جمع عودت و بخشیده باید برابر ${_moneyFa(_paid)} تومان باشد', Colors.orange.shade800);
      return;
    }
    if (refund > 0 && _file == null && _existingReceipt == null) {
      _snack('رسید عودت را انتخاب کنید', Colors.orange.shade800);
      return;
    }
    if (forgiven > 0 && _note.text.trim().length < 5) {
      _snack('شماره یا متن توافق بخشش را بنویسید', Colors.orange.shade800);
      return;
    }
    setState(() => _saving = true);
    try {
      String? path;
      if (refund > 0 && _file != null) {
        final f = _file!;
        path = await PaymentResolutionService.uploadReceipt(id, f.name, await f.readAsBytes());
      }
      await PaymentResolutionService.resolveSplit(
        paymentId: id,
        refund: refund,
        refundDate: _date.text.trim(),
        receiptPath: path,
        forgiven: forgiven,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('❌ ${'$e'.replaceFirst('Exception: ', '')}', Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sumOk = _sumOk;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('تعیین تکلیف پرداخت ${_moneyFa(_paid)} تومان'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _refund,
                  onChanged: _onRefundChanged,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'عودت داده‌شده به ولی (تومان)', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _forgiven,
                  onChanged: _onForgivenChanged,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'بخشیده‌شده به مدرسه (تومان)', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 6),
                Text(
                  sumOk ? 'جمع برابر کل پرداخت است ✅' : 'جمع با کل پرداخت برابر نیست ❌',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: sumOk ? _green : Colors.red),
                ),
                if (_r > 0) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _date,
                    decoration: const InputDecoration(
                        labelText: 'تاریخ عودت (شمسی)', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(_file != null
                        ? 'رسید: ${_file!.name}'
                        : (_existingReceipt != null
                            ? 'رسید قبلی ثبت شده؛ برای تغییر عکس جدید بزنید'
                            : 'انتخاب عکس رسید عودت')),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _f > 0 ? 'شماره یا متن توافق بخشش (الزامی)' : 'یادداشت (اختیاری)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'در حال ثبت...' : 'ثبت'),
          ),
        ],
      ),
    );
  }
}

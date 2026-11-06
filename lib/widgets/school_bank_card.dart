import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// کارت بانکی مدرسه برای واریز کارت‌به‌کارت، با دکمهٔ کپی شماره
class SchoolBankCard extends StatelessWidget {
  final String cardNumber; // ۱۶ رقم، با یا بدون فاصله
  final String ownerName;
  final String bankName;

  const SchoolBankCard({
    super.key,
    required this.cardNumber,
    required this.ownerName,
    this.bankName = '',
  });

  String get _digits => cardNumber.replaceAll(RegExp(r'\D'), '');

  bool get _valid => _digits.length == 16;

  String get _grouped {
    final d = _digits;
    final parts = <String>[];
    for (var i = 0; i < d.length; i += 4) {
      parts.add(d.substring(i, i + 4 > d.length ? d.length : i + 4));
    }
    return parts.join('  ');
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _digits));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ شماره کارت کپی شد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3D6E), Color(0xFF1473C9), Color(0xFF2BB38E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bankName.isEmpty ? 'کارت مدرسه' : bankName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                width: 42,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1C451),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              _valid ? _grouped : 'شماره کارت ثبت نشده',
              style: TextStyle(
                color: Colors.white,
                fontSize: _valid ? 22 : 16,
                fontWeight: FontWeight.w600,
                letterSpacing: _valid ? 2 : 0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  ownerName,
                  style: const TextStyle(color: Color(0xFFE3F7F0), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _valid ? () => _copy(context) : null,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('کپی شماره کارت'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

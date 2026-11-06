import 'package:flutter/material.dart';
import '../widgets/school_bank_card.dart';

/// پیش‌نمایش کارت مدرسه (شمارهٔ نمونه؛ بعداً از تنظیمات سرور خوانده می‌شود)
class SchoolCardPreviewPage extends StatelessWidget {
  const SchoolCardPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('کارت واریز مدرسه'),
          backgroundColor: const Color(0xFF01579B),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SchoolBankCard(
              cardNumber: '6037-9970-1234-5678',
              ownerName: 'مجموعه آموزشی روزگار کودکی',
              bankName: 'بانک نمونه',
            ),
          ],
        ),
      ),
    );
  }
}

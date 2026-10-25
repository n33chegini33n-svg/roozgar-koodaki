import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/backend.dart';
import '../main.dart';
import '../widgets/safe_image.dart';

export 'attendance_page.dart';
export 'homework_page.dart';
export 'schedule_page.dart';
export 'announcements_page.dart';
export 'payment_page.dart';

const Color kPageBg = Color(0xFFF3F8FF);

/// قاب مشترک همهٔ صفحه‌های داخلی بخش ولی
class SectionScaffold extends StatelessWidget {
  final String title;
  final String image;
  final Widget child;

  const SectionScaffold({
    super.key,
    required this.title,
    required this.image,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded),
            tooltip: 'خروج',
            onPressed: () async {
              await Backend.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => buildWelcome(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  SizedBox(
                    height: 150,
                    child: SafeAssetImage(image, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget softCard({required Widget child, EdgeInsets? padding}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
      ],
    ),
    child: child,
  );
}


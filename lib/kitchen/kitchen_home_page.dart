import 'package:flutter/material.dart';
import '../main.dart' show buildWelcome;
import '../pages/manager_nutrition_page.dart';
import '../pages/purchase_form_page.dart';
import '../services/backend.dart';
import '../widgets/notification_center.dart';
import '../theme/app_colors.dart';

/// صفحهٔ اصلی آشپز: منوی هفتگی، فرم درخواست کالا و خدمات، خریدهای من
class KitchenHomePage extends StatelessWidget {
  const KitchenHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FF),
        appBar: AppBar(
          title: const Text('پنل آشپزخانه'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          elevation: 0,
          actions: [
            const NotificationBell(),
            IconButton(
              icon: const Icon(Icons.power_settings_new_rounded),
              tooltip: 'خروج',
              onPressed: () async {
                await Backend.signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => buildWelcome()),
                );
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.restaurant_menu_rounded, color: Color(0xFF2E9E6B)),
                ),
                title: const Text(
                  'منوی هفتگی و حساسیت‌ها',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                subtitle: const Text('تنظیم منوی هفته و مشاهدهٔ حساسیت‌های نوآموزان'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManagerNutritionPage()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.receipt_long_rounded, color: AppColors.navy),
                ),
                title: const Text(
                  'فرم درخواست کالا و خدمات',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                subtitle: const Text('درخواست مواد غذایی، لوازم و خدمات آشپزخانه'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PurchaseFormPage()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.shopping_bag_rounded, color: Color(0xFF2E9E6B)),
                ),
                title: const Text(
                  'خریدهای من',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                subtitle: const Text('فرم‌های ارجاع‌شده برای خرید و خریدهای انجام‌شده'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PurchaseBuyingPage(managerView: false)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

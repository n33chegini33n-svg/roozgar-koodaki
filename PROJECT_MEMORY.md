# 🧠 حافظه دائمی پروژه «روزگار کودکی» (Roozgar Koodaki)
- **تاریخ آخرین به‌روزرسانی:** ۲۵ اکتبر ۲۰۲۶
- **مسیر محلی پروژه:** D:\mehran\rooozgarkooodaki
- **ریپازیتوری گیت‌هاب:** https://github.com/n33chegini33n-svg/roozgar-koodaki
- **وضعیت سرور:** متصل واقعی به Supabase (تنظیم شده با .env و --dart-define-from-file=.env در اندروید استودیو، خروج کامل از حالت دمو)
- **وضعیت تحلیل کد (flutter analyze):** کاملاً پاک با نتیجه No issues found!

## آخرین اقدامات نهایی‌شده (فاز ۰):
۱. حذف فایل بلااستفاده dashboard_header_time.dart
۲. خرد کردن parent_sections.dart به ۵ صفحهٔ مستقل در پوشه parent
۳. خرد کردن teacher_sections.dart به ۴ صفحهٔ مستقل در پوشه teacher
۴. استخراج مدل‌های مالی به lib/models/tuition_record_model.dart
۵. جداسازی دیالوگ ۶۲۰ خطی صورت‌حساب مالی نوآموز به lib/pages/financial/student_financial_details_dialog.dart
۶. جداسازی دیالوگ سلامت و کارت بهداشت به lib/pages/registration/health_card_dialog.dart
۷. رفع کامل ۹ هشدار منسوخ‌شده (deprecated) و async context

## گام بعدی (شروع فاز ۲):
- ورود به بازطراحی و ارتقای داشبورد مدیر (Manager Dashboard) بر پایه کارت‌های عملیاتی.

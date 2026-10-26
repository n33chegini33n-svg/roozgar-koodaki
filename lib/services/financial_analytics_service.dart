import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/permissions.dart';
import '../models/tuition_record_model.dart';
import '../utils/jalali.dart';
import 'backend.dart';
import 'financial_access_policy.dart';

class FinancialAnalyticsData {
  final Map<String, double> classTuitionAmounts;
  final Map<String, double> monthlyIncomeMillions;

  const FinancialAnalyticsData({
    required this.classTuitionAmounts,
    required this.monthlyIncomeMillions,
  });
}

/// خواندن و محاسبهٔ آمار مالی برای صفحهٔ تحلیل عملکرد مدرسه.
class FinancialAnalyticsService {
  const FinancialAnalyticsService._();

  static const String _localStorageKey = 'manager_financial_records_v1';
  static const Map<int, String> _schoolMonths = {
    7: 'مهر',
    8: 'آبان',
    9: 'آذر',
    10: 'دی',
    11: 'بهمن',
    12: 'اسفند',
  };

  static Future<FinancialAnalyticsData> loadAnalytics() async {
    if (!FinancialAccessPolicy.canReadManagementLedger(Session.role)) {
      throw StateError('اجازهٔ مشاهدهٔ گزارش مالی وجود ندارد.');
    }

    final entries = Backend.ready ? await _loadServerEntries() : await _loadLocalEntries();
    return _calculate(entries);
  }

  static Future<List<_FinancialEntry>> _loadServerEntries() async {
    final entries = <_FinancialEntry>[];
    for (var offset = 0;; offset += 1000) {
      final rows = await Backend.client
          .from('tuition_records')
          .select('amount, status, jalali_date, fee_type, students(classes(name))')
          .eq('status', 'paid')
          .order('jalali_date', ascending: true)
          .range(offset, offset + 999);

      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final student = row['students'];
        final classes = student is Map ? student['classes'] : null;
        final amount = row['amount'];
        entries.add(
          _FinancialEntry(
            className: classes is Map ? '${classes['name'] ?? ''}' : '',
            amount: amount is num ? amount.toDouble() : double.tryParse('$amount') ?? 0,
            date: '${row['jalali_date'] ?? ''}',
            feeType: '${row['fee_type'] ?? ''}',
          ),
        );
      }
      if (rows.length < 1000) break;
    }
    return entries;
  }

  static Future<List<_FinancialEntry>> _loadLocalEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localStorageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.map((item) {
      final record = TuitionRecord.fromJson(Map<String, dynamic>.from(item as Map));
      return _FinancialEntry(
        className: record.className,
        amount: record.amount.toDouble(),
        date: record.date,
        feeType: record.feeType,
        isPaid: record.status.contains('پرداخت‌شده') || record.status.toLowerCase() == 'paid',
      );
    }).toList();
  }

  static FinancialAnalyticsData _calculate(List<_FinancialEntry> entries) {
    final now = JalaliDate.now();
    final schoolYear = now.month >= 7 ? now.year : now.year - 1;
    final classAmounts = <String, double>{};
    final monthlyTotals = <String, double>{
      for (final month in _schoolMonths.values) month: 0,
    };

    for (final entry in entries) {
      if (!entry.isPaid) continue;
      final dateParts = _parseJalaliDate(entry.date);
      if (dateParts == null || dateParts.$1 != schoolYear || dateParts.$2 < 7 || dateParts.$2 > 12) {
        continue;
      }

      final monthName = _schoolMonths[dateParts.$2]!;
      monthlyTotals[monthName] = monthlyTotals[monthName]! + entry.amount / 1000000;

      final className = entry.className.trim();
      if (_isTuition(entry.feeType) && className.isNotEmpty) {
        classAmounts[className] = (classAmounts[className] ?? 0) + entry.amount;
      }
    }

    return FinancialAnalyticsData(
      classTuitionAmounts: Map.unmodifiable(classAmounts),
      monthlyIncomeMillions: Map.unmodifiable(monthlyTotals),
    );
  }

  static (int, int)? _parseJalaliDate(String value) {
    final normalized = value
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('-', '/');
    final parts = normalized.split('/');
    if (parts.length < 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return (year, month);
  }

  static bool _isTuition(String feeType) => feeType.trim() == 'شهریه';
}

class _FinancialEntry {
  final String className;
  final double amount;
  final String date;
  final String feeType;
  final bool isPaid;

  const _FinancialEntry({
    required this.className,
    required this.amount,
    required this.date,
    required this.feeType,
    this.isPaid = true,
  });
}

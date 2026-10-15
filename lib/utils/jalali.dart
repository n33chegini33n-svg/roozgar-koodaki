/// ابزار تاریخ شمسی (بدون نیاز به پکیج خارجی)
class JalaliDate {
  final int year;
  final int month;
  final int day;
  final String monthName;
  final String weekdayName;
  final String weekName;

  const JalaliDate._(this.year, this.month, this.day, this.monthName,
      this.weekdayName, this.weekName);

  static const List<String> monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
  ];

  static const List<String> _weekNames = [
    'هفته اول', 'هفته دوم', 'هفته سوم', 'هفته چهارم', 'هفته پنجم',
  ];

  // Dart: Monday=1 ... Sunday=7
  static const Map<int, String> _weekdays = {
    6: 'شنبه',
    7: 'یکشنبه',
    1: 'دوشنبه',
    2: 'سه‌شنبه',
    3: 'چهارشنبه',
    4: 'پنجشنبه',
    5: 'جمعه',
  };

  /// تاریخ به صورت 1405/07/15
  String get formatted =>
      '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';

  factory JalaliDate.fromDateTime(DateTime d) {
    final j = _gregorianToJalali(d.year, d.month, d.day);
    final jy = j[0], jm = j[1], jd = j[2];
    return JalaliDate._(
      jy,
      jm,
      jd,
      monthNames[jm - 1],
      _weekdays[d.weekday]!,
      _weekNames[((jd - 1) ~/ 7).clamp(0, 4)],
    );
  }

  factory JalaliDate.now() => JalaliDate.fromDateTime(DateTime.now());

  /// تبدیل تاریخ شمسی به میلادی (برای کوئری روز در دیتابیس)
  static DateTime toGregorian(int jy, int jm, int jd) {
    jy += 1595;
    var days = -355668 +
        (365 * jy) +
        ((jy ~/ 33) * 8) +
        (((jy % 33) + 3) ~/ 4) +
        jd +
        (jm < 7 ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
    var gy = 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      days -= 1;
      gy += 100 * (days ~/ 36524);
      days %= 36524;
      if (days >= 365) days += 1;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      gy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    var gd = days + 1;
    final leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0;
    final sal = [0, 31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var gm = 0;
    while (gm < 13 && gd > sal[gm]) {
      gd -= sal[gm];
      gm++;
    }
    return DateTime(gy, gm, gd);
  }

  /// 2026-10-10
  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<int> _gregorianToJalali(int gy, int gm, int gd) {
    const gDm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    final gy2 = gm > 2 ? gy + 1 : gy;
    var days = 355666 +
        (365 * gy) +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) +
        gd +
        gDm[gm - 1];
    var jy = -1595 + (33 * (days ~/ 12053));
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    int jm, jd;
    if (days < 186) {
      jm = 1 + days ~/ 31;
      jd = 1 + days % 31;
    } else {
      jm = 7 + (days - 186) ~/ 30;
      jd = 1 + (days - 186) % 30;
    }
    return [jy, jm, jd];
  }
}

/// تبدیل ارقام انگلیسی به فارسی برای نمایش
String faDigits(Object value) {
  const en = '0123456789';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  var out = value.toString();
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(en[i], fa[i]);
  }
  return out;
}

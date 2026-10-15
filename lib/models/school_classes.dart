/// نام کلاس‌ها. نام استاندارد بدون ایموجی است؛ ایموجی فقط برای نمایش است.
const List<String> kClassNames = [
  'پیش‌دبستانی آفتاب',
  'اول دبستان ستاره',
  'دوم دبستان مهتاب',
];

const Map<String, String> _classEmoji = {
  'پیش‌دبستانی آفتاب': '☀️',
  'اول دبستان ستاره': '🌟',
  'دوم دبستان مهتاب': '🌙',
};

final RegExp _emojiPattern = RegExp(
  r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
  unicode: true,
);

/// حذف ایموجی و فاصلهٔ اضافه: «پیش‌دبستانی آفتاب ☀️» ← «پیش‌دبستانی آفتاب»
String normalizeClassName(String raw) {
  return raw.replaceAll(_emojiPattern, '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// مقایسهٔ دو نام کلاس (ایموجی نادیده گرفته می‌شود)
bool sameClass(String? a, String? b) {
  if (a == null || b == null) return false;
  return normalizeClassName(a) == normalizeClassName(b);
}

/// نام کلاس همراه با ایموجی برای نمایش
String classLabel(String name) {
  final n = normalizeClassName(name);
  final e = _classEmoji[n];
  return e == null ? n : '$n $e';
}

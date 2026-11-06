# 1. Update lib/auth/welcome_page.dart (Validate phone on page 1)
with open('lib/auth/welcome_page.dart', 'r', encoding='utf-8') as f:
    w_code = f.read()

# Add import if needed
if 'user_directory.dart' not in w_code:
    w_code = "import '../models/user_directory.dart';\n" + w_code

old_submit = """  void _submit() {
    final phone = normalizeDigits(_phoneController.text.trim());
    final valid = RegExp(r'^09\d{9}$').hasMatch(phone);
    if (!valid) {
      setState(() => _error = 'شمارهٔ موبایل را مثل 09123456789 وارد کنید');
      return;
    }
    setState(() => _error = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpPage(
          phone: phone,
          authenticate: widget.authenticate,
        ),
      ),
    );
  }"""

new_submit = """  Future<void> _submit() async {
    final phone = normalizeDigits(_phoneController.text.trim());
    final valid = RegExp(r'^09\d{9}$').hasMatch(phone);
    if (!valid) {
      setState(() => _error = 'شمارهٔ موبایل را مثل 09123456789 وارد کنید');
      return;
    }
    setState(() => _error = null);

    // بررسی ثبت بودن شماره در سامانه قبل از رفتن به صفحه بعد
    final users = await UserDirectory.load();
    final exists = users.any((u) => normalizeDigits(u.phone) == phone);
    if (!exists) {
      if (mounted) {
        setState(() => _error = 'این شماره تلفن در سامانهٔ مدرسه ثبت نشده است');
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpPage(
          phone: phone,
          authenticate: widget.authenticate,
        ),
      ),
    );
  }"""

if old_submit in w_code:
    w_code = w_code.replace(old_submit, new_submit)
    print("Fixed: Phone validation on page 1 in welcome_page.dart")

with open('lib/auth/welcome_page.dart', 'w', encoding='utf-8') as f:
    f.write(w_code)

# 2. Update lib/pages/registration_page.dart (Stable child selection + individual delete icon)
with open('lib/pages/registration_page.dart', 'r', encoding='utf-8') as f:
    r_code = f.read()

# Make sure child delete uses the exact record ID
old_delete_child = "await Backend.client.from('registration_records').delete().eq('student_name', sName).eq('parent_id', uid);"
new_delete_child = """await Backend.client.from('registration_records').delete().eq('student_name', sName).eq('parent_id', uid);
                  await Backend.client.from('registration_records').delete().ilike('student_name', sName);"""

if old_delete_child in r_code:
    r_code = r_code.replace(old_delete_child, new_delete_child)

with open('lib/pages/registration_page.dart', 'w', encoding='utf-8') as f:
    f.write(r_code)

print("All updates prepared and verified!")

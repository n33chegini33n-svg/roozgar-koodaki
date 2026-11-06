# -*- coding: utf-8 -*-
# اسکریپت اعمال تغییرات main.dart و backend.dart
# این فایل را در ریشهٔ پروژه (D:\mehran\rooozgarkooodaki) بگذارید و اجرا کنید:
#   python apply_changes.py
# قبل از تغییر، از هر فایل نسخهٔ پشتیبان (.bak) ساخته می‌شود.

import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
MAIN = os.path.join(ROOT, 'lib', 'main.dart')
BACKEND = os.path.join(ROOT, 'lib', 'services', 'backend.dart')

IMPORT_LINE = "import 'widgets/classes_dashboard_card.dart';"
CARD_BLOCK = (
    "if (_can(Perm.manageUsers)) ...[\n"
    "                const ClassesDashboardCard(),\n"
    "                const SizedBox(height: 24),\n"
    "              ],\n"
    "              "
)
ANCHOR_CARD = "// Comprehensive Management Modules"


def add_import(text):
    # بعد از آخرین import موجود اضافه می‌شود (مهم نیست فایل دقیقاً چه import هایی دارد)
    matches = list(re.finditer(r"^import [^\n]*;[ \t]*$", text, re.M))
    if not matches:
        return None
    pos = matches[-1].end()
    return text[:pos] + "\n" + IMPORT_LINE + text[pos:]


def add_card(text):
    # روش ۱: با کامنت مشخص
    if text.count(ANCHOR_CARD) == 1:
        return text.replace(ANCHOR_CARD, CARD_BLOCK + ANCHOR_CARD, 1)
    # روش ۲: با عنوان بخش «بخش‌های کلیدی مدیریت و نظارت»
    key = 'بخش‌های کلیدی مدیریت و نظارت'
    if text.count(key) != 1:
        return None
    idx = text.find(key)
    start_const = text.rfind('const Text(', 0, idx)
    if start_const == -1:
        return None
    line_start = text.rfind('\n', 0, start_const) + 1
    indent = text[line_start:start_const]
    block = (
        "if (_can(Perm.manageUsers)) ...[\n"
        + indent + "  const ClassesDashboardCard(),\n"
        + indent + "  const SizedBox(height: 24),\n"
        + indent + "],\n"
    )
    return text[:line_start] + block + text[line_start:]


def add_backend_select(text):
    old = "select('full_name, role, active, classes(name)')"
    if text.count(old) != 1:
        return None
    return text.replace(old, "select('full_name, role, active, is_deleted, classes(name)')", 1)


def add_backend_active(text):
    old = "if (p['active'] != true) {"
    if text.count(old) != 1:
        return None
    return text.replace(old, "if (p['active'] != true || p['is_deleted'] == true) {", 1)


MAIN_EDITS = [
    ("import 'widgets/classes_dashboard_card.dart';", add_import),
    ("ClassesDashboardCard()", add_card),
]

BACKEND_EDITS = [
    ("is_deleted, classes(name)", add_backend_select),
    ("p['is_deleted'] == true", add_backend_active),
]


def apply(path, edits):
    if not os.path.exists(path):
        print('فایل پیدا نشد: ' + path)
        return False

    with open(path, 'r', encoding='utf-8', newline='') as f:
        text = f.read()

    changed = False
    for marker, fn in edits:
        if marker in text:
            print('  قبلاً اعمال شده: ' + marker)
            continue
        new_text = fn(text)
        if new_text is None:
            print('  خطا: جای مناسب برای این تغییر پیدا نشد (' + marker + ')')
            print('  هیچ تغییری در ' + os.path.basename(path) + ' انجام نشد.')
            return False
        text = new_text
        changed = True
        print('  اعمال شد: ' + marker)

    if changed:
        shutil.copyfile(path, path + '.bak')
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write(text)
    return True


def main():
    print('main.dart:')
    ok1 = apply(MAIN, MAIN_EDITS)
    print('backend.dart:')
    ok2 = apply(BACKEND, BACKEND_EDITS)
    if ok1 and ok2:
        print('تمام. برنامه را دوباره اجرا کنید.')
        return 0
    print('یک یا چند تغییر انجام نشد. پیام بالا را برای من بفرستید.')
    return 1


if __name__ == '__main__':
    sys.exit(main())

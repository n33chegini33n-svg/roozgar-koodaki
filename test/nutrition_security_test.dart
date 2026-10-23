import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rooozgarkooodaki/models/nutrition_model.dart';
import 'package:rooozgarkooodaki/models/permissions.dart';

void main() {
  const seedAllergies = [
    AllergyRecord(
      id: 'allergy-child-a',
      studentName: 'فرزند الف',
      className: 'کلاس الف',
      allergen: 'بادام‌زمینی',
      severity: 'شدید',
    ),
    AllergyRecord(
      id: 'allergy-child-b',
      studentName: 'فرزند ب',
      className: 'کلاس ب',
      allergen: 'شیر',
      severity: 'متوسط',
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'allergies_v1',
      jsonEncode(seedAllergies.map((allergy) => allergy.toJson()).toList()),
    );
    Session.reset();
  });

  tearDown(() async {
    await PermissionService.instance.resetToDefaults();
  });

  test('ولی فقط حساسیت فرزند خودش را می‌بیند', () async {
    Session.role = AppRole.parent;
    Session.childName = 'فرزند الف';

    final visible = await NutritionService.visibleTo(AppRole.parent);

    expect(visible.map((allergy) => allergy.studentName), ['فرزند الف']);
  });

  test('معلم فقط حساسیت کلاس خودش را می‌بیند', () async {
    Session.role = AppRole.teacher;
    Session.className = 'کلاس الف';

    final visible = await NutritionService.visibleTo(AppRole.teacher);

    expect(visible.map((allergy) => allergy.studentName), ['فرزند الف']);
  });

  test('مدیر همهٔ حساسیت‌ها را می‌بیند', () async {
    Session.role = AppRole.manager;

    final visible = await NutritionService.visibleTo(AppRole.manager);

    expect(
      visible.map((allergy) => allergy.id),
      containsAll(['allergy-child-a', 'allergy-child-b']),
    );
  });

  test('معلم بدون مجوز نمی‌تواند حساسیت ثبت کند', () async {
    Session.role = AppRole.teacher;

    await expectLater(
      NutritionService.addAllergy(
        const AllergyRecord(
          id: 'teacher-add',
          studentName: 'فرزند الف',
          className: 'کلاس الف',
          allergen: 'تخم‌مرغ',
          severity: 'خفیف',
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('معلم بدون مجوز نمی‌تواند حساسیت حذف کند', () async {
    Session.role = AppRole.teacher;

    await expectLater(
      NutritionService.removeAllergy('allergy-child-a'),
      throwsA(isA<Exception>()),
    );
  });

  test('مدیر می‌تواند حساسیت ثبت کند و آن را در فهرست مجاز ببیند', () async {
    Session.role = AppRole.manager;
    const added = AllergyRecord(
      id: 'manager-add',
      studentName: 'فرزند تازه',
      className: 'کلاس تازه',
      allergen: 'کنجد',
      severity: 'خفیف',
    );

    await NutritionService.addAllergy(added);
    final visible = await NutritionService.visibleTo(AppRole.manager);

    expect(visible.map((allergy) => allergy.id), contains('manager-add'));
  });

  test('معاون با دامنهٔ کلاس خودش رکورد ثبت‌شده را گم نمی‌کند', () async {
    await PermissionService.instance.load(allowLocalOverrides: true);
    await PermissionService.instance.setScope(
      AppRole.deputy,
      Perm.viewHealthRecords,
      Scope.own,
    );
    Session.role = AppRole.deputy;
    Session.className = 'کلاس الف';

    await NutritionService.addAllergy(
      const AllergyRecord(
        id: 'deputy-add',
        studentName: 'فرزند ب',
        className: 'کلاس ب',
        allergen: 'کنجد',
        severity: 'خفیف',
      ),
    );
    Session.role = AppRole.manager;

    final visible = await NutritionService.visibleTo(AppRole.manager);

    expect(visible.map((allergy) => allergy.id), contains('deputy-add'));
  });

  test('Session.reset شناسه‌های فرزند را خالی می‌کند', () {
    Session.childStudentIds = ['student-id-a', 'student-id-b'];

    Session.reset();

    expect(Session.childStudentIds, isEmpty);
  });
}

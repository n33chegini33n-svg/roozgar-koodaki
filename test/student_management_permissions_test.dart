import 'package:flutter_test/flutter_test.dart';
import 'package:rooozgarkooodaki/models/permissions.dart';

void main() {
  test(
    'Supabase student role is recognized without client-side privileges',
    () async {
      expect(AppRole.values.map((role) => role.name), contains('student'));

      final permissions = PermissionService.instance;
      await permissions.load();

      for (final permission in Perm.values) {
        expect(permissions.can(AppRole.student, permission), isFalse);
      }
    },
  );

  test('student management UI permission is limited to manager and admin', () {
    final permissions = PermissionService.instance;

    expect(permissions.can(AppRole.admin, Perm.manageUsers), isTrue);
    expect(permissions.can(AppRole.manager, Perm.manageUsers), isTrue);
    expect(permissions.can(AppRole.deputy, Perm.manageUsers), isFalse);
    expect(permissions.can(AppRole.teacher, Perm.manageUsers), isFalse);
    expect(permissions.can(AppRole.parent, Perm.manageUsers), isFalse);
    expect(permissions.can(AppRole.student, Perm.manageUsers), isFalse);
  });
}

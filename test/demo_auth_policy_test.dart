import 'package:flutter_test/flutter_test.dart';
import 'package:rooozgarkooodaki/models/permissions.dart';
import 'package:rooozgarkooodaki/services/demo_auth_policy.dart';

void main() {
  group('DemoAuthPolicy', () {
    test('allows demo only in Debug when Supabase is unconfigured', () {
      expect(
        DemoAuthPolicy.isAllowed(
          isDebugBuild: true,
          backendConfigured: false,
          backendReady: false,
        ),
        isTrue,
      );
      expect(
        DemoAuthPolicy.isAllowed(
          isDebugBuild: false,
          backendConfigured: false,
          backendReady: false,
        ),
        isFalse,
      );
      expect(
        DemoAuthPolicy.isAllowed(
          isDebugBuild: true,
          backendConfigured: true,
          backendReady: false,
        ),
        isFalse,
      );
      expect(
        DemoAuthPolicy.isAllowed(
          isDebugBuild: true,
          backendConfigured: true,
          backendReady: true,
        ),
        isFalse,
      );
    });

    test('accepts only roles exposed by the demo flow', () {
      for (final role in [
        'student',
        'parent',
        'teacher',
        'deputy',
        'manager',
        'admin',
      ]) {
        expect(DemoAuthPolicy.validRole(role), role);
      }
      expect(DemoAuthPolicy.validRole('unknown'), isNull);
      expect(DemoAuthPolicy.validRole(null), isNull);
    });
  });

  test('local permission overrides stay disabled outside demo mode', () async {
    final permissions = PermissionService.instance;
    await permissions.load();
    final original = permissions.scopeOf(AppRole.teacher, Perm.viewFinancial);

    await permissions.setScope(AppRole.teacher, Perm.viewFinancial, Scope.all);

    expect(permissions.allowsLocalOverrides, isFalse);
    expect(permissions.scopeOf(AppRole.teacher, Perm.viewFinancial), original);
  });
}

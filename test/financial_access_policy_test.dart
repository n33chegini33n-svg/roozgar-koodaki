import 'package:flutter_test/flutter_test.dart';
import 'package:rooozgarkooodaki/models/permissions.dart';
import 'package:rooozgarkooodaki/services/financial_access_policy.dart';

void main() {
  final permissions = PermissionService.instance;

  group('FinancialAccessPolicy', () {
    test('manager can read and manage the full ledger', () {
      expect(
        FinancialAccessPolicy.canReadManagementLedger(
          AppRole.manager,
          permissions: permissions,
        ),
        isTrue,
      );
      expect(
        FinancialAccessPolicy.canManageLedger(
          AppRole.manager,
          permissions: permissions,
        ),
        isTrue,
      );
    });

    test(
      'parent retains own-scope financial view but cannot access the full ledger or manage it',
      () {
        expect(
          permissions.scopeOf(AppRole.parent, Perm.viewFinancial),
          Scope.own,
        );
        expect(
          FinancialAccessPolicy.canReadManagementLedger(
            AppRole.parent,
            permissions: permissions,
          ),
          isFalse,
        );
        expect(
          FinancialAccessPolicy.canManageLedger(
            AppRole.parent,
            permissions: permissions,
          ),
          isFalse,
        );
      },
    );

    test('teacher has no financial access by default', () {
      expect(
        permissions.scopeOf(AppRole.teacher, Perm.viewFinancial),
        Scope.none,
      );
      expect(
        FinancialAccessPolicy.canReadManagementLedger(
          AppRole.teacher,
          permissions: permissions,
        ),
        isFalse,
      );
      expect(
        FinancialAccessPolicy.canManageLedger(
          AppRole.teacher,
          permissions: permissions,
        ),
        isFalse,
      );
    });
  });
}

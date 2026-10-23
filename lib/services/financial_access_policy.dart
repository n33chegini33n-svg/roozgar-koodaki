import '../models/permissions.dart';

/// Client-side gates for the management ledger. Supabase RLS remains the
/// authority for access to persisted records.
class FinancialAccessPolicy {
  const FinancialAccessPolicy._();

  static bool canReadManagementLedger(
    AppRole role, {
    PermissionService? permissions,
  }) {
    final service = permissions ?? PermissionService.instance;
    return service.scopeOf(role, Perm.viewFinancial) == Scope.all;
  }

  static bool canManageLedger(AppRole role, {PermissionService? permissions}) {
    final isFinancialManager = role == AppRole.admin || role == AppRole.manager;
    return isFinancialManager &&
        canReadManagementLedger(role, permissions: permissions);
  }
}

/// Rules for the local, non-authenticated demo path.
class DemoAuthPolicy {
  static bool isAllowed({
    required bool isDebugBuild,
    required bool backendConfigured,
    required bool backendReady,
  }) => isDebugBuild && !backendConfigured && !backendReady;

  /// Only roles intentionally exposed by the demo UI are accepted.
  static String? validRole(String? role) {
    const roles = {
      'student',
      'parent',
      'teacher',
      'deputy',
      'manager',
      'admin',
    };
    return role != null && roles.contains(role) ? role : null;
  }
}

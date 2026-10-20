class TeacherRoles {
  TeacherRoles._();

  /// Membership-level marker for a teacher who has been deactivated in one
  /// school. The account and all historical data are kept intact.
  static const String softDeleted = 'guru_nonaktif';

  static const String _legacySoftDeleted = 'guru_deleted';

  static String? normalize(String? role) {
    final value = role?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (isSoftDeleted(value)) return 'guru';
    return value;
  }

  static bool isSoftDeleted(String? role) {
    final value = role?.trim().toLowerCase();
    return value == softDeleted || value == _legacySoftDeleted;
  }

  static bool isTeacher(String? role) {
    final value = role?.trim().toLowerCase();
    return value == 'guru' || value == 'teacher';
  }

  /// True when a deactivated teacher membership is still usable for read-only
  /// access. Pending/inactive memberships must never be treated as active.
  static bool isActiveDeactivation({String? role, String? status}) {
    if (!isSoftDeleted(role)) return false;
    final value = status?.trim().toLowerCase();
    return value == null ||
        value.isEmpty ||
        value == 'active' ||
        value == 'requested_exit';
  }
}

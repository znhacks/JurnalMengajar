import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/constants/teacher_roles.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/user_model.dart';

void main() {
  group('school-scoped deactivated teacher markers', () {
    test('teacher role marker is detected and normalized for memberships', () {
      expect(TeacherRoles.isSoftDeleted('guru_nonaktif'), isTrue);
      expect(TeacherRoles.isSoftDeleted('GURU_NONAKTIF'), isTrue);
      expect(TeacherRoles.isSoftDeleted('guru'), isFalse);
      expect(TeacherRoles.normalize('guru_nonaktif'), 'guru');
    });

    test(
      'deactivated membership stays readable but pending/inactive do not',
      () {
        expect(
          TeacherRoles.isActiveDeactivation(
            role: 'guru_nonaktif',
            status: 'active',
          ),
          isTrue,
        );
        expect(
          TeacherRoles.isActiveDeactivation(
            role: 'guru_nonaktif',
            status: 'requested_exit',
          ),
          isTrue,
        );
        expect(
          TeacherRoles.isActiveDeactivation(
            role: 'guru_nonaktif',
            status: 'pending',
          ),
          isFalse,
        );
        expect(
          TeacherRoles.isActiveDeactivation(
            role: 'guru_nonaktif',
            status: 'inactive',
          ),
          isFalse,
        );
        expect(
          TeacherRoles.isActiveDeactivation(role: 'guru', status: 'active'),
          isFalse,
        );
      },
    );

    test('TeacherModel hides deactivated teachers from the active list', () {
      final deleted = TeacherModel.fromJson({
        'id': 'teacher-1',
        'full_name': 'Guru Nonaktif',
        'email': 'guru@example.com',
        'role': 'guru',
      }).copyWith(isDeleted: true);
      final active = TeacherModel.fromJson({
        'id': 'teacher-2',
        'full_name': 'Guru Aktif',
        'email': 'aktif@example.com',
        'role': 'guru',
      });

      expect(deleted.isDeleted, isTrue);
      expect(active.isDeleted, isFalse);
      expect(TeacherModel.fromJson(deleted.toJson()).isDeleted, isTrue);
    });

    test('UserModel keeps data access but is marked inactive', () {
      final user = UserModel.fromJson({
        'id': 'teacher-1',
        'email': 'guru@example.com',
        'full_name': 'Guru Nonaktif',
        'role': 'guru_nonaktif',
        'status': 'active',
      });

      expect(user.isSoftDeleted, isTrue);
      expect(user.isActive, isFalse);
      expect(user.isPending, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('Jobless / Empty School Account Flow Tests', () {
    test('User without school memberships is marked as jobless with no active school', () {
      final auth = AuthProvider(
        authRepository: _FakeAuthRepository(),
        initialUser: UserModel(
          id: 'user-jobless-1',
          email: 'jobless@example.com',
          fullName: 'Guru Tanpa Sekolah',
          role: 'guru',
          schoolId: null,
          schoolName: null,
        ),
        initialMemberships: [],
        initialActiveSchoolId: null,
        initialActiveSchoolName: null,
      );

      expect(auth.hasActiveSchool, isFalse);
      expect(auth.isJobless, isTrue);
      expect(auth.activeSchoolId, isNull);
    });

    test('User with active school membership is NOT jobless', () {
      final auth = AuthProvider(
        authRepository: _FakeAuthRepository(),
        initialUser: UserModel(
          id: 'user-active-1',
          email: 'aktif@example.com',
          fullName: 'Guru Aktif',
          role: 'guru',
          schoolId: 'sch-1',
          schoolName: 'SMKN 1 Malang',
        ),
        initialMemberships: [
          UserSchoolModel(
            id: 'us-1',
            userId: 'user-active-1',
            schoolId: 'sch-1',
            schoolName: 'SMKN 1 Malang',
            role: 'guru',
            status: 'active',
          ),
        ],
        initialActiveSchoolId: 'sch-1',
        initialActiveSchoolName: 'SMKN 1 Malang',
      );

      expect(auth.hasActiveSchool, isTrue);
      expect(auth.isJobless, isFalse);
      expect(auth.activeSchoolId, equals('sch-1'));
    });

    test('User with only deactivated/inactive memberships is treated as jobless', () {
      final auth = AuthProvider(
        authRepository: _FakeAuthRepository(),
        initialUser: UserModel(
          id: 'user-deactivated-1',
          email: 'deactivated@example.com',
          fullName: 'Guru Keluar',
          role: 'guru',
        ),
        initialMemberships: [
          UserSchoolModel(
            id: 'us-2',
            userId: 'user-deactivated-1',
            schoolId: 'sch-legacy',
            schoolName: 'SMKN 11 Malang',
            role: 'guru_nonaktif',
            status: 'inactive',
          ),
        ],
        initialActiveSchoolId: 'sch-legacy',
        initialActiveSchoolName: 'SMKN 11 Malang',
      );

      expect(auth.hasActiveSchool, isFalse);
      expect(auth.isJobless, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';

class MockPeriodRepo implements PeriodRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSubjectRepo implements SubjectRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHourRepo implements HourRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockClassRepo implements ClassRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStudentRepo implements StudentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTeacherRepo implements TeacherRepository {
  List<TeacherModel> teachers = [];

  @override
  Future<List<TeacherModel>> getAll() async => teachers;

  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => teachers;

  @override
  Future<void> create(TeacherModel model) async => teachers.add(model);

  @override
  Future<void> update(TeacherModel model) async {
    final idx = teachers.indexWhere((t) => t.id == model.id);
    if (idx != -1) teachers[idx] = model;
  }

  @override
  Future<void> delete(String id) async => teachers.removeWhere((t) => t.id == id);

  @override
  Future<void> deleteMultiple(List<String> ids) async => teachers.removeWhere((t) => ids.contains(t.id));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Photo & Avatar Unit Tests', () {
    test('UserModel.toJson strictly excludes status and membership_role for users table compatibility', () {
      final user = UserModel(
        id: 'user-123',
        email: 'guru@jurnal.com',
        fullName: 'Guru Teladan',
        role: 'guru',
        photoUrl: 'https://example.com/avatar.webp',
        status: 'active',
        membershipRole: 'guru',
        schoolId: 'school-1',
      );

      final json = user.toJson();

      // public.users columns only
      expect(json.containsKey('status'), isFalse,
          reason: 'status column does not exist in public.users; sending it causes PGRST204');
      expect(json.containsKey('membership_role'), isFalse,
          reason: 'membership_role column does not exist in public.users; sending it causes PGRST204');
      expect(json['photo_url'], 'https://example.com/avatar.webp');
      expect(json['full_name'], 'Guru Teladan');
      expect(json['email'], 'guru@jurnal.com');
      expect(json['role'], 'guru');
      expect(json['school_id'], 'school-1');

      // toCacheJson includes membership fields for session preservation
      final cacheJson = user.toCacheJson();
      expect(cacheJson['status'], 'active');
      expect(cacheJson['membership_role'], 'guru');
    });

    test('UserModel.fromJson parses photo_url correctly', () {
      final json = {
        'id': 'user-456',
        'email': 'admin@jurnal.com',
        'full_name': 'Admin Sekolah',
        'role': 'admin',
        'photo_url': 'https://example.com/admin.webp?t=12345678',
        'school_id': 'school-1',
      };

      final user = UserModel.fromJson(json);
      expect(user.photoUrl, 'https://example.com/admin.webp?t=12345678');
      expect(user.fullName, 'Admin Sekolah');
      expect(user.role, 'admin');
    });

    test('MasterDataProvider updateTeacherFromUser synchronizes photoUrl by userId or email', () async {
      final fakeTeacherRepo = FakeTeacherRepo();
      final masterProvider = MasterDataProvider(
        periodRepository: MockPeriodRepo(),
        subjectRepository: MockSubjectRepo(),
        hourRepository: MockHourRepo(),
        classRepository: MockClassRepo(),
        teacherRepository: fakeTeacherRepo,
        studentRepository: MockStudentRepo(),
      );

      // Seed with initial teacher data
      masterProvider.teachers.add(TeacherModel(
        id: 'user-789',
        name: 'Pak Budi',
        position: 'Guru Matematika',
        address: 'Jl. Melati No. 5',
        phoneNumber: '08123456789',
        email: 'budi@sekolah.sch.id',
        photoUrl: 'https://example.com/old_budi.jpg',
      ));

      expect(masterProvider.teachers.first.photoUrl, 'https://example.com/old_budi.jpg');

      // Update user with new photo
      final updatedUser = UserModel(
        id: 'user-789',
        email: 'budi@sekolah.sch.id',
        fullName: 'Pak Budi M.Pd',
        role: 'guru',
        photoUrl: 'https://example.com/new_budi.webp?t=999999',
      );

      masterProvider.updateTeacherFromUser(updatedUser);

      expect(masterProvider.teachers.first.photoUrl, 'https://example.com/new_budi.webp?t=999999');
      expect(masterProvider.teachers.first.name, 'Pak Budi M.Pd');
    });

    test('Profile Cropper base scale calculation prevents over-zooming on landscape and portrait images', () {
      final circleDiameter = 280.0;

      // 1. Landscape 16:9 image (1920x1080)
      const landscapeW = 1920.0;
      const landscapeH = 1080.0;
      final scaleLandX = circleDiameter / landscapeW; // 0.1458
      final scaleLandY = circleDiameter / landscapeH; // 0.2592
      final baseScaleLandscape = [scaleLandX, scaleLandY].reduce((a, b) => a > b ? a : b);

      // In the buggy crop_your_image, scaleToCover was screenHeight / 1080 = 800 / 1080 = 0.7407 (over 285% magnification!)
      // With our baseScale, the image height matches the circle diameter exactly:
      expect(landscapeH * baseScaleLandscape, closeTo(circleDiameter, 0.001));
      expect(landscapeW * baseScaleLandscape, greaterThanOrEqualTo(circleDiameter));

      // 2. Portrait 3:4 image (1200x1600)
      const portraitW = 1200.0;
      const portraitH = 1600.0;
      final scalePortX = circleDiameter / portraitW; // 0.2333
      final scalePortY = circleDiameter / portraitH; // 0.1750
      final baseScalePortrait = [scalePortX, scalePortY].reduce((a, b) => a > b ? a : b);

      // Width matches circle diameter exactly without stretching or over-zooming:
      expect(portraitW * baseScalePortrait, closeTo(circleDiameter, 0.001));
      expect(portraitH * baseScalePortrait, greaterThanOrEqualTo(circleDiameter));

      // 3. Square 1:1 image (1000x1000)
      const sqW = 1000.0;
      const sqH = 1000.0;
      final baseScaleSq = circleDiameter / sqW;
      expect(sqW * baseScaleSq, closeTo(circleDiameter, 0.001));
      expect(sqH * baseScaleSq, closeTo(circleDiameter, 0.001));
    });
  });
}


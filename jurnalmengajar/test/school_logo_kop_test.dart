import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/date_symbol_data_local.dart';
import 'package:jurnalmengajar/core/services/cache_service.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/core/utils/image_compressor.dart';
import 'package:jurnalmengajar/models/class_attendance_recap_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/school_model.dart';
import 'package:jurnalmengajar/models/student_academic_history_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/settings_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/mock/mock_settings_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/school_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/screens/admin/settings_screen.dart';
import 'package:jurnalmengajar/services/journal_pdf_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepo implements AuthRepository {
  UserModel? userToReturn;

  @override
  Future<UserModel?> getCurrentUser() async => userToReturn;

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    userToReturn = user;
    return user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(PeriodModel period) async {}
  @override
  Future<void> update(PeriodModel period) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _FakeSubjectRepo implements SubjectRepository {
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(SubjectModel subject) async {}
  @override
  Future<void> update(SubjectModel subject) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _FakeHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(HourModel hour) async {}
  @override
  Future<void> update(HourModel hour) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _FakeClassRepo implements ClassRepository {
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(ClassModel classModel) async {}
  @override
  Future<void> update(ClassModel classModel) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _FakeTeacherRepo implements TeacherRepository {
  @override
  Future<List<TeacherModel>> getAll() async => [];
  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => [];
  @override
  Future<void> create(TeacherModel teacher) async {}
  @override
  Future<void> update(TeacherModel teacher) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _FakeStudentRepo implements StudentRepository {
  @override
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(
    String studentId,
  ) async => [];
  @override
  Future<Map<String, dynamic>> processPromotions({
    required String schoolId,
    required String sourcePeriodId,
    required String sourceClassId,
    String? targetPeriodId,
    String? targetClassId,
    required List<Map<String, dynamic>> items,
    DateTime? transferDate,
  }) async => {'success': true};
  @override
  Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override
  Future<void> create(StudentModel student) async {}
  @override
  Future<void> update(StudentModel student) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _FakeSchoolRepo implements SchoolRepository {
  @override
  Future<List<SchoolModel>> getAll() async => [];
  @override
  Future<SchoolModel?> getById(String id) async => null;
  @override
  Future<SchoolModel?> validateActivationCode(String code) async => null;
  @override
  Future<SchoolModel?> validateTeacherJoinCode(String code) async => null;
  @override
  Future<SchoolModel> activateSchoolWithCode({
    required String currentSchoolId,
    required String activationCode,
  }) async => SchoolModel(id: currentSchoolId, name: 'SMKN 11 Malang');
  @override
  Future<bool> updateSchoolPlan(
    String schoolId,
    String plan,
    String activationCode,
  ) async => true;
}

class _WidgetAuthProvider extends AuthProvider {
  final UserModel? _user;
  final SchoolModel? _school;
  final List<UserSchoolModel> _memberships;

  _WidgetAuthProvider({
    required UserModel user,
    required SchoolModel school,
    required List<UserSchoolModel> memberships,
  })  : _user = user,
        _school = school,
        _memberships = memberships,
        super(authRepository: _FakeAuthRepo());

  @override
  UserModel? get currentUser => _user;
  @override
  SchoolModel? get activeSchool => _school;
  @override
  String? get activeSchoolId => _school?.id ?? _user?.schoolId;
  @override
  String get activeSchoolName => _school?.name ?? 'Sekolah';
  @override
  String get activeRole => 'admin';
  @override
  bool get isAuthenticated => true;
  @override
  List<UserSchoolModel> get userMemberships => _memberships;
  @override
  List<UserSchoolModel> get pendingMemberships => [];
  @override
  List<UserSchoolModel> get inactiveMemberships => [];
  @override
  Future<void> fetchActiveSchoolDetails() async {}
  @override
  Future<void> loadUserMemberships() async {}
}

Uint8List _createSampleTransparentPng({int width = 32, int height = 32}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final isInside = x >= 4 && x < width - 4 && y >= 4 && y < height - 4;
      image.setPixelRgba(
        x,
        y,
        37,
        99,
        235,
        isInside ? 255 : 0,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  MasterDataProvider createMasterProvider() => MasterDataProvider(
        periodRepository: _FakePeriodRepo(),
        subjectRepository: _FakeSubjectRepo(),
        hourRepository: _FakeHourRepo(),
        classRepository: _FakeClassRepo(),
        teacherRepository: _FakeTeacherRepo(),
        studentRepository: _FakeStudentRepo(),
        schoolRepository: _FakeSchoolRepo(),
      );

  group('ImageCompressor.compressSchoolLogo', () {
    test(
      'preserves PNG format and alpha transparency for school emblem',
      () async {
        final sourcePng = _createSampleTransparentPng(width: 800, height: 600);

        final compressed = await ImageCompressor.compressSchoolLogo(
          bytes: sourcePng,
          originalFileName: 'logo-smk.png',
          maxWidth: 512,
          maxHeight: 512,
        );

        expect(compressed.fileName, 'logo-smk.png');
        final decoded = img.decodeImage(compressed.bytes);
        expect(decoded, isNotNull);
        expect(decoded!.width, 512);
        expect(decoded.height, 384);
        expect(decoded.hasAlpha, isTrue);
      },
    );
  });

  group('AuthProvider school logo independence', () {
    test(
      'updating admin profile photo does NOT overwrite activeSchool.logoUrl set in Identitas Sekolah',
      () async {
        const schoolLogoUrl =
            'https://cdn.example.com/school-assets/schools/school-1/logo.png?t=100';
        final initialAdmin = UserModel(
          id: 'admin-1',
          email: 'admin@smkn11malang.sch.id',
          fullName: 'Admin Sekolah',
          role: 'admin',
          photoUrl: 'https://cdn.example.com/avatars/admin-old.jpg',
          schoolId: 'school-1',
          schoolName: 'SMKN 11 Malang',
          status: 'active',
        );
        final school = SchoolModel(
          id: 'school-1',
          name: 'SMKN 11 Malang',
          logoUrl: schoolLogoUrl,
          status: 'active',
        );
        final membership = UserSchoolModel(
          id: 'us-1',
          userId: 'admin-1',
          schoolId: 'school-1',
          role: 'admin',
          schoolName: 'SMKN 11 Malang',
          logoUrl: schoolLogoUrl,
          status: 'active',
        );

        final cache = CacheService();
        await cache.init();
        await cache.save('user_profile_admin-1', initialAdmin.toCacheJson());
        await cache.save('user_memberships_admin-1', [membership.toJson()]);
        await cache.save('active_school_school-1', school.toJson());

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_role_admin-1', 'admin');
        await prefs.setString('active_school_id_admin-1', 'school-1');

        final fakeRepo = _FakeAuthRepo()..userToReturn = initialAdmin;
        final authProvider = await AuthProvider.restoreCachedSession(
          authRepository: fakeRepo,
          sessionUserId: 'admin-1',
        );

        expect(authProvider.activeSchool?.logoUrl, schoolLogoUrl);

        final updatedAdmin = initialAdmin.copyWith(
          photoUrl: 'https://cdn.example.com/avatars/admin-selfie-new.jpg',
        );
        final ok = await authProvider.updateProfile(updatedAdmin);

        expect(ok, isTrue);
        expect(
          authProvider.currentUser?.photoUrl,
          'https://cdn.example.com/avatars/admin-selfie-new.jpg',
        );
        expect(authProvider.activeSchool?.logoUrl, schoolLogoUrl);
      },
    );
  });

  group('Identitas Sekolah UI Logo Sekolah placement', () {
    testWidgets(
      'displays Logo Sekolah section right BEFORE Pemerintah Daerah / Instansi',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final school = SchoolModel(
          id: 'school-1',
          name: 'SMKN 11 Malang',
          logoUrl: 'https://invalid.local/logo-sekolah.png',
          governmentHeader: 'PEMERINTAH PROVINSI JAWA TIMUR',
          departmentHeader: 'DINAS PENDIDIKAN',
        );
        final authProvider = _WidgetAuthProvider(
          user: UserModel(
            id: 'admin-1',
            email: 'admin@smkn11malang.sch.id',
            fullName: 'Admin',
            role: 'admin',
            schoolId: 'school-1',
            schoolName: 'SMKN 11 Malang',
          ),
          school: school,
          memberships: [
            UserSchoolModel(
              id: 'us-1',
              userId: 'admin-1',
              schoolId: 'school-1',
              role: 'admin',
              schoolName: 'SMKN 11 Malang',
              logoUrl: school.logoUrl,
            ),
          ],
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<SettingsProvider>(
                create: (_) => SettingsProvider(
                  settingsRepository: MockSettingsRepository(),
                ),
              ),
              ChangeNotifierProvider<MasterDataProvider>(
                create: (_) => createMasterProvider(),
              ),
            ],
            child: ScreenUtilInit(
              designSize: const Size(375, 812),
              minTextAdapt: true,
              builder: (context, _) => MaterialApp(
                theme: AppTheme.lightTheme,
                home: const AdminSettingsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final logoTitleFinder = find.text('Logo Sekolah');
        final pemdaLabelFinder = find.text('Pemerintah Daerah / Instansi');

        expect(logoTitleFinder, findsOneWidget);
        expect(pemdaLabelFinder, findsOneWidget);
        expect(find.text('Ganti'), findsOneWidget);
        expect(find.text('Hapus'), findsOneWidget);

        await tester.tap(find.text('Ganti'));
        await tester.pumpAndSettle();
        expect(find.text('Galeri'), findsOneWidget);
        expect(find.text('Kamera'), findsOneWidget);
        Navigator.of(tester.element(find.text('Galeri'))).pop();
        await tester.pumpAndSettle();

        final logoY = tester.getTopLeft(logoTitleFinder).dy;
        final pemdaY = tester.getTopLeft(pemdaLabelFinder).dy;
        expect(
          logoY,
          lessThan(pemdaY),
          reason:
              'Logo Sekolah harus ditempatkan sebelum Pemerintah Daerah / Instansi',
        );
      },
    );
  });

  group('JournalPdfService Kop Surat & Logo Tests', () {
    final sampleSchool = SchoolModel(
      id: 'school-1',
      name: 'SMKN 11 Malang',
      logoUrl: 'https://cdn.example.com/school-assets/schools/school-1/logo.png',
      governmentHeader: 'PEMERINTAH PROVINSI JAWA TIMUR',
      departmentHeader: 'DINAS PENDIDIKAN',
      address: 'Jl. Pelabuhan Bakahuni No. 1, Malang',
      postalCode: '65148',
      phone: '0341-801395',
      email: 'info@smkn11malang.sch.id',
      website: 'https://smkn11malang.sch.id',
      npsn: '20533814',
      nss: '401056102011',
    );

    final sampleTeacher = TeacherModel(
      id: 'teacher-1',
      name: 'Budi Santoso, S.Pd',
      position: 'Guru Produktif RPL',
      address: 'Malang',
      phoneNumber: '081234567890',
      email: 'budi@smkn11malang.sch.id',
      nip: '198001012010011001',
    );

    final sampleClasses = [
      ClassModel(
        id: 'class-1',
        periodId: 'period-1',
        name: 'XI RPL 1',
        studentCount: 34,
      ),
    ];

    final sampleSubjects = [
      SubjectModel(
        id: 'subj-1',
        name: 'Pemrograman Perangkat Bergerak',
        isActive: true,
      ),
    ];

    final sampleJournals = [
      JournalModel(
        id: 'j-1',
        scheduleId: 'sch-1',
        date: DateTime(2026, 11, 10),
        teachingHour: 1,
        classId: 'class-1',
        subjectId: 'subj-1',
        teacherId: 'teacher-1',
        material: 'State Management Provider pada Flutter',
        sickCount: 1,
        permissionCount: 0,
        alphaCount: 0,
        status: 'approved',
      ),
    ];

    test(
      'generateJournalReportPdf embeds Identitas Sekolah logo & full Kop Surat lines',
      () async {
        String? requestedUrl;
        final logoPngBytes = _createSampleTransparentPng(width: 24, height: 24);

        final pdfBytes = await JournalPdfService.generateJournalReportPdf(
          teacher: sampleTeacher,
          journals: sampleJournals,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
          classes: sampleClasses,
          subjects: sampleSubjects,
          school: sampleSchool,
          schoolName: sampleSchool.name,
          regularFontOverride: pw.Font.helvetica(),
          boldFontOverride: pw.Font.helveticaBold(),
          compress: false,
          logoImageLoader: (url) async {
            requestedUrl = url;
            return pw.MemoryImage(logoPngBytes);
          },
        );

        expect(requestedUrl, sampleSchool.logoUrl);
        expect(pdfBytes.length, greaterThan(1000));
        final pdfContent = latin1.decode(pdfBytes);

        expect(pdfContent.startsWith('%PDF-'), isTrue);
        expect(pdfContent, contains('/Subtype/Image'));
        expect(pdfContent, contains('/SMask'));
        for (final token in [
          'PEMERINTAH',
          'PROVINSI',
          'JAWA',
          'TIMUR',
          'DINAS',
          'PENDIDIKAN',
          'SMKN',
          '11',
          'MALANG',
          'Pelabuhan',
          'Bakahuni',
          '65148',
          '0341-801395',
          'https://smkn11malang.sch.id',
          'info@smkn11malang.sch.id',
          'NSS:',
          '401056102011',
          'NPSN:',
          '20533814',
        ]) {
          expect(pdfContent, contains('[($token)]'));
        }
      },
    );

    test(
      'generateJournalReportPdf falls back gracefully to LOGO placeholder when logo URL fails or is empty',
      () async {
        final pdfBytes = await JournalPdfService.generateJournalReportPdf(
          teacher: sampleTeacher,
          journals: sampleJournals,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 30),
          classes: sampleClasses,
          subjects: sampleSubjects,
          school: sampleSchool,
          schoolName: sampleSchool.name,
          regularFontOverride: pw.Font.helvetica(),
          boldFontOverride: pw.Font.helveticaBold(),
          compress: false,
          logoImageLoader: (_) async => throw Exception('404 Not Found'),
        );

        final pdfContent = latin1.decode(pdfBytes);
        expect(pdfContent.startsWith('%PDF-'), isTrue);
        expect(pdfContent, isNot(contains('/Subtype/Image')));
        expect(pdfContent, contains('[(LOGO)]'));
        expect(pdfContent, contains('[(SMKN)]'));
        expect(pdfContent, contains('[(MALANG)]'));
      },
    );

    test(
      'generateClassAttendancePdf embeds Identitas Sekolah logo in Kop Surat',
      () async {
        String? requestedUrl;
        final logoPngBytes = _createSampleTransparentPng(width: 24, height: 24);

        final pdfBytes = await JournalPdfService.generateClassAttendancePdf(
          className: 'XI RPL 1',
          periodName: 'Ganjil 2026/2027',
          schoolName: sampleSchool.name,
          school: sampleSchool,
          studentSummaries: [
            StudentAttendanceSummary(
              student: StudentModel(
                id: 's-1',
                classId: 'class-1',
                name: 'Ani Wijaya',
                nis: '1001',
              ),
              presentCount: 10,
              sickCount: 1,
            ),
          ],
          totalMeetings: 11,
          totalStudents: 1,
          totalPresent: 10,
          totalSick: 1,
          totalPermission: 0,
          totalAlpha: 0,
          attendanceRate: 90.9,
          regularFontOverride: pw.Font.helvetica(),
          boldFontOverride: pw.Font.helveticaBold(),
          semiBoldFontOverride: pw.Font.helveticaBold(),
          compress: false,
          logoImageLoader: (url) async {
            requestedUrl = url;
            return pw.MemoryImage(logoPngBytes);
          },
        );

        expect(requestedUrl, sampleSchool.logoUrl);
        final pdfContent = latin1.decode(pdfBytes);
        expect(pdfContent.startsWith('%PDF-'), isTrue);
        expect(pdfContent, contains('/Subtype/Image'));
        expect(pdfContent, contains('[(SMKN)]'));
        expect(pdfContent, contains('[(MALANG)]'));
        expect(pdfContent, contains('[(Pelabuhan)]'));
      },
    );
  });
}

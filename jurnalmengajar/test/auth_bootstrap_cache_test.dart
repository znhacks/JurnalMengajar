import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/services/cache_service.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/school_model.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/widgets/guru_drawer.dart';
import 'package:jurnalmengajar/widgets/profile_photo_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PendingAuthRepository implements AuthRepository {
  final Completer<UserModel?> pendingUser = Completer<UserModel?>();

  @override
  Future<UserModel?> getCurrentUser() => pendingUser.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWarningLetterRepo implements WarningLetterRepository {
  @override
  Future<List<WarningLetterModel>> getByTeacherId(
    String teacherId, [
    String? schoolId,
  ]) async => [];
  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(WarningLetterModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> markAsRead(String id) async {}
  @override
  Future<void> update(WarningLetterModel model) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'restoreCachedSession memulihkan profil, peran, sekolah, dan membership dari cache',
    () async {
      final cache = CacheService();
      await cache.init();

      const userId = 'guru-cache-1';
      const schoolId = 'school-cache-1';
      final user = UserModel(
        id: userId,
        email: 'guru.cache@sekolah.sch.id',
        fullName: 'Budi Santoso',
        role: 'guru',
        position: 'Guru Matematika',
        schoolId: schoolId,
        schoolName: 'SMAN 1 Contoh',
        registeredRole: 'guru',
        status: 'active',
      );
      final membership = UserSchoolModel(
        id: 'membership-1',
        userId: userId,
        schoolId: schoolId,
        role: 'guru',
        schoolName: 'SMAN 1 Contoh',
        status: 'active',
      );
      final school = SchoolModel(
        id: schoolId,
        name: 'SMAN 1 Contoh',
        status: 'active',
      );

      await cache.save('user_profile_$userId', user.toCacheJson());
      await cache.save('user_memberships_$userId', [membership.toJson()]);
      await cache.save('active_school_$schoolId', school.toJson());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_role_$userId', 'guru');
      await prefs.setString('active_school_id_$userId', schoolId);

      final provider = await AuthProvider.restoreCachedSession(
        authRepository: _PendingAuthRepository(),
        sessionUserId: userId,
      );

      expect(provider.initialized, isTrue);
      expect(provider.currentUser?.fullName, 'Budi Santoso');
      expect(provider.currentUser?.email, 'guru.cache@sekolah.sch.id');
      expect(provider.activeRole, 'guru');
      expect(provider.activeSchoolId, schoolId);
      expect(provider.activeSchoolName, 'SMAN 1 Contoh');
      expect(provider.activeSchool?.name, 'SMAN 1 Contoh');
      expect(provider.userMemberships.single.schoolName, 'SMAN 1 Contoh');

      provider.dispose();
    },
  );

  testWidgets(
    'drawer tidak menampilkan placeholder Guru Pengajar / G saat profil belum siap',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = AuthProvider(
        authRepository: _PendingAuthRepository(),
      );
      final warningProvider = WarningLetterProvider(
        warningLetterRepository: _FakeWarningLetterRepo(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<WarningLetterProvider>.value(
              value: warningProvider,
            ),
            ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
          ],
          child: ScreenUtilInit(
            designSize: const Size(1280, 800),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SizedBox(
                  width: 288,
                  height: 800,
                  child: GuruDrawerPanel(currentRoute: '/guru/dashboard'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(authProvider.currentUser, isNull);
      expect(find.text('Guru Pengajar'), findsNothing);
      expect(find.text('G'), findsNothing);
      expect(find.text('Sekolah'), findsNothing);
      expect(find.byType(ProfilePhotoView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

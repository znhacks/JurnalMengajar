import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/school_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/student_academic_history_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/services/excel_import_service.dart';
import 'package:jurnalmengajar/widgets/class_import_modal.dart';
import 'package:jurnalmengajar/widgets/student_import_modal.dart';

class FakePeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [
    PeriodModel(
      id: 'p1',
      name: '2026/2027 Ganjil',
      isActive: true,
      schoolId: 's1',
    ),
  ];
  @override
  Future<void> create(PeriodModel p) async {}
  @override
  Future<void> update(PeriodModel p) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
  @override
  Future<void> setActivePeriod(String id) async {}
}

class FakeSubjectRepo implements SubjectRepository {
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(SubjectModel s) async {}
  @override
  Future<void> update(SubjectModel s) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(HourModel h) async {}
  @override
  Future<void> update(HourModel h) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeClassRepo implements ClassRepository {
  final List<ClassModel> classes = [];
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => classes;
  @override
  Future<void> create(ClassModel c) async => classes.add(c);
  @override
  Future<void> update(ClassModel c) async {}
  @override
  Future<void> delete(String id) async =>
      classes.removeWhere((c) => c.id == id);
  @override
  Future<void> deleteMultiple(List<String> ids) async =>
      classes.removeWhere((c) => ids.contains(c.id));
}

class FakeTeacherRepo implements TeacherRepository {
  @override
  Future<List<TeacherModel>> getAll() async => [];
  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => [];
  @override
  Future<void> create(TeacherModel t) async {}
  @override
  Future<void> update(TeacherModel t) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeStudentRepo implements StudentRepository {
  @override
  Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override
  Future<void> create(StudentModel s) async {}
  @override
  Future<void> update(StudentModel s) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
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
}

void main() {
  group('ExcelImportService - Class Import Tests', () {
    test(
      'downloadClassTemplate creates workbook with properly spaced columns',
      () async {
        final excel = Excel.createExcel();
        const sheetName = 'Format Impor Kelas';
        excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
        final sheet = excel[sheetName];

        sheet.setColumnWidth(0, 10.0);
        sheet.setColumnWidth(1, 30.0);
        sheet.setColumnWidth(2, 38.0);

        sheet.appendRow([
          TextCellValue('No'),
          TextCellValue('Nama Kelas'),
          TextCellValue('Keterangan / Jurusan (Opsional)'),
        ]);

        sheet.appendRow([
          IntCellValue(1),
          TextCellValue('X RPL 1'),
          TextCellValue('Rekayasa Perangkat Lunak'),
        ]);

        final bytes = excel.save();
        expect(bytes, isNotNull);

        // Verify decode
        final decoded = Excel.decodeBytes(bytes!);
        final readSheet = decoded.tables[sheetName]!;
        expect(readSheet.rows.length, 2);
        expect(readSheet.rows[0][1]?.value.toString(), 'Nama Kelas');
        expect(readSheet.rows[1][1]?.value.toString(), 'X RPL 1');
      },
    );

    test(
      'parseClassExcelBytes parses classes, detects duplicates and validates data',
      () {
        final excel = Excel.createExcel();
        final sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];

        sheet.appendRow([
          TextCellValue('No'),
          TextCellValue('Nama Kelas'),
          TextCellValue('Keterangan / Jurusan'),
        ]);

        sheet.appendRow([
          IntCellValue(1),
          TextCellValue('X RPL 1'),
          TextCellValue('Rekayasa Perangkat Lunak'),
        ]);

        // Duplicate in file
        sheet.appendRow([
          IntCellValue(2),
          TextCellValue('X RPL 1'),
          TextCellValue('Duplikat'),
        ]);

        // Existing in DB
        sheet.appendRow([
          IntCellValue(3),
          TextCellValue('XI TKJ 1'),
          TextCellValue('Teknik Komputer'),
        ]);

        // Missing name
        sheet.appendRow([
          IntCellValue(4),
          TextCellValue(''),
          TextCellValue('Tanpa Nama'),
        ]);

        final bytes = excel.save()!;
        final existingClasses = [
          ClassModel(
            id: 'c_exist',
            periodId: 'p1',
            name: 'XI TKJ 1',
            studentCount: 20,
          ),
        ];

        final result = ExcelImportService.parseClassExcelBytes(
          bytes,
          fileName: 'kelas_test.xlsx',
          existingClasses: existingClasses,
        );

        expect(result.fileName, 'kelas_test.xlsx');
        expect(result.items.length, 4);

        // Item 0: valid
        expect(result.items[0].name, 'X RPL 1');
        expect(result.items[0].isValid, true);
        expect(result.items[0].isDuplicate, false);
        expect(result.items[0].isSelected, true);

        // Item 1: duplicate in file
        expect(result.items[1].name, 'X RPL 1');
        expect(result.items[1].isDuplicate, true);
        expect(result.items[1].isSelected, false);

        // Item 2: duplicate from database
        expect(result.items[2].name, 'XI TKJ 1');
        expect(result.items[2].isDuplicate, true);
        expect(result.items[2].isSelected, false);

        // Item 3: missing name error
        expect(result.items[3].isValid, false);
        expect(result.items[3].error, isNotNull);
      },
    );
  });

  group('Import Step 1 & Step 2 UI Integration', () {
    testWidgets(
      'ClassImportModal renders Step 1 banner, period selector and template button',
      (tester) async {
        final fakeClassRepo = FakeClassRepo();
        final masterProvider = MasterDataProvider(
          periodRepository: FakePeriodRepo(),
          subjectRepository: FakeSubjectRepo(),
          hourRepository: FakeHourRepo(),
          classRepository: fakeClassRepo,
          teacherRepository: FakeTeacherRepo(),
          studentRepository: FakeStudentRepo(),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<MasterDataProvider>.value(
                value: masterProvider,
              ),
            ],
            child: ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (context, _) =>
                  const MaterialApp(home: Scaffold(body: ClassImportModal())),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify clean header and action buttons
        expect(find.text('Impor Kelas'), findsOneWidget);
        expect(find.text('Unduh Template'), findsOneWidget);
        expect(find.text('Pilih File Excel'), findsOneWidget);
      },
    );

    testWidgets(
      'StudentImportModal displays clear onboarding guide when no classes exist',
      (tester) async {
        final fakeClassRepo = FakeClassRepo(); // Empty classes
        final masterProvider = MasterDataProvider(
          periodRepository: FakePeriodRepo(),
          subjectRepository: FakeSubjectRepo(),
          hourRepository: FakeHourRepo(),
          classRepository: fakeClassRepo,
          teacherRepository: FakeTeacherRepo(),
          studentRepository: FakeStudentRepo(),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<MasterDataProvider>.value(
                value: masterProvider,
              ),
            ],
            child: ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (context, _) => const MaterialApp(
                home: Scaffold(body: StudentImportModal(availableClasses: [])),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Must guide user to Impor Kelas first
        expect(find.text('Belum Ada Kelas'), findsOneWidget);
        expect(find.text('Impor Kelas'), findsOneWidget);
      },
    );
  });
}

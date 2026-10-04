import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/widgets/student_import_modal.dart';

class FakePeriodRepo implements PeriodRepository {
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

class FakeSubjectRepo implements SubjectRepository {
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

class FakeHourRepo implements HourRepository {
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

class FakeClassRepo implements ClassRepository {
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

class FakeTeacherRepo implements TeacherRepository {
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

class FakeStudentRepo implements StudentRepository {
  List<StudentModel> items = [];

  @override
  Future<List<StudentModel>> getAllByClass(String classId) async =>
      items.where((s) => s.classId == classId).toList();

  @override
  Future<void> create(StudentModel student) async => items.add(student);

  @override
  Future<void> update(StudentModel student) async {}

  @override
  Future<void> delete(String id) async => items.removeWhere((s) => s.id == id);

  @override
  Future<void> deleteMultiple(List<String> ids) async =>
      items.removeWhere((s) => ids.contains(s.id));
}

void main() {
  testWidgets('StudentImportModal renders upload step with template and instruction details', (tester) async {
    final fakeStudentRepo = FakeStudentRepo();
    final fakeClassRepo = FakeClassRepo();

    final masterProvider = MasterDataProvider(
      periodRepository: FakePeriodRepo(),
      subjectRepository: FakeSubjectRepo(),
      hourRepository: FakeHourRepo(),
      classRepository: fakeClassRepo,
      teacherRepository: FakeTeacherRepo(),
      studentRepository: fakeStudentRepo,
    );

    final mockClass = ClassModel(
      id: 'c1',
      periodId: 'p1',
      name: 'Kelas X-A',
      studentCount: 15,
      schoolId: 's1',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, _) => MaterialApp(
            home: Scaffold(
              body: StudentImportModal(
                initialClass: mockClass,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header title
    expect(find.text('Impor Siswa dari Excel'), findsOneWidget);
    expect(find.text('Kelas: Kelas X-A'), findsOneWidget);

    // Verify template download section
    expect(find.text('Belum punya format Excel?'), findsOneWidget);
    expect(find.text('Unduh'), findsOneWidget);

    // Verify file picker drop area
    expect(find.text('Pilih File Excel Siswa'), findsOneWidget);
    expect(find.text('Mendukung format .xlsx atau .xls'), findsOneWidget);

    // Verify column guidelines
    expect(find.text('Petunjuk Format Kolom Excel:'), findsOneWidget);
    expect(find.text('Nama Siswa: '), findsOneWidget);
    expect(find.text('Jenis Kelamin: '), findsOneWidget);
  });
}

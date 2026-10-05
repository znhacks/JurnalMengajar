import '../models/student_model.dart';
import '../models/student_academic_history_model.dart';

abstract class StudentRepository {
  Future<List<StudentModel>> getAllByClass(String classId);
  Future<void> create(StudentModel model);
  Future<void> update(StudentModel model);
  Future<void> delete(String id);
  Future<void> deleteMultiple(List<String> ids);
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(String studentId);
  Future<Map<String, dynamic>> processPromotions({
    required String schoolId,
    required String sourcePeriodId,
    required String sourceClassId,
    String? targetPeriodId,
    String? targetClassId,
    required List<Map<String, dynamic>> items,
    DateTime? transferDate,
  });
}

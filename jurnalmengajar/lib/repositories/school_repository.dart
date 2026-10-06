import '../models/school_model.dart';

abstract class SchoolRepository {
  Future<List<SchoolModel>> getAll();
  Future<SchoolModel?> validateActivationCode(String code);
  /// Cari sekolah dari kode gabung guru (kode sederhana dari admin).
  /// Mengembalikan null jika tidak ada / kolom belum dimigrasi.
  Future<SchoolModel?> validateTeacherJoinCode(String code);
  Future<SchoolModel> activateSchoolWithCode({
    required String currentSchoolId,
    required String activationCode,
  });
  Future<bool> updateSchoolPlan(String schoolId, String plan, String activationCode);
}

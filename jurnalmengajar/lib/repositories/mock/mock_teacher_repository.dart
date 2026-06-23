import '../teacher_repository.dart';
import '../../models/teacher_model.dart';
import '../../models/user_model.dart';
import 'mock_database.dart';

class MockTeacherRepository implements TeacherRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<List<TeacherModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_db.teachers);
  }

  @override
  Future<void> create(TeacherModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 't_${DateTime.now().millisecondsSinceEpoch}';
    final newTeacher = model.copyWith(id: id);
    _db.teachers.add(newTeacher);

    // Sync to user model if doesn't exist yet
    final emailExists = _db.users.any((u) => u.email.toLowerCase() == model.email.toLowerCase());
    if (!emailExists) {
      _db.users.add(UserModel(
        id: 'u_${DateTime.now().millisecondsSinceEpoch}',
        email: model.email,
        fullName: model.name,
        role: 'guru',
        photoUrl: model.photoUrl,
        phoneNumber: model.phoneNumber,
        position: model.position,
        address: model.address,
      ));
    }
  }

  @override
  Future<void> update(TeacherModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.teachers.indexWhere((t) => t.id == model.id);
    if (index != -1) {
      final oldTeacher = _db.teachers[index];
      _db.teachers[index] = model;

      // Sync to user model as well
      final userIndex = _db.users.indexWhere((u) => u.email.toLowerCase() == oldTeacher.email.toLowerCase());
      if (userIndex != -1) {
        final u = _db.users[userIndex];
        _db.users[userIndex] = u.copyWith(
          email: model.email,
          fullName: model.name,
          photoUrl: model.photoUrl,
          phoneNumber: model.phoneNumber,
          position: model.position,
          address: model.address,
        );
      }
    } else {
      throw Exception('Guru tidak ditemukan!');
    }
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final teacher = _db.teachers.firstWhere((t) => t.id == id, orElse: () => throw Exception('Guru tidak ditemukan!'));
    _db.teachers.removeWhere((t) => t.id == id);
    
    // Also remove from user list to prevent ghost logins
    _db.users.removeWhere((u) => u.email.toLowerCase() == teacher.email.toLowerCase());
  }
}

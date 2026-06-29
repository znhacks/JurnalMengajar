import '../auth_repository.dart';
import '../../models/user_model.dart';
import '../../models/teacher_model.dart';
import 'mock_database.dart';

class MockAuthRepository implements AuthRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<UserModel?> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _db.currentUser;
  }

  @override
  Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    
    // Check in user list
    final userIndex = _db.users.indexWhere(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );

    if (userIndex != -1) {
      final user = _db.users[userIndex];
      _db.currentUser = user;
      return user;
    } else {
      // Create a dummy user if not found just for demonstration, or throw error.
      // We will throw error for proper authentication demonstration.
      throw Exception('Email atau password salah!');
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    
    // Choose a default teacher user as Google login target
    final googleUser = _db.users.firstWhere(
      (u) => u.email == 'sri@jurnal.com',
      orElse: () => _db.users.first,
    );

    _db.currentUser = googleUser;
    return googleUser;
  }

  @override
  Future<void> register(UserModel user, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if email already exists
    if (_db.users.any((u) => u.email.toLowerCase() == user.email.toLowerCase())) {
      throw Exception('Email sudah terdaftar!');
    }

    final id = 'u_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = user.copyWith(id: id);
    _db.users.add(newUser);

    // If role is guru, automatically register as a Teacher too
    if (newUser.role == 'guru') {
      final teacherId = 't_${DateTime.now().millisecondsSinceEpoch}';
      final newTeacher = TeacherModel(
        id: teacherId,
        name: newUser.fullName,
        position: newUser.position ?? 'Guru Bidang Studi',
        address: newUser.address ?? 'Belum Diisi',
        phoneNumber: newUser.phoneNumber ?? 'Belum Diisi',
        email: newUser.email,
        photoUrl: newUser.photoUrl,
      );
      _db.teachers.add(newTeacher);
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final exists = _db.users.any((u) => u.email.toLowerCase() == email.toLowerCase());
    if (!exists) {
      throw Exception('Email tidak ditemukan!');
    }
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _db.currentUser = null;
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final index = _db.users.indexWhere((u) => u.id == user.id);
    if (index == -1) {
      throw Exception('User tidak ditemukan!');
    }

    _db.users[index] = user;
    
    // If current logged in user is being updated, update the session
    if (_db.currentUser?.id == user.id) {
      _db.currentUser = user;
    }

    // Synchronize with Teacher list if user is a teacher
    final teacherIndex = _db.teachers.indexWhere((t) => t.email.toLowerCase() == user.email.toLowerCase());
    if (teacherIndex != -1) {
      final t = _db.teachers[teacherIndex];
      _db.teachers[teacherIndex] = t.copyWith(
        name: user.fullName,
        position: user.position,
        address: user.address,
        phoneNumber: user.phoneNumber,
        photoUrl: user.photoUrl,
      );
    }

    return user;
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _db.users;
  }

  @override
  Future<void> updateUserRole(String userId, String role) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _db.users[index] = _db.users[index].copyWith(role: role);
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _db.users.removeWhere((u) => u.id == userId);
    if (_db.currentUser?.id == userId) {
      _db.currentUser = null;
    }
  }
}

import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> getCurrentUser();
  Future<UserModel> login(String email, String password);
  Future<UserModel> loginWithGoogle();
  Future<void> register(UserModel user, String password);
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> changeEmail(String newEmail);
  Future<void> logout();
  Future<UserModel> updateProfile(UserModel user);
  Future<List<UserModel>> getAllUsers();
  Future<void> updateUserRole(String userId, String role);
  Future<void> deleteAccount(String userId);
  Future<void> updateFcmToken(String userId, String token);
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _initialized = false; // true once the first getCurrentUser() attempt finishes
  bool _isLoadingUser = false; // guard against concurrent _loadCurrentUser() calls
  String? _errorMessage;
  bool _isRecoveryMode = false;

  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    _loadCurrentUser(isInitialBoot: true);
    
    // Automatically reload profile on Auth state change (e.g. OAuth Redirect Callback)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      if (event == AuthChangeEvent.passwordRecovery) {
        _isRecoveryMode = true;
        await _loadCurrentUser();
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        await _loadCurrentUser();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _isRecoveryMode = false;
        notifyListeners();
      }
    });
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isRecoveryMode => _isRecoveryMode;
  AuthRepository get authRepository => _authRepository;

  Future<void> _loadCurrentUser({bool isInitialBoot = false}) async {
    // Prevent concurrent executions to avoid race conditions with OAuth callback
    if (_isLoadingUser) return;
    _isLoadingUser = true;
    _isLoading = true;
    notifyListeners();
    try {
      final user = await authRepository.getCurrentUser();
      if (user?.role == 'pending_guru') {
        _currentUser = null;
        await authRepository.logout();
        if (!isInitialBoot) {
          _errorMessage = 'Pendaftaran Anda sedang menunggu persetujuan Admin. Silakan hubungi Admin untuk konfirmasi.';
        }
      } else {
        _currentUser = user;
        if (user != null) {
          FcmService().syncToken(this);
        }
      }
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
    } finally {
      _isLoadingUser = false;
      _isLoading = false;
      _initialized = true; // mark ready regardless of result
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _isRecoveryMode = false;
    notifyListeners();
    try {
      final loggedInUser = await authRepository.login(email, password);
      if (loggedInUser.role == 'pending_guru') {
        await authRepository.logout();
        throw Exception('Pendaftaran Anda sedang menunggu persetujuan Admin. Silakan hubungi Admin untuk konfirmasi.');
      }
      _currentUser = loggedInUser;
      _isLoading = false;
      notifyListeners();
      FcmService().syncToken(this);
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _isRecoveryMode = false;
    notifyListeners();
    try {
      // On web: this triggers the browser redirect to Google.
      // The session will be captured by onAuthStateChange when the user returns.
      // On mobile: the deep link callback will trigger onAuthStateChange as well.
      await authRepository.loginWithGoogle();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required String position,
    required String address,
    String role = 'guru',
    String? photoUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = UserModel(
        id: '',
        email: email,
        fullName: fullName,
        role: role,
        phoneNumber: phoneNumber,
        position: position,
        address: address,
        photoUrl: photoUrl,
      );
      await authRepository.register(user, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await authRepository.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await authRepository.updatePassword(newPassword);
      _isRecoveryMode = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changeEmail(String newEmail) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.changeEmail(newEmail);
      await _loadCurrentUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _isRecoveryMode = false;
    notifyListeners();
    await authRepository.logout();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateFcmToken(String token) async {
    if (_currentUser != null) {
      await authRepository.updateFcmToken(_currentUser!.id, token);
    }
  }

  Future<bool> updateProfile(UserModel updatedUser) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await authRepository.updateProfile(updatedUser);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final users = await authRepository.getAllUsers();
      _isLoading = false;
      notifyListeners();
      return users;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<bool> updateUserRole(String userId, String role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await authRepository.updateUserRole(userId, role);
      // If the modified user is current user, update local profile as well
      if (_currentUser != null && _currentUser!.id == userId) {
        _currentUser = _currentUser!.copyWith(role: role);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await authRepository.deleteAccount(userId);
      if (_currentUser != null && _currentUser!.id == userId) {
        _currentUser = null;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _cleanErrorMessage(dynamic e) {
    final errorString = e.toString().toLowerCase();
    
    // Deteksi error koneksi internet / jaringan
    if (errorString.contains('socketexception') || 
        errorString.contains('failed host lookup') || 
        errorString.contains('network_request_failed') ||
        errorString.contains('clientexception') ||
        errorString.contains('network error') ||
        errorString.contains('xmlhttprequest error') ||
        errorString.contains('connection failed') ||
        errorString.contains('failed to connect') ||
        errorString.contains('handshake') ||
        errorString.contains('stream error')) {
      return 'Koneksi internet terputus. Silakan periksa koneksi internet Anda dan coba lagi.';
    }
    
    // Deteksi error autentikasi umum dari Supabase
    if (errorString.contains('invalid login credentials')) {
      return 'Email atau password salah. Silakan periksa kembali.';
    }
    if (errorString.contains('email not confirmed')) {
      return 'Email Anda belum diverifikasi. Silakan periksa kotak masuk email Anda.';
    }
    if (errorString.contains('rate limit') || errorString.contains('too many requests')) {
      return 'Terlalu banyak percobaan masuk. Silakan coba lagi nanti.';
    }
    if (errorString.contains('user already exists') || errorString.contains('user_already_exists')) {
      return 'Email sudah terdaftar. Silakan gunakan email lain atau masuk.';
    }
    
    // Bersihkan prefix "Exception: " jika ada
    return e.toString().replaceAll('Exception: ', '');
  }
}

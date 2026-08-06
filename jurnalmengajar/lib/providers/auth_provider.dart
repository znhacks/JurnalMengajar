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

  List<dynamic> _userMemberships = [];
  String? _activeSchoolId;
  String _activeSchoolName = 'Sekolah';
  String _activeRole = 'guru';

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isRecoveryMode => _isRecoveryMode;
  AuthRepository get authRepository => _authRepository;

  List<dynamic> get userMemberships => _userMemberships;
  String? get activeSchoolId => _activeSchoolId;
  String get activeSchoolName => _activeSchoolName;
  String get activeRole => _activeRole;

  void switchActiveSchool(String schoolId, String schoolName, String role) {
    _activeSchoolId = schoolId;
    _activeSchoolName = schoolName;
    _activeRole = role;
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        schoolName: schoolName,
        role: role,
      );
    }
    notifyListeners();
  }

  Future<bool> joinSchoolWithCode(String code, {String role = 'guru'}) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final cleanCode = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

      // 1. Fetch matching school from schools table by code or npsn or id
      final schoolsRes = await supabase
          .from('schools')
          .select();

      Map<String, dynamic>? matchedSchool;
      for (final s in (schoolsRes as List)) {
        final sCode = ((s['code'] as String?) ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final sNpsn = ((s['npsn'] as String?) ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final sId = ((s['id'] as String?) ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final sName = ((s['name'] as String?) ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');

        if ((sCode.isNotEmpty && sCode == cleanCode) ||
            (sNpsn.isNotEmpty && sNpsn == cleanCode) ||
            (sId.isNotEmpty && sId == cleanCode) ||
            (sName.isNotEmpty && (sName == cleanCode || sName.contains(cleanCode)))) {
          matchedSchool = Map<String, dynamic>.from(s);
          break;
        }
      }

      if (matchedSchool == null) {
        throw Exception('Kode / NPSN Sekolah tidak ditemukan.');
      }

      final schoolId = matchedSchool['id'] as String;
      final schoolName = matchedSchool['name'] as String? ?? 'Sekolah';

      final effectiveRole = role;

      // 2. Insert or update user_schools relationship
      try {
        await supabase.from('user_schools').upsert({
          'user_id': _currentUser!.id,
          'school_id': schoolId,
          'role': effectiveRole,
        });
      } catch (dbErr) {
        debugPrint('Note inserting user_schools: $dbErr');
      }

      // 3. Update active school locally
      switchActiveSchool(schoolId, schoolName, effectiveRole);
      await loadUserMemberships();
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

  Future<void> loadUserMemberships() async {
    if (_currentUser == null) return;
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('user_schools')
          .select('*, schools(name, code)')
          .eq('user_id', _currentUser!.id);

      _userMemberships = (res as List).map((item) {
        final m = Map<String, dynamic>.from(item);
        m['role'] = item['role'] ?? _currentUser!.role;
        return m;
      }).toList();

      if (_userMemberships.isNotEmpty) {
        final first = _userMemberships.first;
        final schData = first['schools'];
        _activeSchoolId = first['school_id'];
        _activeRole = first['role'] ?? _currentUser!.role;
        _activeSchoolName = (schData != null && schData['name'] != null) ? schData['name'] : 'Sekolah';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user memberships: $e');
      _userMemberships = [];
    }
  }


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
          _errorMessage = 'Pendaftaran Guru Anda sedang menunggu persetujuan Admin Sekolah. Silakan hubungi Admin Sekolah Anda untuk konfirmasi.';
        }
      } else if (user?.role == 'pending_admin') {
        _currentUser = null;
        await authRepository.logout();
        if (!isInitialBoot) {
          _errorMessage = 'Pendaftaran Admin Sekolah Anda sedang menunggu pengaktifan Kode Sekolah dari Superadmin. Silakan hubungi Superadmin.';
        }
      } else {
        _currentUser = user;
        if (user != null) {
          FcmService().syncToken(this);
          await loadUserMemberships();
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
        throw Exception('Pendaftaran Guru Anda sedang menunggu persetujuan Admin Sekolah. Silakan hubungi Admin Sekolah Anda untuk konfirmasi.');
      } else if (loggedInUser.role == 'pending_admin') {
        await authRepository.logout();
        throw Exception('Pendaftaran Admin Sekolah Anda sedang menunggu pengaktifan Kode Sekolah dari Superadmin. Silakan hubungi Superadmin.');
      }
      _currentUser = loggedInUser;
      await loadUserMemberships();
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
    String? schoolName,
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
        schoolName: schoolName,
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
    _activeSchoolId = null;
    _activeSchoolName = 'Sekolah';
    _activeRole = 'guru';
    _userMemberships = [];
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

  Future<List<UserModel>> getAllUsers([String? schoolId]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final targetSchoolId = schoolId ?? _activeSchoolId;
      final users = (targetSchoolId != null && targetSchoolId.isNotEmpty)
          ? await authRepository.getAllUsersForSchool(targetSchoolId)
          : await authRepository.getAllUsers();
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

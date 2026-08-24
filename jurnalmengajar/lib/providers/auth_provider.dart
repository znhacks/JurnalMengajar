import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/user_school_model.dart';
import '../models/school_model.dart';
import '../repositories/auth_repository.dart';
import '../services/fcm_service.dart';

class AuthProvider with ChangeNotifier {
  static const String _kActiveSchoolIdKey = 'active_school_id';
  static const String _kActiveRoleKey = 'active_role';
  final AuthRepository _authRepository;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _initialized = false; // true once the first getCurrentUser() attempt finishes
  bool _isLoadingUser = false; // guard against concurrent _loadCurrentUser() calls
  String? _errorMessage;
  bool _isRecoveryMode = false;
  bool _isSchoolExpired = false;

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

  List<UserSchoolModel> _userMemberships = [];
  String? _activeSchoolId;
  String _activeSchoolName = 'Sekolah';
  String _activeRole = 'guru';
  SchoolModel? _activeSchool;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isRecoveryMode => _isRecoveryMode;
  bool get isSchoolExpired => _isSchoolExpired;
  AuthRepository get authRepository => _authRepository;

  List<UserSchoolModel> get userMemberships => _userMemberships;
  String? get activeSchoolId => _activeSchoolId;
  String get activeSchoolName => _activeSchoolName;
  String get activeRole => _activeRole;
  SchoolModel? get activeSchool => _activeSchool;

  bool get isExclusiveAdmin {
    if (_currentUser == null) return true;
    final emailLower = _currentUser!.email.toLowerCase().trim();
    final nameLower = _currentUser!.fullName.toLowerCase().trim();
    return emailLower == 'admin@jurnal.com' ||
           emailLower == 'smkn11malang@jurnal.com' ||
           emailLower.startsWith('admin@') ||
           nameLower.contains('admin');
  }

  Future<void> fetchActiveSchoolDetails() async {
    if (_activeSchoolId == null) {
      _activeSchool = null;
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('schools')
          .select()
          .eq('id', _activeSchoolId!)
          .maybeSingle();
      if (res != null) {
        _activeSchool = SchoolModel.fromJson(res);
        _activeSchoolName = _activeSchool!.name;
      } else {
        _activeSchool = null;
        if (!isExclusiveAdmin) {
          throw Exception('Tidak terdapat sekolah dengan kode ini, mungkin berlangganan pada jmpanel.vercel.app telah expired/school dihapus');
        }
      }
    } catch (e) {
      if (e.toString().contains('jmpanel.vercel.app')) {
        rethrow;
      }
      debugPrint('Error fetching active school details: $e');
      _activeSchool = null;
    }
  }

  Future<void> switchActiveSchool(String schoolId, String schoolName, String role) async {
    _activeSchoolId = schoolId;
    _activeSchoolName = schoolName;
    _activeRole = role;
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        schoolName: schoolName,
        role: role,
      );
    }
    
    // Persist active school & role locally to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveSchoolIdKey, schoolId);
      await prefs.setString(_kActiveRoleKey, role);
    } catch (e) {
      debugPrint('Error saving active school to SharedPreferences: $e');
    }

    try {
      await fetchActiveSchoolDetails();
    } catch (e) {
      if (e.toString().contains('jmpanel.vercel.app')) {
        _isSchoolExpired = true;
        notifyListeners();
        return;
      }
      rethrow;
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
            (sName.isNotEmpty && sName == cleanCode)) {
          matchedSchool = Map<String, dynamic>.from(s);
          break;
        }
      }

      if (matchedSchool == null) {
        throw Exception('Tidak terdapat sekolah dengan kode ini, mungkin berlangganan pada jmpanel.vercel.app telah expired/school dihapus');
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

      // 3. Update active school locally & persist
      await switchActiveSchool(schoolId, schoolName, effectiveRole);
      await loadUserMemberships();
      _isSchoolExpired = false;
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

      final loadedMemberships = (res as List)
          .where((item) => item['schools'] != null)
          .map((item) {
        final m = Map<String, dynamic>.from(item);
        m['role'] = item['role'] ?? _currentUser!.role;
        return UserSchoolModel.fromJson(m);
      }).toList();

      _userMemberships = loadedMemberships;

      if (_userMemberships.isNotEmpty) {
        // Load saved preference if available
        final prefs = await SharedPreferences.getInstance();
        final savedSchoolId = prefs.getString(_kActiveSchoolIdKey);

        UserSchoolModel? activeMember;
        if (savedSchoolId != null && savedSchoolId.isNotEmpty) {
          activeMember = _userMemberships.firstWhere(
            (m) => m.schoolId == savedSchoolId,
            orElse: () => _userMemberships.first,
          );
        } else {
          activeMember = _userMemberships.first;
        }

        _activeSchoolId = activeMember.schoolId;
        _activeRole = activeMember.role;
        _activeSchoolName = activeMember.schoolName;

        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            schoolName: _activeSchoolName,
            role: _activeRole,
          );
        }
        await fetchActiveSchoolDetails();
      } else {
        if (!isExclusiveAdmin) {
          throw Exception('Tidak terdapat sekolah dengan kode ini, mungkin berlangganan pada jmpanel.vercel.app telah expired/school dihapus');
        }
      }
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('jmpanel.vercel.app')) {
        rethrow;
      }
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
      if (_errorMessage != null && _errorMessage!.contains('jmpanel.vercel.app')) {
        _isSchoolExpired = true;
      }
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
      if (_errorMessage != null && _errorMessage!.contains('jmpanel.vercel.app')) {
        _isSchoolExpired = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
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
    _isSchoolExpired = false;
    notifyListeners();
    await authRepository.logout();
    _currentUser = null;
    _activeSchoolId = null;
    _activeSchoolName = 'Sekolah';
    _activeRole = 'guru';
    _activeSchool = null;
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
      await logout();
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

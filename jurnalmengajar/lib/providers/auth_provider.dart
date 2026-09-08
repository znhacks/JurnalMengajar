import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/user_school_model.dart';
import '../models/school_model.dart';
import '../repositories/auth_repository.dart';
import '../services/fcm_service.dart';
import '../core/utils/helper.dart';


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

  bool get hasMultipleSchools => _userMemberships.length > 1;

  bool get isExclusiveAdmin {
    if (_currentUser == null) return false;
    // Account without multiple memberships doesn't need school switcher
    return _userMemberships.length <= 1;
  }

  Future<void> fetchActiveSchoolDetails() async {
    if (_activeSchoolId == null) {
      _activeSchool = null;
      return;
    }
    try {
      final supabase = Supabase.instance.client;
      var res = await supabase
          .from('schools')
          .select()
          .eq('id', _activeSchoolId!)
          .maybeSingle();

      if (res == null) {
        try {
          final tenantRes = await supabase
              .from('tenants')
              .select('id, name, school_code, status')
              .eq('id', _activeSchoolId!)
              .maybeSingle();
          if (tenantRes != null) {
            final tenantName = tenantRes['name'] as String? ?? 'Sekolah';
            final tenantStatus = (tenantRes['status'] as String? ?? 'active').toLowerCase();
            final tenantCode = tenantRes['school_code'] as String? ?? _activeSchoolId!;
            try {
              await supabase.from('schools').upsert({
                'id': _activeSchoolId!,
                'name': tenantName,
                'code': tenantCode,
                'status': tenantStatus,
              }, onConflict: 'id');
            } catch (_) {}

            res = await supabase
                .from('schools')
                .select()
                .eq('id', _activeSchoolId!)
                .maybeSingle();

            res ??= {
              'id': _activeSchoolId!,
              'name': tenantName,
              'code': tenantCode,
              'status': tenantStatus,
            };
          }
        } catch (_) {}
      }

      // Self-heal from user metadata if school record is missing
      if (res == null && _activeSchoolId != null) {
        final fallbackName = _activeSchoolName.isNotEmpty 
            ? _activeSchoolName 
            : (_currentUser?.schoolName ?? 'Sekolah');
        try {
          await supabase.from('schools').upsert({
            'id': _activeSchoolId!,
            'name': fallbackName,
            'code': _activeSchoolId!,
            'status': 'active',
            'subscription_plan': 'free',
            'max_teachers': 30,
          }, onConflict: 'id');
          res = {
            'id': _activeSchoolId!,
            'name': fallbackName,
            'code': _activeSchoolId!,
            'status': 'active',
            'subscription_plan': 'free',
            'max_teachers': 30,
          };
        } catch (_) {}
      }

      if (res != null) {
        var schoolModel = SchoolModel.fromJson(res);

        // Otomatis: jika logo_url kosong, ambil dari foto profil akun khusus admin (bukan guru yang switch)
        String? resolvedLogo = schoolModel.logoUrl;
        if (resolvedLogo == null || resolvedLogo.trim().isEmpty) {
          try {
            final adminUsers = await supabase
                .from('users')
                .select('id, photo_url, role')
                .eq('school_id', _activeSchoolId!)
                .eq('role', 'admin');

            for (final u in (adminUsers as List)) {
              if (u['photo_url'] != null && (u['photo_url'] as String).trim().isNotEmpty) {
                resolvedLogo = (u['photo_url'] as String).trim();
                // Simpan otomatis ke tabel schools agar sinkron di semua tempat
                await supabase.from('schools').update({
                  'logo_url': resolvedLogo,
                }).eq('id', _activeSchoolId!);
                break;
              }
            }
          } catch (adminPhotoErr) {
            debugPrint('Note resolving dedicated admin photo for school logo: $adminPhotoErr');
          }
        }

        if (resolvedLogo != null && resolvedLogo.trim().isNotEmpty && resolvedLogo != schoolModel.logoUrl) {
          schoolModel = schoolModel.copyWith(logoUrl: resolvedLogo);
        }

        _activeSchool = schoolModel;
        _activeSchoolName = _activeSchool!.name;
        if (_activeSchool!.isInactive) {
          _isSchoolExpired = true;
          notifyListeners();
          throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator.');
        } else {
          _isSchoolExpired = false;
        }
      } else {
        _activeSchool = null;
      }
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
        rethrow;
      }
      debugPrint('Error fetching active school details: $e');
      _activeSchool = null;
    }
  }

  Future<void> switchActiveSchool(String schoolId, String schoolName, String role) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId.trim();
    _activeSchoolId = cleanSchoolId;
    _activeSchoolName = schoolName;
    _activeRole = role;
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        schoolId: cleanSchoolId,
        schoolName: schoolName,
        role: role,
      );
    }

    // Immediately populate basic activeSchool from userMemberships so UI has full context instantly
    try {
      final m = _userMemberships.firstWhere(
        (element) => element.schoolId == cleanSchoolId && element.role.toLowerCase() == role.toLowerCase(),
        orElse: () => _userMemberships.firstWhere((element) => element.schoolId == cleanSchoolId),
      );
      _activeSchool = SchoolModel(
        id: m.schoolId,
        name: m.schoolName,
        logoUrl: m.logoUrl,
      );
    } catch (_) {}

    // Notify listeners immediately so the UI switches context with 0ms delay
    notifyListeners();
    
    // Persist active school & role locally in background
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kActiveSchoolIdKey, cleanSchoolId);
      prefs.setString(_kActiveRoleKey, role);
    }).catchError((e) {
      debugPrint('Error saving active school to SharedPreferences: $e');
    });

    try {
      await fetchActiveSchoolDetails();
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
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
      final cleanCode = code.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

      // 1. Direct query: SELECT * FROM schools WHERE code = :cleanCode AND status = 'active'
      var res = await supabase
          .from('schools')
          .select()
          .ilike('code', cleanCode)
          .eq('status', 'active')
          .maybeSingle();

      // 2. If not found, check if exists with inactive status
      if (res == null) {
        final inactiveRes = await supabase
            .from('schools')
            .select()
            .ilike('code', cleanCode)
            .maybeSingle();

        if (inactiveRes != null) {
          final s = SchoolModel.fromJson(inactiveRes);
          if (s.isInactive) {
            throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
          }
        }

        // 3. Fallback check by npsn or id
        res = await supabase
            .from('schools')
            .select()
            .or('npsn.ilike.$cleanCode,id.eq.$cleanCode')
            .eq('status', 'active')
            .maybeSingle();

        // 4. Fallback check by tenant
        if (res == null) {
          var tenantRes = await supabase
              .from('tenants')
              .select('id, name, school_code, status')
              .ilike('school_code', '%$cleanCode%')
              .maybeSingle();

          tenantRes ??= await supabase
              .from('tenants')
              .select('id, name, school_code, status')
              .eq('id', cleanCode)
              .maybeSingle();

          if (tenantRes != null) {
            final tenantId = tenantRes['id'] as String;
            final tenantName = tenantRes['name'] as String? ?? 'Sekolah';
            final tenantStatus = (tenantRes['status'] as String? ?? 'active').toLowerCase();
            final tenantCode = tenantRes['school_code'] as String? ?? cleanCode;

            if (tenantStatus == 'inactive') {
              throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
            }

            try {
              await supabase.from('schools').upsert({
                'id': tenantId,
                'name': tenantName,
                'code': tenantCode,
                'status': tenantStatus,
              }, onConflict: 'id');
            } catch (_) {}

            res = await supabase
                .from('schools')
                .select()
                .or('id.eq.$tenantId,code.ilike.$cleanCode')
                .eq('status', 'active')
                .maybeSingle();

            res ??= {
              'id': tenantId,
              'name': tenantName,
              'code': tenantCode,
              'status': tenantStatus,
            };
          }
        }
      }

      if (res == null) {
        throw Exception('Kode aktivasi tidak valid');
      }

      final matchedSchool = SchoolModel.fromJson(res);
      final schoolId = matchedSchool.id;
      final schoolName = matchedSchool.name;

      final effectiveRole = role;

      // Check if user is already connected with this specific role in user_schools
      final existingRoleMember = await supabase
          .from('user_schools')
          .select('id, role')
          .eq('user_id', _currentUser!.id)
          .eq('school_id', schoolId)
          .eq('role', effectiveRole)
          .maybeSingle();

      // Check max teachers quota for new teacher registration/join (only if not already a member with this role)
      if (effectiveRole == 'guru' && existingRoleMember == null) {
        final existingTeachers = await supabase
            .from('user_schools')
            .select('id')
            .eq('school_id', schoolId)
            .eq('role', 'guru');
        
        final teacherCount = (existingTeachers as List).length;
        if (teacherCount >= matchedSchool.maxTeachers) {
          throw Exception('Batas maksimal ${matchedSchool.maxTeachers} guru untuk sekolah ini telah tercapai.');
        }
      }

      if (existingRoleMember == null) {
        try {
          await supabase.from('user_schools').upsert({
            'user_id': _currentUser!.id,
            'school_id': schoolId,
            'role': effectiveRole,
            'status': 'active',
          }, onConflict: 'user_id, school_id, role');
        } catch (insertErr) {
          debugPrint('Note inserting user_schools: $insertErr');
        }
      }

      // Update active school locally & persist
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
      final Map<String, UserSchoolModel> membershipMap = {};

      // 1. Fetch from user_schools
      try {
        final res = await supabase
            .from('user_schools')
            .select('*, schools(id, name, code, logo_url, npsn, status)')
            .eq('user_id', _currentUser!.id);

        for (final item in (res as List)) {
          final m = Map<String, dynamic>.from(item as Map);
          m['role'] = item['role'] ?? _currentUser!.role;

          if (m['schools'] == null && m['school_id'] != null) {
            final sId = AppHelper.parseSingleCleanSchoolId(m['school_id']);
            if (sId != null && sId.isNotEmpty) {
              try {
                final sRes = await supabase
                    .from('schools')
                    .select('id, name, code, logo_url, status')
                    .eq('id', sId)
                    .maybeSingle();
                if (sRes != null) {
                  m['schools'] = sRes;
                }
              } catch (_) {}
            }
          }

          final parsed = UserSchoolModel.fromJson(m);
          if (parsed.schoolId.isNotEmpty) {
            final key = '${parsed.schoolId}_${parsed.role.toLowerCase()}';
            membershipMap[key] = parsed;
          }
        }
      } catch (err) {
        debugPrint('Error loading user_schools in memberships: $err');
      }

      // 2. Fetch from school_memberships
      try {
        final memRes = await supabase
            .from('school_memberships')
            .select('*, schools(id, name, code, logo_url, npsn, status)')
            .eq('user_id', _currentUser!.id);

        for (final item in (memRes as List)) {
          final m = Map<String, dynamic>.from(item as Map);
          final parsed = UserSchoolModel.fromJson(m);
          if (parsed.schoolId.isNotEmpty) {
            final key = '${parsed.schoolId}_${parsed.role.toLowerCase()}';
            if (!membershipMap.containsKey(key)) {
              membershipMap[key] = parsed;
            }
          }
        }
      } catch (_) {}

      // 3. Check for any schools listed in _currentUser.schoolIds
      for (final sId in _currentUser!.schoolIds) {
        final cleanId = AppHelper.parseSingleCleanSchoolId(sId);
        if (cleanId != null && cleanId.isNotEmpty) {
          final key = '${cleanId}_${_currentUser!.role.toLowerCase()}';
          if (!membershipMap.containsKey(key)) {
            try {
              final sRes = await supabase
                  .from('schools')
                  .select('id, name, code, logo_url, status')
                  .eq('id', cleanId)
                  .maybeSingle();
              if (sRes != null) {
                membershipMap[key] = UserSchoolModel(
                  id: 'us_$cleanId',
                  userId: _currentUser!.id,
                  schoolId: cleanId,
                  role: _currentUser!.role,
                  schoolName: sRes['name']?.toString() ?? 'Sekolah',
                  schoolCode: sRes['code']?.toString(),
                  logoUrl: sRes['logo_url']?.toString(),
                );
              }
            } catch (_) {}
          }
        }
      }

      _userMemberships = membershipMap.values.toList();

      if (_userMemberships.isEmpty && _currentUser != null) {
        // Self-heal: If user has schoolId or schoolName in profile, look up school and link
        try {
          Map<String, dynamic>? schoolData;
          final cleanUserSchoolId = AppHelper.parseSingleCleanSchoolId(_currentUser!.schoolId);
          if (cleanUserSchoolId != null && cleanUserSchoolId.isNotEmpty) {
            schoolData = await supabase
                .from('schools')
                .select('id, name, code, logo_url')
                .eq('id', cleanUserSchoolId)
                .maybeSingle();
          }
          if (schoolData == null && _currentUser!.schoolName != null && _currentUser!.schoolName!.isNotEmpty) {
            schoolData = await supabase
                .from('schools')
                .select('id, name, code, logo_url')
                .ilike('name', _currentUser!.schoolName!.trim())
                .maybeSingle();
          }
          if (schoolData != null) {
            final sId = schoolData['id'] as String;
            final sName = schoolData['name'] as String;
            final sLogo = schoolData['logo_url'] as String?;
            final sCode = schoolData['code'] as String?;

            try {
              await supabase.from('user_schools').insert({
                'user_id': _currentUser!.id,
                'school_id': sId,
                'role': _currentUser!.role,
                'status': 'active',
              });
            } catch (_) {}

            final healedMember = UserSchoolModel(
              id: 'us_healed',
              userId: _currentUser!.id,
              schoolId: sId,
              role: _currentUser!.role,
              schoolName: sName,
              schoolCode: sCode,
              logoUrl: sLogo,
            );
            _userMemberships = [healedMember];
          }
        } catch (healErr) {
          debugPrint('Error self-healing user memberships: $healErr');
        }
      }

      if (_userMemberships.isNotEmpty) {
        // Load saved preference if available
        final prefs = await SharedPreferences.getInstance();
        final rawSavedSchoolId = prefs.getString(_kActiveSchoolIdKey);
        final savedSchoolId = AppHelper.parseSingleCleanSchoolId(rawSavedSchoolId);
        final savedRole = prefs.getString(_kActiveRoleKey);

        UserSchoolModel? activeMember;
        if (savedSchoolId != null && savedSchoolId.isNotEmpty) {
          try {
            activeMember = _userMemberships.firstWhere(
              (m) => m.schoolId == savedSchoolId && (savedRole == null || m.role.toLowerCase() == savedRole.toLowerCase()),
            );
          } catch (_) {
            activeMember = _userMemberships.firstWhere(
              (m) => m.schoolId == savedSchoolId,
              orElse: () => _userMemberships.first,
            );
          }
        } else {
          final hasAdminRole = _currentUser?.role.toLowerCase() == 'admin' || _currentUser?.role.toLowerCase() == 'superadmin';
          if (hasAdminRole || _userMemberships.any((m) => m.role.toLowerCase() == 'admin')) {
            activeMember = _userMemberships.firstWhere(
              (m) => m.role.toLowerCase() == 'admin' || m.role.toLowerCase() == 'superadmin',
              orElse: () => _userMemberships.first,
            );
          } else {
            activeMember = _userMemberships.first;
          }
        }

        _activeSchoolId = AppHelper.parseSingleCleanSchoolId(activeMember.schoolId) ?? activeMember.schoolId;
        _activeRole = activeMember.role;
        _activeSchoolName = activeMember.schoolName;

        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            schoolId: _activeSchoolId,
            schoolName: _activeSchoolName,
            role: _activeRole,
          );
        }
        await fetchActiveSchoolDetails();
      } else {
        _activeSchool = null;
      }
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
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
      if (_errorMessage != null && _errorMessage!.contains('dinonaktifkan')) {
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
      if (_errorMessage != null && _errorMessage!.contains('dinonaktifkan')) {
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
    String? schoolId,
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
        schoolId: schoolId,
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

      // Hanya sinkronkan ke logo sekolah jika user adalah KHUSUS ADMIN (bukan guru yang bisa switch)
      if (updatedUser.photoUrl != null && updatedUser.photoUrl!.isNotEmpty) {
        final isDedicatedAdmin = _currentUser?.role == 'admin' &&
            !_userMemberships.any((m) => m.role == 'guru');
        if (isDedicatedAdmin && _activeSchoolId != null && _activeSchoolId!.isNotEmpty) {
          try {
            await Supabase.instance.client.from('schools').update({
              'logo_url': updatedUser.photoUrl,
            }).eq('id', _activeSchoolId!);

            if (_activeSchool != null) {
              _activeSchool = _activeSchool!.copyWith(logoUrl: updatedUser.photoUrl);
            }
          } catch (syncErr) {
            debugPrint('Note syncing school logo: $syncErr');
          }
        }
      }

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

  Future<bool> updateUserRole(String userId, String role, [String? schoolId]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final targetSchoolId = schoolId ?? _activeSchoolId;
      await authRepository.updateUserRole(userId, role, targetSchoolId);
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

  Future<bool> requestExitFromSchool(String? membershipId, {String? schoolId, String? role}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (membershipId != null && membershipId.isNotEmpty) {
        await _authRepository.requestExitFromSchool(membershipId, schoolId: schoolId, role: role, userId: _currentUser?.id);
      } else if (schoolId != null && role != null && _currentUser != null) {
        final supabase = Supabase.instance.client;
        final existing = await supabase
            .from('user_schools')
            .select('id')
            .eq('user_id', _currentUser!.id)
            .eq('school_id', schoolId)
            .eq('role', role)
            .maybeSingle();

        if (existing != null) {
          await _authRepository.requestExitFromSchool(existing['id'] as String);
        } else {
          await supabase.from('user_schools').upsert({
            'user_id': _currentUser!.id,
            'school_id': schoolId,
            'role': role,
            'status': 'requested_exit',
          }, onConflict: 'user_id, school_id, role');
        }
      }
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

  Future<bool> cancelExitRequest(String? membershipId, {String? schoolId, String? role}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (membershipId != null && membershipId.isNotEmpty) {
        await _authRepository.cancelExitRequest(membershipId, schoolId: schoolId, role: role, userId: _currentUser?.id);
      } else if (schoolId != null && role != null && _currentUser != null) {
        final supabase = Supabase.instance.client;
        await supabase
            .from('user_schools')
            .update({'status': 'active'})
            .eq('user_id', _currentUser!.id)
            .eq('school_id', schoolId)
            .eq('role', role);
      }
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

  Future<List<Map<String, dynamic>>> getPendingExitRequests(String schoolId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final requests = await _authRepository.getPendingExitRequests(schoolId);
      _isLoading = false;
      notifyListeners();
      return requests;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<bool> approveExitRequest(String membershipId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.approveExitRequest(membershipId);
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

  Future<bool> rejectExitRequest(String membershipId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authRepository.rejectExitRequest(membershipId);
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

    // Deteksi error constraint database (duplicate key / unique constraint)
    if (errorString.contains('user_schools_user_id_school_id_key') ||
        (errorString.contains('duplicate key') && errorString.contains('user_schools'))) {
      return 'Akun Anda sudah terhubung dengan sekolah ini.';
    }
    if (errorString.contains('duplicate key') || errorString.contains('23505')) {
      return 'Data ini sudah terdaftar di dalam sistem.';
    }
    if (errorString.contains('row-level security') || errorString.contains('violates row-level security policy')) {
      return 'Akses ditolak oleh kebijakan keamanan sistem (RLS). Silakan hubungi admin.';
    }
    
    // Bersihkan prefix "Exception: " jika ada
    String cleaned = e.toString().replaceAll('Exception: ', '');
    // Jika ada format PostgrestException(message: ..., code: ...) ambil messagenya saja
    if (cleaned.contains('PostgrestException(') && cleaned.contains('message:')) {
      final msgMatch = RegExp(r'message:\s*([^,\)]+)').firstMatch(cleaned);
      if (msgMatch != null && msgMatch.group(1) != null) {
        cleaned = msgMatch.group(1)!.trim();
      }
    }
    return cleaned;
  }
}

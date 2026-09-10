import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/user_school_model.dart';
import '../models/school_model.dart';
import '../repositories/auth_repository.dart';
import '../services/fcm_service.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';


class AuthProvider with ChangeNotifier {
  static const String _kActiveSchoolIdKey = 'active_school_id';
  static const String _kActiveRoleKey = 'active_role';
  static String _userSchoolKey(String userId) => 'active_school_id_$userId';
  static String _userRoleKey(String userId) => 'active_role_$userId';
  final AuthRepository _authRepository;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _initialized = false; // true once the first getCurrentUser() attempt finishes
  bool _isLoadingUser = false; // guard against concurrent _loadCurrentUser() calls
  bool _isLoadingMemberships = false; // guard against concurrent loadUserMemberships() calls
  String? _errorMessage;
  bool _isRecoveryMode = false;
  bool _isSchoolExpired = false;

  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository {
    _loadCurrentUser(isInitialBoot: true);
    
    // Automatically reload profile on Auth state change (e.g. OAuth Redirect Callback)
    try {
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
    } catch (_) {
      // Supabase instance might not be initialized in test environments
    }
  }

  List<UserSchoolModel> _userMemberships = [];
  List<UserSchoolModel> _pendingMemberships = [];
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
  List<UserSchoolModel> get pendingMemberships => _pendingMemberships;
  String? get activeSchoolId => _activeSchoolId;
  String get activeSchoolName => _activeSchoolName;
  String get activeRole => _activeRole;
  SchoolModel? get activeSchool => _activeSchool;

  bool get hasMultipleSchools => _userMemberships.length > 1;

  /// True jika user adalah Admin Asli (akun dasar adalah admin/superadmin/school_admin).
  /// Admin Asli terkunci pada peran ADMIN, tidak dapat switch menjadi guru, dan hanya
  /// mengelola sekolah yang ditugaskan.
  bool get isAdminAsli {
    if (_currentUser == null) return false;
    final r = _currentUser!.role.toLowerCase();
    return r == 'admin' || r == 'superadmin' || r == 'school_admin';
  }

  /// True jika user adalah Admin Cadangan (akun dasar guru yang memiliki penugasan admin aktif
  /// di tabel user_schools untuk sekolah tertentu).
  bool get isAdminCadangan {
    if (_currentUser == null || isAdminAsli) return false;
    return _userMemberships.any(
      (m) => m.role.toLowerCase() == 'admin' && m.status?.toLowerCase() == 'active',
    );
  }

  /// True jika akun adalah Guru murni (bukan admin asli dan tidak punya penugasan admin cadangan).
  bool get isGuruMurni => !isAdminAsli && !isAdminCadangan;

  bool get isExclusiveAdmin {
    if (_currentUser == null) return false;
    if (isAdminAsli) {
      // Admin Asli yang hanya memiliki 1 sekolah kewenangan tidak perlu switcher
      return _userMemberships.where((m) => m.role.toLowerCase() == 'admin').length <= 1;
    }
    return _userMemberships.length <= 1;
  }

  Future<void> fetchActiveSchoolDetails() async {
    if (_activeSchoolId == null) {
      _activeSchool = null;
      return;
    }

    // SWR: Load from local cache immediately (0ms) so header/branding renders instantly
    if (_activeSchool == null) {
      try {
        final cached = await CacheService().loadMap('active_school_$_activeSchoolId');
        if (cached != null) {
          _activeSchool = SchoolModel.fromJson(cached);
          _activeSchoolName = _activeSchool!.name;
          notifyListeners();
        }
      } catch (_) {}
    }

    try {
      final supabase = Supabase.instance.client;
      var res = await supabase
          .from('schools')
          .select()
          .eq('id', _activeSchoolId!)
          .maybeSingle()
          .timeout(NetworkResilience.defaultQueryTimeout);

      if (res == null) {
        try {
          final tenantRes = await supabase
              .from('tenants')
              .select('id, name, school_code, status')
              .eq('id', _activeSchoolId!)
              .maybeSingle()
              .timeout(NetworkResilience.defaultQueryTimeout);
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
                .maybeSingle()
                .timeout(NetworkResilience.defaultQueryTimeout);

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
                .eq('role', 'admin')
                .timeout(NetworkResilience.defaultQueryTimeout);

            for (final u in (adminUsers as List)) {
              if (u['photo_url'] != null && (u['photo_url'] as String).trim().isNotEmpty) {
                resolvedLogo = (u['photo_url'] as String).trim();
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
        // Persist to local cache for instant 0ms offline display
        await CacheService().save('active_school_$_activeSchoolId', _activeSchool!.toJson());

        if (_activeSchool!.isInactive) {
          _isSchoolExpired = true;
          notifyListeners();
          throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator.');
        } else {
          _isSchoolExpired = false;
        }
      } else if (_activeSchool == null) {
        final cached = await CacheService().loadMap('active_school_$_activeSchoolId');
        if (cached != null) {
          _activeSchool = SchoolModel.fromJson(cached);
          _activeSchoolName = _activeSchool!.name;
        }
      }
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
        rethrow;
      }
      debugPrint('Error fetching active school details: $e');
      if (_activeSchool == null) {
        final cached = await CacheService().loadMap('active_school_$_activeSchoolId');
        if (cached != null) {
          _activeSchool = SchoolModel.fromJson(cached);
          _activeSchoolName = _activeSchool!.name;
        }
      }
    }
  }

  Future<void> switchActiveSchool(String schoolId, String schoolName, String role) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId.trim();

    // STRICT ROLE & SCHOOL ENFORCEMENT
    String effectiveRole = role.toLowerCase();
    if (isAdminAsli) {
      // Admin Asli NEVER switches to guru!
      effectiveRole = 'admin';
      final assignedSchool = AppHelper.parseSingleCleanSchoolId(_currentUser?.schoolId);
      if (assignedSchool != null && assignedSchool.isNotEmpty && cleanSchoolId != assignedSchool) {
        debugPrint('[AUTH_PROVIDER] Blocked Admin Asli from switching to unauthorized school: $cleanSchoolId');
        return;
      }
    } else if (isGuruMurni) {
      // Pure Guru NEVER switches to admin!
      effectiveRole = 'guru';
    } else if (isAdminCadangan) {
      // Admin Cadangan can only use 'admin' for schools where they have active admin membership
      if (effectiveRole == 'admin') {
        final hasAdmin = _userMemberships.any(
          (m) => m.schoolId == cleanSchoolId && m.role.toLowerCase() == 'admin' && m.status?.toLowerCase() == 'active',
        );
        if (!hasAdmin) {
          effectiveRole = 'guru';
        }
      }
    }

    _activeSchoolId = cleanSchoolId;
    _activeSchoolName = schoolName;
    _activeRole = effectiveRole;

    // IMPORTANT: DO NOT overwrite _currentUser.role! Keep base user role immutable in memory!
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        schoolId: cleanSchoolId,
        schoolName: schoolName,
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
    
    // Persist active school & role locally in background (both user-scoped and global)
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kActiveSchoolIdKey, cleanSchoolId);
      prefs.setString(_kActiveRoleKey, effectiveRole);
      if (_currentUser != null) {
        prefs.setString(_userSchoolKey(_currentUser!.id), cleanSchoolId);
        prefs.setString(_userRoleKey(_currentUser!.id), effectiveRole);
      }
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
      debugPrint('Error fetching active school details in switchActiveSchool: $e');
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

        // 3. Fallback check by npsn or id (only query id if cleanCode is a valid UUID!)
        final isCleanCodeUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanCode);
        if (isCleanCodeUuid) {
          res = await supabase
              .from('schools')
              .select()
              .or('npsn.ilike.$cleanCode,id.eq.$cleanCode')
              .eq('status', 'active')
              .maybeSingle();
        } else {
          res = await supabase
              .from('schools')
              .select()
              .ilike('npsn', cleanCode)
              .eq('status', 'active')
              .maybeSingle();
        }

        // 4. Fallback check by tenant
        if (res == null) {
          var tenantRes = await supabase
              .from('tenants')
              .select('id, name, school_code, status')
              .ilike('school_code', '%$cleanCode%')
              .maybeSingle();

          if (tenantRes == null && isCleanCodeUuid) {
            tenantRes = await supabase
                .from('tenants')
                .select('id, name, school_code, status')
                .eq('id', cleanCode)
                .maybeSingle();
          }

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

            final isTenantUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(tenantId);
            if (isTenantUuid) {
              res = await supabase
                  .from('schools')
                  .select()
                  .or('id.eq.$tenantId,code.ilike.$cleanCode')
                  .eq('status', 'active')
                  .maybeSingle();
            } else {
              res = await supabase
                  .from('schools')
                  .select()
                  .ilike('code', cleanCode)
                  .eq('status', 'active')
                  .maybeSingle();
            }

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
      final schoolId = AppHelper.parseSingleCleanSchoolId(matchedSchool.id) ?? matchedSchool.id.trim();

      final effectiveRole = role;

      // Check if user is already connected with this school in user_schools
      final existingMember = await supabase
          .from('user_schools')
          .select('id, role, status')
          .eq('user_id', _currentUser!.id)
          .eq('school_id', schoolId)
          .maybeSingle();

      if (existingMember != null) {
        final existingStatus = (existingMember['status'] as String? ?? 'active').toLowerCase();
        if (existingStatus == 'active') {
          throw Exception('Anda sudah menjadi anggota di sekolah ini.');
        } else if (existingStatus == 'pending') {
          throw Exception('Permintaan bergabung sedang menunggu persetujuan dari Admin sekolah.');
        } else if (existingStatus == 'requested_exit') {
          throw Exception('Anda memiliki pengajuan keluar yang sedang diproses untuk sekolah ini.');
        } else if (existingStatus == 'rejected' || existingStatus == 'inactive') {
          // Re-apply: update status to pending
          await supabase
              .from('user_schools')
              .update({
                'role': effectiveRole,
                'status': 'pending',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingMember['id']);
        }
      } else {
        // Check max teachers quota for new teacher join (count active teachers)
        if (effectiveRole == 'guru') {
          final existingTeachers = await supabase
              .from('user_schools')
              .select('id')
              .eq('school_id', schoolId)
              .eq('role', 'guru')
              .eq('status', 'active');
          
          final teacherCount = (existingTeachers as List).length;
          if (teacherCount >= matchedSchool.maxTeachers) {
            throw Exception('Batas maksimal ${matchedSchool.maxTeachers} guru untuk sekolah ini telah tercapai.');
          }
        }

        try {
          await supabase.from('user_schools').insert({
            'user_id': _currentUser!.id,
            'school_id': schoolId,
            'role': effectiveRole,
            'status': 'pending',
          });
        } catch (insertErr) {
          debugPrint('Note inserting user_schools: $insertErr');
          rethrow;
        }
      }

      // DO NOT call switchActiveSchool: user stays in their current school until approved!
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

  Future<void> _applyActiveMembershipFromPreferences() async {
    if (_userMemberships.isEmpty || _currentUser == null) {
      _activeSchool = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = _currentUser!.id;
    // Prefer user-scoped keys, fallback to legacy global keys
    final rawSavedSchoolId = prefs.getString(_userSchoolKey(userId)) ?? prefs.getString(_kActiveSchoolIdKey);
    final savedSchoolId = AppHelper.parseSingleCleanSchoolId(rawSavedSchoolId);
    final rawSavedRole = prefs.getString(_userRoleKey(userId)) ?? prefs.getString(_kActiveRoleKey);
    final savedRole = rawSavedRole?.toLowerCase().trim();

    UserSchoolModel? activeMember;

    if (isAdminAsli) {
      // ADMIN ASLI: Strictly locked to ADMIN and assigned school!
      final assignedSchool = AppHelper.parseSingleCleanSchoolId(_currentUser?.schoolId);
      activeMember = _userMemberships.firstWhere(
        (m) => (assignedSchool == null || m.schoolId == assignedSchool) && m.role.toLowerCase() == 'admin',
        orElse: () => _userMemberships.firstWhere(
          (m) => m.role.toLowerCase() == 'admin',
          orElse: () => _userMemberships.first,
        ),
      );
      // Clean up corrupt SharedPreferences if 'guru' was saved
      prefs.setString(_userRoleKey(userId), 'admin');
      prefs.setString(_kActiveRoleKey, 'admin');
      if (assignedSchool != null && assignedSchool.isNotEmpty) {
        prefs.setString(_userSchoolKey(userId), assignedSchool);
        prefs.setString(_kActiveSchoolIdKey, assignedSchool);
      }
    } else {
      // NON-ADMIN ASLI: Account is GURU (Pure Guru or Admin Cadangan)
      // PRIORITY 1: IN-MEMORY CONTEXT PRESERVATION
      // If the app is already running and has a valid active school and active role in memory,
      // PRESERVE IT! Opening Navbar, rebuilds, or background reload must NEVER overwrite active context!
      if (_activeSchoolId != null && _activeSchoolId!.isNotEmpty) {
        try {
          activeMember = _userMemberships.firstWhere(
            (m) => m.schoolId == _activeSchoolId && m.role.toLowerCase() == _activeRole.toLowerCase(),
          );
        } catch (_) {
          try {
            activeMember = _userMemberships.firstWhere(
              (m) => m.schoolId == _activeSchoolId && m.role.toLowerCase() == 'guru',
              orElse: () => _userMemberships.firstWhere((m) => m.schoolId == _activeSchoolId),
            );
          } catch (_) {}
        }
      }

      // PRIORITY 2: USE SAVED PREFERENCES (for initial boot / session restore)
      if (activeMember == null && savedSchoolId != null && savedSchoolId.isNotEmpty) {
        // Can user activate 'admin' role in savedSchoolId?
        // ONLY if user is Admin Cadangan AND has an active admin membership in savedSchoolId AND savedRole is explicitly 'admin'!
        final canUseAdmin = isAdminCadangan &&
            savedRole == 'admin' &&
            _userMemberships.any((m) => m.schoolId == savedSchoolId && m.role.toLowerCase() == 'admin' && m.status?.toLowerCase() == 'active');
        final targetRole = canUseAdmin ? 'admin' : 'guru';

        try {
          activeMember = _userMemberships.firstWhere(
            (m) => m.schoolId == savedSchoolId && m.role.toLowerCase() == targetRole,
          );
        } catch (_) {
          try {
            activeMember = _userMemberships.firstWhere(
              (m) => m.schoolId == savedSchoolId,
              orElse: () => _userMemberships.firstWhere(
                (m) => m.role.toLowerCase() == 'guru',
                orElse: () => _userMemberships.first,
              ),
            );
          } catch (_) {
            activeMember = _userMemberships.first;
          }
        }
      }

      // PRIORITY 3: FALLBACK TO PRIMARY USER SCHOOL (DEFAULT TO GURU!)
      if (activeMember == null) {
        final primarySchoolId = AppHelper.parseSingleCleanSchoolId(_currentUser?.schoolId);
        if (primarySchoolId != null && primarySchoolId.isNotEmpty) {
          try {
            activeMember = _userMemberships.firstWhere(
              (m) => m.schoolId == primarySchoolId && m.role.toLowerCase() == 'guru',
              orElse: () => _userMemberships.firstWhere((m) => m.schoolId == primarySchoolId),
            );
          } catch (_) {}
        }
      }

      // PRIORITY 4: ULTIMATE FALLBACK - ALWAYS PREFER GURU OVER ADMIN
      activeMember ??= _userMemberships.firstWhere(
        (m) => m.role.toLowerCase() == 'guru',
        orElse: () => _userMemberships.first,
      );
    }

    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(activeMember.schoolId) ?? activeMember.schoolId;

    // ENFORCE AUTHORITATIVE ROLE
    String finalActiveRole;
    if (isAdminAsli) {
      finalActiveRole = 'admin';
    } else if (isGuruMurni) {
      // Pure Guru can NEVER be anything other than guru!
      finalActiveRole = 'guru';
    } else {
      // Admin Cadangan: can only be 'admin' if this specific membership is 'admin' AND active!
      if (activeMember.role.toLowerCase() == 'admin' && activeMember.status?.toLowerCase() == 'active') {
        finalActiveRole = 'admin';
      } else {
        finalActiveRole = 'guru';
      }
    }

    _activeSchoolId = cleanActiveSchoolId;
    _activeRole = finalActiveRole;
    _activeSchoolName = activeMember.schoolName;

    // Persist verified user-scoped preferences
    prefs.setString(_userSchoolKey(userId), cleanActiveSchoolId);
    prefs.setString(_userRoleKey(userId), finalActiveRole);
    prefs.setString(_kActiveSchoolIdKey, cleanActiveSchoolId);
    prefs.setString(_kActiveRoleKey, finalActiveRole);

    // IMPORTANT: DO NOT overwrite _currentUser.role! Keep base user role immutable in memory!
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        schoolId: _activeSchoolId,
        schoolName: _activeSchoolName,
      );
    }
    await fetchActiveSchoolDetails();
  }

  Future<void> loadUserMemberships() async {
    if (_currentUser == null) return;
    if (_isLoadingMemberships) return;
    _isLoadingMemberships = true;

    // SWR: Load memberships immediately from cache (0ms) so app is interactive instantly
    if (_userMemberships.isEmpty) {
      try {
        final cached = await CacheService().loadList('user_memberships_${_currentUser!.id}');
        if (cached != null && cached.isNotEmpty) {
          _userMemberships = cached.map((m) => UserSchoolModel.fromJson(m)).toList();
          await _applyActiveMembershipFromPreferences();
          notifyListeners();
        }
      } catch (_) {}
    }

    try {
      final supabase = Supabase.instance.client;
      final Map<String, UserSchoolModel> membershipMap = {};

      // 1. Fetch from user_schools (FILTER ONLY ACTIVE ROWS)
      try {
        final res = await supabase
            .from('user_schools')
            .select('*, schools(id, name, code, logo_url, npsn, status)')
            .eq('user_id', _currentUser!.id)
            .eq('status', 'active')
            .timeout(NetworkResilience.defaultQueryTimeout);

        for (final item in (res as List)) {
          final m = Map<String, dynamic>.from(item as Map);
          final status = (m['status'] as String? ?? 'active').toLowerCase();
          if (status != 'active') continue; // Extra safety guard

          m['role'] = item['role'] ?? _currentUser!.role;
          final mRole = m['role'].toString().toLowerCase();

          // ADMIN ASLI PROTECTION: An Admin Asli must NEVER load 'guru' memberships!
          if (isAdminAsli && (mRole == 'guru' || mRole == 'teacher')) {
            continue;
          }

          // ADMIN ASLI PROTECTION: Only assigned school allowed for Admin Asli!
          final assignedSchool = AppHelper.parseSingleCleanSchoolId(_currentUser?.schoolId);
          final sId = AppHelper.parseSingleCleanSchoolId(m['school_id']);
          if (isAdminAsli && assignedSchool != null && assignedSchool.isNotEmpty && sId != assignedSchool) {
            continue;
          }

          if (m['schools'] == null && m['school_id'] != null) {
            if (sId != null && sId.isNotEmpty) {
              try {
                final sRes = await supabase
                    .from('schools')
                    .select('id, name, code, logo_url, status')
                    .eq('id', sId)
                    .maybeSingle()
                    .timeout(NetworkResilience.defaultQueryTimeout);
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
            .eq('user_id', _currentUser!.id)
            .timeout(NetworkResilience.defaultQueryTimeout);

        for (final item in (memRes as List)) {
          final m = Map<String, dynamic>.from(item as Map);
          final parsed = UserSchoolModel.fromJson(m);
          if (parsed.schoolId.isNotEmpty) {
            final parsedRole = parsed.role.toLowerCase();
            if (isAdminAsli && (parsedRole == 'guru' || parsedRole == 'teacher')) continue;

            final key = '${parsed.schoolId}_$parsedRole';
            if (!membershipMap.containsKey(key)) {
              membershipMap[key] = parsed;
            }
          }
        }
      } catch (_) {}

      // 3. Check for any schools listed in _currentUser.schoolIds
      // For Admin Asli, only allow their assigned school!
      final allowedSchoolIds = isAdminAsli
          ? ([AppHelper.parseSingleCleanSchoolId(_currentUser!.schoolId)].whereType<String>().toList())
          : _currentUser!.schoolIds;

      for (final sId in allowedSchoolIds) {
        final cleanId = AppHelper.parseSingleCleanSchoolId(sId);
        if (cleanId != null && cleanId.isNotEmpty) {
          final roleForMembership = isAdminAsli ? 'admin' : _currentUser!.role.toLowerCase();
          final key = '${cleanId}_$roleForMembership';
          if (!membershipMap.containsKey(key)) {
            try {
              final sRes = await supabase
                  .from('schools')
                  .select('id, name, code, logo_url, status')
                  .eq('id', cleanId)
                  .maybeSingle()
                  .timeout(NetworkResilience.defaultQueryTimeout);
              if (sRes != null) {
                membershipMap[key] = UserSchoolModel(
                  id: 'us_$cleanId',
                  userId: _currentUser!.id,
                  schoolId: cleanId,
                  role: roleForMembership,
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
                .maybeSingle()
                .timeout(NetworkResilience.defaultQueryTimeout);
          }
          if (schoolData == null && _currentUser!.schoolName != null && _currentUser!.schoolName!.isNotEmpty) {
            schoolData = await supabase
                .from('schools')
                .select('id, name, code, logo_url')
                .ilike('name', _currentUser!.schoolName!.trim())
                .maybeSingle()
                .timeout(NetworkResilience.defaultQueryTimeout);
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

      // 4. Fetch pending memberships for display in ProfilScreen
      final List<UserSchoolModel> pendingList = [];
      try {
        final pendingRes = await supabase
            .from('user_schools')
            .select('*, schools(id, name, code, logo_url, npsn, status)')
            .eq('user_id', _currentUser!.id)
            .eq('status', 'pending')
            .timeout(NetworkResilience.defaultQueryTimeout);

        for (final item in (pendingRes as List)) {
          final m = Map<String, dynamic>.from(item as Map);
          m['role'] = item['role'] ?? _currentUser!.role;
          final sId = AppHelper.parseSingleCleanSchoolId(m['school_id']);

          if (m['schools'] == null && sId != null && sId.isNotEmpty) {
            try {
              final sRes = await supabase
                  .from('schools')
                  .select('id, name, code, logo_url, status')
                  .eq('id', sId)
                  .maybeSingle()
                  .timeout(NetworkResilience.defaultQueryTimeout);
              if (sRes != null) {
                m['schools'] = sRes;
              }
            } catch (_) {}
          }

          final parsed = UserSchoolModel.fromJson(m);
          if (parsed.schoolId.isNotEmpty) {
            pendingList.add(parsed);
          }
        }
      } catch (err) {
        debugPrint('Error loading pending user_schools in memberships: $err');
      }
      _pendingMemberships = pendingList;

      if (_userMemberships.isNotEmpty) {
        // Persist to local cache for instant 0ms offline display
        await CacheService().save(
          'user_memberships_${_currentUser!.id}',
          _userMemberships.map((m) => m.toJson()).toList(),
        );
        await _applyActiveMembershipFromPreferences();
      } else {
        _activeSchool = null;
      }
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
        rethrow;
      }
      debugPrint('Error loading user memberships: $e');
      if (_userMemberships.isEmpty) {
        final cached = await CacheService().loadList('user_memberships_${_currentUser!.id}');
        if (cached != null && cached.isNotEmpty) {
          _userMemberships = cached.map((m) => UserSchoolModel.fromJson(m)).toList();
          await _applyActiveMembershipFromPreferences();
        }
      }
    } finally {
      _isLoadingMemberships = false;
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
          final prefs = await SharedPreferences.getInstance();
          final uid = user.id;
          final savedUserRole = prefs.getString(_userRoleKey(uid)) ?? prefs.getString(_kActiveRoleKey);
          final savedUserSchool = prefs.getString(_userSchoolKey(uid)) ?? prefs.getString(_kActiveSchoolIdKey);

          if (isAdminAsli) {
            _activeRole = 'admin';
            _activeSchoolId = AppHelper.parseSingleCleanSchoolId(user.schoolId) ?? user.schoolId;
          } else {
            // If in-memory is already set and valid, retain it
            if (_activeSchoolId == null || _activeSchoolId!.isEmpty) {
              _activeSchoolId = AppHelper.parseSingleCleanSchoolId(savedUserSchool) ??
                  (AppHelper.parseSingleCleanSchoolId(user.schoolId) ?? user.schoolId);
            }
            // Non-Admin Asli: Allow 'admin' if explicitly saved by this user, then loadUserMemberships() will strictly sanitize
            final canRestoreAdmin = savedUserRole?.toLowerCase() == 'admin';
            _activeRole = canRestoreAdmin ? 'admin' : 'guru';
          }
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
      if (isAdminAsli) {
        _activeRole = 'admin';
        _activeSchoolId = AppHelper.parseSingleCleanSchoolId(loggedInUser.schoolId) ?? loggedInUser.schoolId;
      } else {
        _activeRole = 'guru';
        _activeSchoolId = AppHelper.parseSingleCleanSchoolId(loggedInUser.schoolId) ?? loggedInUser.schoolId;
      }

      // Immediately write safe initial preferences for this user
      try {
        final prefs = await SharedPreferences.getInstance();
        final uid = loggedInUser.id;
        if (_activeSchoolId != null && _activeSchoolId!.isNotEmpty) {
          prefs.setString(_userSchoolKey(uid), _activeSchoolId!);
          prefs.setString(_kActiveSchoolIdKey, _activeSchoolId!);
        }
        prefs.setString(_userRoleKey(uid), _activeRole);
        prefs.setString(_kActiveRoleKey, _activeRole);
      } catch (_) {}

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
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.remove(_userSchoolKey(_currentUser!.id));
        await prefs.remove(_userRoleKey(_currentUser!.id));
      }
      await prefs.remove(_kActiveSchoolIdKey);
      await prefs.remove(_kActiveRoleKey);
    } catch (_) {}
    await authRepository.logout();
    _currentUser = null;
    _activeSchoolId = null;
    _activeSchoolName = 'Sekolah';
    _activeRole = 'guru';
    _activeSchool = null;
    _userMemberships = [];
    _pendingMemberships = [];
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

      // Evict Flutter memory image cache to guarantee instant refresh of avatars
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await CacheService().purgePrefix('teachers_');

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
      // If the modified user is current user and not Admin Asli, update local profile as well
      if (_currentUser != null && _currentUser!.id == userId && !isAdminAsli) {
        _currentUser = _currentUser!.copyWith(role: role);
      }
      try {
        await CacheService().purgePrefix('teachers_');
        await CacheService().purgePrefix('user_');
      } catch (_) {}
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

  Future<bool> rejectJoinRequest(String userId, [String? schoolId]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final targetSchoolId = schoolId ?? _activeSchoolId;
      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        throw Exception('Konteks sekolah tidak valid untuk menolak pendaftaran.');
      }
      await authRepository.rejectJoinRequest(userId, targetSchoolId);
      try {
        await CacheService().purgePrefix('teachers_');
        await CacheService().purgePrefix('user_');
      } catch (_) {}
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

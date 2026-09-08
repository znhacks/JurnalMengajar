import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/period_model.dart';
import '../models/subject_model.dart';
import '../models/hour_model.dart';
import '../models/class_model.dart';
import '../models/teacher_model.dart';
import '../models/school_model.dart';
import '../repositories/period_repository.dart';
import '../repositories/subject_repository.dart';
import '../repositories/hour_repository.dart';
import '../repositories/class_repository.dart';
import '../repositories/teacher_repository.dart';
import '../models/student_model.dart';
import '../repositories/student_repository.dart';
import '../repositories/school_repository.dart';
import '../core/services/cache_service.dart';

class MasterDataProvider with ChangeNotifier {
  final PeriodRepository periodRepository;
  final SubjectRepository subjectRepository;
  final HourRepository hourRepository;
  final ClassRepository classRepository;
  final TeacherRepository teacherRepository;
  final StudentRepository studentRepository;
  final SchoolRepository? schoolRepository;

  List<PeriodModel> _periods = [];
  List<SubjectModel> _subjects = [];
  List<HourModel> _hours = [];
  List<ClassModel> _classes = [];
  List<TeacherModel> _teachers = [];
  List<StudentModel> _students = [];
  List<SchoolModel> _schools = [];
  String? _currentSchoolId;

  bool _isLoading = false;
  String? _errorMessage;

  MasterDataProvider({
    required this.periodRepository,
    required this.subjectRepository,
    required this.hourRepository,
    required this.classRepository,
    required this.teacherRepository,
    required this.studentRepository,
    this.schoolRepository,
  });

  // Getters
  List<PeriodModel> get periods => _periods;
  List<SubjectModel> get subjects => _subjects;
  List<HourModel> get hours => _hours;
  List<ClassModel> get classes => _classes;
  List<TeacherModel> get teachers => _teachers;
  List<StudentModel> get students => _students;
  List<SchoolModel> get schools => _schools;
  String? get currentSchoolId => _currentSchoolId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PeriodModel? get activePeriod {
    try {
      return _periods.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAllData([String? schoolId]) async {
    _currentSchoolId = schoolId;
    _errorMessage = null;

    // SWR Instant Cache Population: If lists are empty, render from disk cache immediately (0ms)
    final sKey = schoolId ?? 'default';
    if (_classes.isEmpty || _subjects.isEmpty || _teachers.isEmpty || _periods.isEmpty || _hours.isEmpty) {
      try {
        final cachedPeriods = await CacheService().loadList('periods_$sKey');
        final cachedSubjects = await CacheService().loadList('subjects_$sKey');
        final cachedHours = await CacheService().loadList('hours_$sKey');
        final cachedClasses = await CacheService().loadList('classes_$sKey');
        final cachedTeachers = await CacheService().loadList('teachers_$sKey');

        bool hasAnyCache = false;
        if (cachedPeriods != null && cachedPeriods.isNotEmpty && _periods.isEmpty) {
          _periods = cachedPeriods.map((p) => PeriodModel.fromJson(p)).toList();
          hasAnyCache = true;
        }
        if (cachedSubjects != null && cachedSubjects.isNotEmpty && _subjects.isEmpty) {
          _subjects = cachedSubjects.map((s) => SubjectModel.fromJson(s)).toList();
          hasAnyCache = true;
        }
        if (cachedHours != null && cachedHours.isNotEmpty && _hours.isEmpty) {
          _hours = cachedHours.map((h) => HourModel.fromJson(h)).toList();
          hasAnyCache = true;
        }
        if (cachedClasses != null && cachedClasses.isNotEmpty && _classes.isEmpty) {
          _classes = cachedClasses.map((c) => ClassModel.fromJson(c)).toList();
          hasAnyCache = true;
        }
        if (cachedTeachers != null && cachedTeachers.isNotEmpty && _teachers.isEmpty) {
          _teachers = cachedTeachers.map((t) => TeacherModel.fromJson(t)).toList();
          hasAnyCache = true;
        }

        if (hasAnyCache) {
          _isLoading = false;
          notifyListeners();
        } else {
          _isLoading = true;
          notifyListeners();
        }
      } catch (_) {
        _isLoading = true;
        notifyListeners();
      }
    } else {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        periodRepository.getAll(schoolId).catchError((err) {
          debugPrint('[RUNTIME_DEBUG:MASTER_DATA] periods error: $err');
          return <PeriodModel>[];
        }),
        subjectRepository.getAll(schoolId).catchError((err) {
          debugPrint('[RUNTIME_DEBUG:MASTER_DATA] subjects error: $err');
          return <SubjectModel>[];
        }),
        hourRepository.getAll(schoolId).catchError((err) {
          debugPrint('[RUNTIME_DEBUG:MASTER_DATA] hours error: $err');
          return <HourModel>[];
        }),
        classRepository.getAll(schoolId).catchError((err) {
          debugPrint('[RUNTIME_DEBUG:MASTER_DATA] classes error: $err');
          return <ClassModel>[];
        }),
        (schoolId != null && schoolId.isNotEmpty)
            ? teacherRepository.getAllForSchool(schoolId).catchError((err) {
                debugPrint('[RUNTIME_DEBUG:MASTER_DATA] teachers error: $err');
                return <TeacherModel>[];
              })
            : teacherRepository.getAll().catchError((err) {
                debugPrint('[RUNTIME_DEBUG:MASTER_DATA] teachers error: $err');
                return <TeacherModel>[];
              }),
        if (schoolRepository != null && _schools.isEmpty)
          schoolRepository!.getAll().catchError((err) {
            debugPrint('[RUNTIME_DEBUG:MASTER_DATA] schools error: $err');
            return <SchoolModel>[];
          })
        else
          Future.value(_schools),
      ]);

      final newPeriods = results[0] as List<PeriodModel>;
      final newSubjects = results[1] as List<SubjectModel>;
      final newHours = results[2] as List<HourModel>;
      final newClasses = results[3] as List<ClassModel>;
      final newTeachers = results[4] as List<TeacherModel>;
      final newSchools = results[5] as List<SchoolModel>;

      // Don't overwrite existing populated cache if network returned empty due to weak signal
      if (newPeriods.isNotEmpty || _periods.isEmpty) _periods = newPeriods;
      if (newSubjects.isNotEmpty || _subjects.isEmpty) _subjects = newSubjects;
      if (newHours.isNotEmpty || _hours.isEmpty) _hours = newHours;
      if (newClasses.isNotEmpty || _classes.isEmpty) _classes = newClasses;
      if (newTeachers.isNotEmpty || _teachers.isEmpty) _teachers = newTeachers;
      if (newSchools.isNotEmpty || _schools.isEmpty) _schools = newSchools;

      debugPrint('[RUNTIME_DEBUG:MASTER_DATA] Loaded data counts -> Periods: ${_periods.length}, Subjects: ${_subjects.length}, Hours: ${_hours.length}, Classes: ${_classes.length}, Teachers: ${_teachers.length}, Schools: ${_schools.length}');
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[RUNTIME_DEBUG:MASTER_DATA] ERROR in loadAllData: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- PERIOD CRUD ---
  Future<bool> createPeriod(PeriodModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await periodRepository.create(finalModel);
      _periods = await periodRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePeriod(PeriodModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await periodRepository.update(finalModel);
      _periods = await periodRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePeriod(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await periodRepository.delete(id);
      _periods = await periodRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- SUBJECT CRUD ---
  Future<bool> createSubject(SubjectModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await subjectRepository.create(finalModel);
      _subjects = await subjectRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSubject(SubjectModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await subjectRepository.update(finalModel);
      _subjects = await subjectRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSubject(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await subjectRepository.delete(id);
      _subjects = await subjectRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- HOUR CRUD ---
  Future<bool> createHour(HourModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await hourRepository.create(finalModel);
      _hours = await hourRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateHour(HourModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await hourRepository.update(finalModel);
      _hours = await hourRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHour(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await hourRepository.delete(id);
      _hours = await hourRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- CLASS CRUD ---
  Future<bool> createClass(ClassModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await classRepository.create(finalModel);
      _classes = await classRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateClass(ClassModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final effectiveSchoolId = (model.schoolId != null && model.schoolId!.isNotEmpty)
          ? model.schoolId
          : _currentSchoolId;
      final finalModel = (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: effectiveSchoolId)
          : model;
      await classRepository.update(finalModel);
      _classes = await classRepository.getAll(_currentSchoolId ?? effectiveSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteClass(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await classRepository.delete(id);
      _classes = await classRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- SCHOOL CRUD (Plan) ---
  Future<SchoolModel?> validateActivationCode(String code) async {
    if (schoolRepository != null) {
      return await schoolRepository!.validateActivationCode(code);
    }
    return null;
  }

  Future<SchoolModel> activateSchoolWithCode({
    required String currentSchoolId,
    required String activationCode,
  }) async {
    if (schoolRepository == null) {
      throw Exception('Repository sekolah belum diinisialisasi');
    }
    _isLoading = true;
    notifyListeners();
    try {
      final updatedSchool = await schoolRepository!.activateSchoolWithCode(
        currentSchoolId: currentSchoolId,
        activationCode: activationCode,
      );
      _schools = await schoolRepository!.getAll();
      return updatedSchool;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSchoolPlan(String schoolId, String plan, String activationCode) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (schoolRepository != null) {
        await schoolRepository!.updateSchoolPlan(schoolId, plan, activationCode);
        _schools = await schoolRepository!.getAll();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- TEACHER CRUD ---
  Future<bool> createTeacher(TeacherModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      await teacherRepository.create(model);
      _teachers = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty)
          ? await teacherRepository.getAllForSchool(_currentSchoolId!)
          : await teacherRepository.getAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTeacher(TeacherModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      await teacherRepository.update(model);
      _teachers = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty)
          ? await teacherRepository.getAllForSchool(_currentSchoolId!)
          : await teacherRepository.getAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTeacher(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await teacherRepository.delete(id);
      _teachers = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty)
          ? await teacherRepository.getAllForSchool(_currentSchoolId!)
          : await teacherRepository.getAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateTeacherFromUser(UserModel user) {
    final index = _teachers.indexWhere((t) => t.email.toLowerCase() == user.email.toLowerCase());
    if (index != -1) {
      _teachers[index] = _teachers[index].copyWith(
        name: user.fullName,
        position: user.position ?? _teachers[index].position,
        address: user.address ?? _teachers[index].address,
        phoneNumber: user.phoneNumber ?? _teachers[index].phoneNumber,
        photoUrl: user.photoUrl,
      );
      notifyListeners();
    }
  }

  // --- STUDENT CRUD ---
  Future<void> loadStudentsForClass(String classId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _students = await studentRepository.getAllByClass(classId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStudent(StudentModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final finalModel = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: _currentSchoolId)
          : model;
      await studentRepository.create(finalModel);
      _students = await studentRepository.getAllByClass(model.classId);
      _classes = await classRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStudent(StudentModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      final finalModel = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: _currentSchoolId)
          : model;
      await studentRepository.update(finalModel);
      _students = await studentRepository.getAllByClass(model.classId);
      _classes = await classRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteStudent(String id, String classId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await studentRepository.delete(id);
      _students = await studentRepository.getAllByClass(classId);
      _classes = await classRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMultiplePeriods(List<String> ids) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final id in ids) {
        await periodRepository.delete(id);
      }
      _periods = await periodRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMultipleSubjects(List<String> ids) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final id in ids) {
        await subjectRepository.delete(id);
      }
      _subjects = await subjectRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMultipleHours(List<String> ids) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final id in ids) {
        await hourRepository.delete(id);
      }
      _hours = await hourRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMultipleClasses(List<String> ids) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final id in ids) {
        await classRepository.delete(id);
      }
      _classes = await classRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMultipleTeachers(List<String> ids) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final id in ids) {
        await teacherRepository.delete(id);
      }
      _teachers = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty)
          ? await teacherRepository.getAllForSchool(_currentSchoolId!)
          : await teacherRepository.getAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMultipleStudents(List<String> ids, String classId) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final id in ids) {
        await studentRepository.delete(id);
      }
      _students = await studentRepository.getAllByClass(classId);
      _classes = await classRepository.getAll(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

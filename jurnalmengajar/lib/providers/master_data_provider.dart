import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/period_model.dart';
import '../models/subject_model.dart';
import '../models/hour_model.dart';
import '../models/class_model.dart';
import '../models/teacher_model.dart';
import '../repositories/period_repository.dart';
import '../repositories/subject_repository.dart';
import '../repositories/hour_repository.dart';
import '../repositories/class_repository.dart';
import '../repositories/teacher_repository.dart';
import '../models/student_model.dart';
import '../repositories/student_repository.dart';

class MasterDataProvider with ChangeNotifier {
  final PeriodRepository periodRepository;
  final SubjectRepository subjectRepository;
  final HourRepository hourRepository;
  final ClassRepository classRepository;
  final TeacherRepository teacherRepository;
  final StudentRepository studentRepository;

  List<PeriodModel> _periods = [];
  List<SubjectModel> _subjects = [];
  List<HourModel> _hours = [];
  List<ClassModel> _classes = [];
  List<TeacherModel> _teachers = [];
  List<StudentModel> _students = [];

  bool _isLoading = false;
  String? _errorMessage;

  MasterDataProvider({
    required this.periodRepository,
    required this.subjectRepository,
    required this.hourRepository,
    required this.classRepository,
    required this.teacherRepository,
    required this.studentRepository,
  }) {
    loadAllData();
  }

  // Getters
  List<PeriodModel> get periods => _periods;
  List<SubjectModel> get subjects => _subjects;
  List<HourModel> get hours => _hours;
  List<ClassModel> get classes => _classes;
  List<TeacherModel> get teachers => _teachers;
  List<StudentModel> get students => _students;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PeriodModel? get activePeriod {
    try {
      return _periods.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadAllData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        periodRepository.getAll(),
        subjectRepository.getAll(),
        hourRepository.getAll(),
        classRepository.getAll(),
        teacherRepository.getAll(),
      ]);
      _periods = results[0] as List<PeriodModel>;
      _subjects = results[1] as List<SubjectModel>;
      _hours = results[2] as List<HourModel>;
      _classes = results[3] as List<ClassModel>;
      _teachers = results[4] as List<TeacherModel>;
    } catch (e) {
      _errorMessage = e.toString();
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
      await periodRepository.create(model);
      _periods = await periodRepository.getAll();
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
      await periodRepository.update(model);
      _periods = await periodRepository.getAll();
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
      _periods = await periodRepository.getAll();
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
      await subjectRepository.create(model);
      _subjects = await subjectRepository.getAll();
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
      await subjectRepository.update(model);
      _subjects = await subjectRepository.getAll();
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
      _subjects = await subjectRepository.getAll();
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
      await hourRepository.create(model);
      _hours = await hourRepository.getAll();
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
      await hourRepository.update(model);
      _hours = await hourRepository.getAll();
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
      _hours = await hourRepository.getAll();
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
      await classRepository.create(model);
      _classes = await classRepository.getAll();
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
      await classRepository.update(model);
      _classes = await classRepository.getAll();
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
      _classes = await classRepository.getAll();
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
      _teachers = await teacherRepository.getAll();
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
      _teachers = await teacherRepository.getAll();
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
      _teachers = await teacherRepository.getAll();
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
      await studentRepository.create(model);
      _students = await studentRepository.getAllByClass(model.classId);
      _classes = await classRepository.getAll();
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
      await studentRepository.update(model);
      _students = await studentRepository.getAllByClass(model.classId);
      _classes = await classRepository.getAll();
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
      _classes = await classRepository.getAll();
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

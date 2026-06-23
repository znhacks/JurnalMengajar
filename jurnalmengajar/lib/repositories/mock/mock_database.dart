import '../../models/user_model.dart';
import '../../models/teacher_model.dart';
import '../../models/period_model.dart';
import '../../models/subject_model.dart';
import '../../models/hour_model.dart';
import '../../models/class_model.dart';
import '../../models/schedule_model.dart';
import '../../models/journal_model.dart';
import '../../models/journal_attachment_model.dart';
import '../../models/settings_model.dart';

class MockDatabase {
  static final MockDatabase _instance = MockDatabase._internal();
  factory MockDatabase() => _instance;
  MockDatabase._internal() {
    _initData();
  }

  // Current logged in user
  UserModel? currentUser;

  // In-memory data collections
  final List<UserModel> users = [];
  final List<TeacherModel> teachers = [];
  final List<PeriodModel> periods = [];
  final List<SubjectModel> subjects = [];
  final List<HourModel> hours = [];
  final List<ClassModel> classes = [];
  final List<ScheduleModel> schedules = [];
  final List<JournalModel> journals = [];
  SettingsModel settings = SettingsModel(id: 'default', maxJournalInputDays: 3);

  void _initData() {
    // 1. Periods
    periods.addAll([
      PeriodModel(id: 'p1', name: '2025/2026 Ganjil', isActive: true),
      PeriodModel(id: 'p2', name: '2024/2025 Genap', isActive: false),
    ]);

    // 2. Subjects
    subjects.addAll([
      SubjectModel(id: 's1', name: 'Matematika', isActive: true),
      SubjectModel(id: 's2', name: 'Bahasa Inggris', isActive: true),
      SubjectModel(id: 's3', name: 'Fisika', isActive: true),
      SubjectModel(id: 's4', name: 'Kimia', isActive: true),
      SubjectModel(id: 's5', name: 'Biologi', isActive: true),
      SubjectModel(id: 's6', name: 'Sejarah', isActive: true),
    ]);

    // 3. Hours
    hours.addAll([
      HourModel(id: 'h1', teachingHour: 1, startTime: '07:00', endTime: '07:45'),
      HourModel(id: 'h2', teachingHour: 2, startTime: '07:45', endTime: '08:30'),
      HourModel(id: 'h3', teachingHour: 3, startTime: '08:30', endTime: '09:15'),
      HourModel(id: 'h4', teachingHour: 4, startTime: '09:30', endTime: '10:15'),
      HourModel(id: 'h5', teachingHour: 5, startTime: '10:15', endTime: '11:00'),
      HourModel(id: 'h6', teachingHour: 6, startTime: '11:00', endTime: '11:45'),
    ]);

    // 4. Classes
    classes.addAll([
      ClassModel(id: 'c1', periodId: 'p1', name: 'Kelas X-A', studentCount: 32),
      ClassModel(id: 'c2', periodId: 'p1', name: 'Kelas X-B', studentCount: 30),
      ClassModel(id: 'c3', periodId: 'p1', name: 'Kelas XI-MIPA 1', studentCount: 35),
      ClassModel(id: 'c4', periodId: 'p1', name: 'Kelas XII-IPS 2', studentCount: 28),
    ]);

    // 5. Teachers
    teachers.addAll([
      TeacherModel(
        id: 't1',
        name: 'Budi Santoso, M.Pd.',
        position: 'Guru Matematika',
        address: 'Jl. Merdeka No. 10, Jakarta',
        phoneNumber: '08123456789',
        email: 'budi@jurnal.com',
        photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop', // Stock male-like portrait (or just portrait)
      ),
      TeacherModel(
        id: 't2',
        name: 'Sri Wahyuni, S.Pd.',
        position: 'Guru Bahasa Inggris',
        address: 'Jl. Mawar No. 5, Bogor',
        phoneNumber: '08139876543',
        email: 'sri@jurnal.com',
        photoUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop', // Stock female-like portrait
      ),
      TeacherModel(
        id: 't3',
        name: 'Admin Utama',
        position: 'Kepala Tata Usaha',
        address: 'Gedung Sekolah R.102',
        phoneNumber: '08554433221',
        email: 'admin@jurnal.com',
        photoUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop',
      ),
    ]);

    // 6. Users
    users.addAll([
      UserModel(
        id: 'u1',
        email: 'budi@jurnal.com',
        fullName: 'Budi Santoso, M.Pd.',
        role: 'guru',
        photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop',
        phoneNumber: '08123456789',
        position: 'Guru Matematika',
        address: 'Jl. Merdeka No. 10, Jakarta',
      ),
      UserModel(
        id: 'u2',
        email: 'sri@jurnal.com',
        fullName: 'Sri Wahyuni, S.Pd.',
        role: 'guru',
        photoUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop',
        phoneNumber: '08139876543',
        position: 'Guru Bahasa Inggris',
        address: 'Jl. Mawar No. 5, Bogor',
      ),
      UserModel(
        id: 'u3',
        email: 'admin@jurnal.com',
        fullName: 'Admin Utama',
        role: 'admin',
        photoUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop',
        phoneNumber: '08554433221',
        position: 'Kepala Tata Usaha',
        address: 'Gedung Sekolah R.102',
      ),
      // Generic test login users
      UserModel(
        id: 'u4',
        email: 'guru@jurnal.com',
        fullName: 'Sri Wahyuni, S.Pd.',
        role: 'guru',
        photoUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop',
        phoneNumber: '08139876543',
        position: 'Guru Bahasa Inggris',
        address: 'Jl. Mawar No. 5, Bogor',
      ),
    ]);

    // 7. Schedules (Jadwal Mengajar)
    // We create schedules for today, yesterday, and tomorrow.
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    // Sri Wahyuni (t2 / u2 / u4) - Bahasa Inggris (s2)
    schedules.addAll([
      ScheduleModel(
        id: 'sc1',
        periodId: 'p1',
        date: yesterday,
        teachingHour: 1,
        classId: 'c1', // X-A
        subjectId: 's2', // B. Inggris
        teacherId: 't2',
        note: 'Materi: Introduction',
        isActive: true,
      ),
      ScheduleModel(
        id: 'sc2',
        periodId: 'p1',
        date: yesterday,
        teachingHour: 2,
        classId: 'c2', // X-B
        subjectId: 's2',
        teacherId: 't2',
        note: 'Materi: Greetings',
        isActive: true,
      ),
      ScheduleModel(
        id: 'sc3',
        periodId: 'p1',
        date: today,
        teachingHour: 1,
        classId: 'c1', // X-A
        subjectId: 's2',
        teacherId: 't2',
        note: 'Ulangan Harian',
        isActive: true,
      ),
      ScheduleModel(
        id: 'sc4',
        periodId: 'p1',
        date: today,
        teachingHour: 3,
        classId: 'c3', // XI-MIPA 1
        subjectId: 's2',
        teacherId: 't2',
        note: 'Materi: Analytical Exposition',
        isActive: true,
      ),
      ScheduleModel(
        id: 'sc5',
        periodId: 'p1',
        date: today,
        teachingHour: 5,
        classId: 'c4', // XII-IPS 2
        subjectId: 's2',
        teacherId: 't2',
        note: 'Discussion on projects',
        isActive: true,
      ),
      ScheduleModel(
        id: 'sc6',
        periodId: 'p1',
        date: tomorrow,
        teachingHour: 2,
        classId: 'c2', // X-B
        subjectId: 's2',
        teacherId: 't2',
        note: 'Regular class',
        isActive: true,
      ),
    ]);

    // Budi Santoso (t1 / u1) - Matematika (s1)
    schedules.addAll([
      ScheduleModel(
        id: 'sc7',
        periodId: 'p1',
        date: yesterday,
        teachingHour: 3,
        classId: 'c1', // X-A
        subjectId: 's1', // Matematika
        teacherId: 't1',
        note: 'Aljabar Dasar',
        isActive: true,
      ),
      ScheduleModel(
        id: 'sc8',
        periodId: 'p1',
        date: today,
        teachingHour: 2,
        classId: 'c3', // XI-MIPA 1
        subjectId: 's1',
        teacherId: 't1',
        note: 'Trigonometri Lanjutan',
        isActive: true,
      ),
      ScheduleModel(
        id: 'sc9',
        periodId: 'p1',
        date: today,
        teachingHour: 4,
        classId: 'c4', // XII-IPS 2
        subjectId: 's1',
        teacherId: 't1',
        note: 'Statistika Deskriptif',
        isActive: true,
      ),
    ]);

    // 8. Journals
    journals.addAll([
      // A verified journal from yesterday
      JournalModel(
        id: 'j1',
        scheduleId: 'sc1',
        date: yesterday,
        teachingHour: 1,
        classId: 'c1',
        subjectId: 's2',
        teacherId: 't2',
        material: 'Introduction and Self Identification. Students introduced themselves in front of the class.',
        sickCount: 1,
        permissionCount: 2,
        alphaCount: 0,
        note: 'Bambang was sick, Ani and Budi were on leave.',
        attachment: JournalAttachmentModel(
          id: 'ja1',
          filePath: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500',
          fileType: 'image',
          fileName: 'introduction_class.jpg',
        ),
        status: 'verified',
      ),
      // A pending journal from yesterday (waiting for approval)
      JournalModel(
        id: 'j2',
        scheduleId: 'sc2',
        date: yesterday,
        teachingHour: 2,
        classId: 'c2',
        subjectId: 's2',
        teacherId: 't2',
        material: 'Greetings and Salutations. Explaining formal and informal expressions.',
        sickCount: 0,
        permissionCount: 0,
        alphaCount: 1,
        note: 'Cecep was absent (Alpha) without notification.',
        attachment: JournalAttachmentModel(
          id: 'ja2',
          filePath: 'mock_document.pdf',
          fileType: 'pdf',
          fileName: 'cecep_absence_note.pdf',
        ),
        status: 'pending',
      ),
      // A rejected journal from yesterday for Budi
      JournalModel(
        id: 'j3',
        scheduleId: 'sc7',
        date: yesterday,
        teachingHour: 3,
        classId: 'c1',
        subjectId: 's1',
        teacherId: 't1',
        material: 'Aljabar Dasar - Suku Banyak',
        sickCount: 0,
        permissionCount: 0,
        alphaCount: 0,
        note: 'No anomalies. Reviewing basic equations.',
        status: 'rejected',
      ),
    ]);
  }
}

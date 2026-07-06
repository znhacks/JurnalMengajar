import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/schedule_model.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/period_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';

class DetailJadwalScreen extends StatefulWidget {
  final String scheduleId;
  const DetailJadwalScreen({super.key, required this.scheduleId});

  @override
  State<DetailJadwalScreen> createState() => _DetailJadwalScreenState();
}

class _DetailJadwalScreenState extends State<DetailJadwalScreen> {
  JournalModel? _existingJournal;
  bool _checkingJournal = true;

  @override
  void initState() {
    super.initState();
    _checkExistingJournal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
      if (scheduleProvider.schedules.isEmpty &&
          scheduleProvider.teacherSchedulesForSelectedDate.isEmpty) {
        scheduleProvider.loadAllSchedules();
      }
    });
  }

  Future<void> _checkExistingJournal() async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

    // Let's first wait for a tiny delay or wait for frames to ensure schedules are loaded
    await Future.delayed(Duration.zero);
    
    // Find schedule
    ScheduleModel? schedule;
    try {
      schedule = scheduleProvider.schedules.firstWhere(
        (s) => s.id == widget.scheduleId,
        orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
          (s) => s.id == widget.scheduleId,
        ),
      );
    } catch (_) {}

    if (schedule != null) {
      final allSchedules = scheduleProvider.schedules.isNotEmpty 
          ? scheduleProvider.schedules 
          : scheduleProvider.teacherSchedulesForSelectedDate;
          
      final groupSchedules = allSchedules.where((s) {
        return s.date.year == schedule!.date.year &&
            s.date.month == schedule.date.month &&
            s.date.day == schedule.date.day &&
            s.classId == schedule.classId &&
            s.subjectId == schedule.subjectId &&
            s.teacherId == schedule.teacherId &&
            s.periodId == schedule.periodId;
      }).toList();

      JournalModel? foundJournal;
      for (final s in groupSchedules) {
        final journal = await journalProvider.getJournalForSchedule(s.id);
        if (journal != null) {
          foundJournal = journal;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _existingJournal = foundJournal;
          _checkingJournal = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _checkingJournal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    // Find schedule
    ScheduleModel? schedule;
    try {
      schedule = scheduleProvider.schedules.firstWhere(
        (s) => s.id == widget.scheduleId,
        orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
          (s) => s.id == widget.scheduleId,
        ),
      );
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Jadwal')),
        body: const Center(child: Text('Jadwal tidak ditemukan')),
      );
    }

    // Find all schedule IDs in same group
    final allSchedules = scheduleProvider.schedules.isNotEmpty 
        ? scheduleProvider.schedules 
        : scheduleProvider.teacherSchedulesForSelectedDate;
        
    final groupSchedules = allSchedules.where((s) {
      return s.date.year == schedule!.date.year &&
          s.date.month == schedule.date.month &&
          s.date.day == schedule.date.day &&
          s.classId == schedule.classId &&
          s.subjectId == schedule.subjectId &&
          s.teacherId == schedule.teacherId &&
          s.periodId == schedule.periodId;
    }).toList()..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

    final hoursStr = groupSchedules.map((s) => s.teachingHour).join(', ');
    final matchedHours = masterProvider.hours
        .where((h) => groupSchedules.map((s) => s.teachingHour).contains(h.teachingHour))
        .toList()
      ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));
    final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '00:00';
    final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '00:00';

    // Resolve entities
    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.id == schedule?.teacherId,
      orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
    );

    final cls = masterProvider.classes.firstWhere(
      (c) => c.id == schedule?.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );

    final subject = masterProvider.subjects.firstWhere(
      (s) => s.id == schedule?.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final period = masterProvider.periods.firstWhere(
      (p) => p.id == schedule?.periodId,
      orElse: () => PeriodModel(id: '', name: 'Periode--', isActive: false),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Jadwal'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Informasi Kegiatan Mengajar',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const Divider(height: 32),

                        _buildDetailRow(Icons.person, 'Guru Pengampu', teacher.name),
                        _buildDetailRow(Icons.class_, 'Kelas / Siswa', '${cls.name} (${cls.studentCount} Siswa)'),
                        _buildDetailRow(Icons.menu_book, 'Mata Pelajaran', subject.name),
                        _buildDetailRow(Icons.calendar_today, 'Tanggal', AppHelper.formatDate(schedule.date)),
                        _buildDetailRow(
                          Icons.access_time,
                          'Jam Pelajaran',
                          'Jam Ke-$hoursStr ($hrStart - $hrEnd)',
                        ),
                        _buildDetailRow(Icons.date_range, 'Periode Akademik', period.name),
                        _buildDetailRow(Icons.description, 'Catatan Jadwal', schedule.note ?? 'Tidak ada catatan khusus.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Floating Bottom Button
            Padding(
              padding: EdgeInsets.all(20.w),
              child: _checkingJournal
                  ? const Center(child: CircularProgressIndicator())
                  : _existingJournal != null
                      ? Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/guru/journal/${_existingJournal!.id}');
                                },
                                icon: const Icon(Icons.assignment),
                                label: const Text('Lihat Jurnal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A), // Dark slate
                                ),
                              ),
                            ),
                            if (_existingJournal!.status == 'rejected') ...[
                              SizedBox(width: 12.w),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/guru/journal-form?scheduleId=${schedule!.id}');
                                  },
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text('Revisi Jurnal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEA580C),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : ElevatedButton.icon(
                          onPressed: () {
                            context.push('/guru/journal-form?scheduleId=${schedule!.id}');
                          },
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Isi Jurnal'),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22.w, color: const Color(0xFF0D9488)),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

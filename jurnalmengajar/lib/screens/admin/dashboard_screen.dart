import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
    await Provider.of<ScheduleProvider>(context, listen: false).loadAllSchedules();
    await Provider.of<JournalProvider>(context, listen: false).loadAllJournals();
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final totalJournals = journalProvider.journals.length;
    final totalSchedules = scheduleProvider.schedules.length;
    final totalPending = journalProvider.journals.where((j) => j.status == 'pending').length;

    // Calculate unsubmitted schedules for selected day
    final schedulesForDay = scheduleProvider.schedules.where((s) =>
        s.date.year == _selectedDay.year &&
        s.date.month == _selectedDay.month &&
        s.date.day == _selectedDay.day).toList();

    final unsubmittedCount = schedulesForDay.where((s) {
      final hasJournal = journalProvider.journals.any((j) => j.scheduleId == s.id);
      return !hasJournal;
    }).length;

    final isLoading = masterProvider.isLoading || scheduleProvider.isLoading || journalProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/dashboard'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat Datang, Admin!',
                        style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'Berikut adalah ringkasan operasional mengajar saat ini.',
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 20.h),

                      // Counter Grid Layout
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                        childAspectRatio: 1.4,
                        children: [
                          _buildStatCard(
                            'Total Jurnal',
                            '$totalJournals',
                            Icons.assignment,
                            const Color(0xFF0D9488),
                          ),
                          _buildStatCard(
                            'Total Jadwal',
                            '$totalSchedules',
                            Icons.calendar_month,
                            Colors.indigo,
                          ),
                          _buildStatCard(
                            'Butuh Approval',
                            '$totalPending',
                            Icons.rate_review,
                            Colors.amber[700]!,
                          ),
                          _buildStatCard(
                            'Belum Input',
                            '$unsubmittedCount',
                            Icons.pending_actions,
                            Colors.red[600]!,
                            subtitle: 'Hari terpilih',
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // Calendar Card
                      Text(
                        'Kalender Pemantauan',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 12.h),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: TableCalendar(
                            firstDay: DateTime.now().subtract(const Duration(days: 365)),
                            lastDay: DateTime.now().add(const Duration(days: 365)),
                            focusedDay: _focusedDay,
                            calendarFormat: CalendarFormat.month,
                            selectedDayPredicate: (day) {
                              return isSameDay(_selectedDay, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              _focusedDay = focusedDay;
                            },
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleTextStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                            ),
                            calendarStyle: CalendarStyle(
                              selectedDecoration: const BoxDecoration(
                                color: Color(0xFF0D9488),
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: const TextStyle(
                                color: Color(0xFF0D9488),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Schedule info for the selected day
                      Text(
                        'Jadwal Mengajar - ${AppHelper.formatDateShort(_selectedDay)}',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 12.h),

                      if (schedulesForDay.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            'Tidak ada jadwal terdaftar untuk hari ini.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
                              textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: schedulesForDay.length,
                          separatorBuilder: (context, index) => SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final sched = schedulesForDay[index];
                            final cls = masterProvider.classes.firstWhere(
                              (c) => c.id == sched.classId,
                              orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
                            );
                            final subj = masterProvider.subjects.firstWhere(
                              (s) => s.id == sched.subjectId,
                              orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
                            );
                            final teacher = masterProvider.teachers.firstWhere(
                              (t) => t.id == sched.teacherId,
                              orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
                            );

                            final hasJournal = journalProvider.journals.any((j) => j.scheduleId == sched.id);

                            return Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: hasJournal ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                    child: Icon(
                                      hasJournal ? Icons.check_circle_outline : Icons.pending_actions,
                                      color: hasJournal ? const Color(0xFF10B981) : Colors.red,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${cls.name} • ${subj.name}',
                                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          'Guru: ${teacher.name}',
                                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: hasJournal ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      hasJournal ? 'Sudah Input' : 'Belum Input',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                        color: hasJournal ? const Color(0xFF10B981) : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, {String? subtitle}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24.w),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey[500]),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

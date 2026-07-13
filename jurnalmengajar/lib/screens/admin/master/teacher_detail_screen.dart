import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/master_data_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../models/teacher_model.dart';
import '../../../models/schedule_model.dart';
import '../../../models/class_model.dart';
import '../../../models/subject_model.dart';
import '../../../models/hour_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/helper.dart';

class TeacherDetailScreen extends StatefulWidget {
  final String teacherId;
  const TeacherDetailScreen({super.key, required this.teacherId});

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    await Future.wait([
      scheduleProvider.loadAllSchedules(),
      journalProvider.loadAllJournals(),
    ]);
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.trim().isEmpty) {
      AppHelper.showSnackBar(context, 'Nomor WhatsApp belum terdaftar', isError: true);
      return;
    }
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }
    final url = Uri.parse('https://wa.me/$cleanPhone');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Gagal membuka WhatsApp', isError: true);
      }
    }
  }

  bool _hasTeacherScheduleOnDay(List<ScheduleModel> schedules, DateTime day) {
    return schedules.any(
      (s) =>
          s.teacherId == widget.teacherId &&
          s.isActive &&
          s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day,
    );
  }

  Widget _buildScheduledDayCell(
    DateTime day,
    bool isSelected,
    bool isToday,
    bool isOutside,
    List<ScheduleModel> schedules,
  ) {
    final hasSchedule = _hasTeacherScheduleOnDay(schedules, day);

    Color bgColor = Colors.transparent;
    Color textColor = isOutside ? AppTheme.outline : AppTheme.onBackground;
    FontWeight fontWeight = FontWeight.w500;

    if (isSelected) {
      bgColor = AppTheme.primaryColor;
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
    } else if (hasSchedule) {
      bgColor = const Color(0xFFFFEB3B).withValues(alpha: 0.35);
      textColor = isOutside ? AppTheme.outline : AppTheme.onBackground;
      fontWeight = FontWeight.w700;
    } else if (isToday) {
      bgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
      textColor = AppTheme.primaryColor;
      fontWeight = FontWeight.w700;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: hasSchedule && !isSelected
            ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 12.sp,
          fontWeight: fontWeight,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.id == widget.teacherId,
      orElse: () => TeacherModel(
        id: '',
        name: 'Guru--',
        position: 'Jabatan--',
        address: '',
        phoneNumber: '',
        email: '',
      ),
    );

    // Filter schedules for this teacher on selected day
    final dailySchedules = scheduleProvider.schedules.where((s) {
      return s.teacherId == widget.teacherId &&
          s.isActive &&
          s.date.year == _selectedDay.year &&
          s.date.month == _selectedDay.month &&
          s.date.day == _selectedDay.day;
    }).toList();

    // Filter journals for this teacher on selected day
    final dailyJournals = journalProvider.journals.where((j) {
      return j.teacherId == widget.teacherId &&
          j.date.year == _selectedDay.year &&
          j.date.month == _selectedDay.month &&
          j.date.day == _selectedDay.day;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Detail Guru'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Summary Card
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36.r,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: teacher.photoUrl != null && teacher.photoUrl!.startsWith('http')
                          ? NetworkImage(teacher.photoUrl!)
                          : (teacher.photoUrl != null ? FileImage(File(teacher.photoUrl!)) : null) as ImageProvider?,
                      child: teacher.photoUrl == null
                          ? Icon(Icons.person, size: 36.r, color: Colors.grey[400])
                          : null,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      teacher.name,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onBackground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      teacher.position,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 16),
                    // Contact Info Details
                    _buildContactRow(
                      Icons.phone_android_rounded,
                      teacher.phoneNumber.isNotEmpty ? teacher.phoneNumber : 'Belum Diisi',
                      onTap: teacher.phoneNumber.isNotEmpty ? () => _launchWhatsApp(teacher.phoneNumber) : null,
                      actionIcon: teacher.phoneNumber.isNotEmpty ? Icons.chat : null,
                      actionColor: const Color(0xFF25D366),
                    ),
                    SizedBox(height: 6.h),
                    _buildContactRow(
                      Icons.email_outlined,
                      teacher.email.isNotEmpty ? teacher.email : 'Belum Diisi',
                    ),
                    SizedBox(height: 6.h),
                    _buildContactRow(
                      Icons.location_on_outlined,
                      teacher.address.isNotEmpty ? teacher.address : 'Belum Diisi',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // 2. Weekly Calendar Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: TableCalendar(
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    leftChevronIcon: const Icon(Icons.chevron_left, color: AppTheme.primaryColor),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                    titleTextStyle: GoogleFonts.hankenGrotesk(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onBackground,
                    ),
                  ),
                  rowHeight: 42.h,
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.week,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildScheduledDayCell(day, false, false, false, scheduleProvider.schedules);
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      return _buildScheduledDayCell(day, false, false, true, scheduleProvider.schedules);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildScheduledDayCell(day, false, true, false, scheduleProvider.schedules);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return _buildScheduledDayCell(day, true, false, false, scheduleProvider.schedules);
                    },
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // 3. Jadwal Mengajar Section
              _buildSectionHeader('Jadwal Mengajar'),
              SizedBox(height: 6.h),
              dailySchedules.isEmpty
                  ? _buildEmptyState('Tidak ada jadwal mengajar pada hari ini.')
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dailySchedules.length,
                      separatorBuilder: (context, _) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final sched = dailySchedules[index];
                        final cls = masterProvider.classes.firstWhere(
                          (c) => c.id == sched.classId,
                          orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
                        );
                        final subject = masterProvider.subjects.firstWhere(
                          (s) => s.id == sched.subjectId,
                          orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
                        );
                        final hour = masterProvider.hours.firstWhere(
                          (h) => h.teachingHour == sched.teachingHour,
                          orElse: () => HourModel(id: '', teachingHour: sched.teachingHour, startTime: '00:00', endTime: '00:00'),
                        );

                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${hour.startTime}\n${hour.endTime}',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cls.name,
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.onBackground,
                                      ),
                                    ),
                                    Text(
                                      subject.name,
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 11.5.sp,
                                        color: AppTheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              SizedBox(height: 12.h),

              // 4. Jurnal Mengajar Section
              _buildSectionHeader('Jurnal Mengajar'),
              SizedBox(height: 6.h),
              dailyJournals.isEmpty
                  ? _buildEmptyState('Tidak ada jurnal mengajar pada hari ini.')
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dailyJournals.length,
                      separatorBuilder: (context, _) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final journal = dailyJournals[index];
                        final cls = masterProvider.classes.firstWhere(
                          (c) => c.id == journal.classId,
                          orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
                        );
                        final subject = masterProvider.subjects.firstWhere(
                          (s) => s.id == journal.subjectId,
                          orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
                        );

                        Color statusColor;
                        IconData statusIcon;
                        if (journal.status == 'verified') {
                          statusColor = const Color(0xFF10B981);
                          statusIcon = Icons.check_circle_rounded;
                        } else if (journal.status == 'rejected') {
                          statusColor = Colors.red;
                          statusIcon = Icons.cancel_rounded;
                        } else {
                          statusColor = const Color(0xFFF59E0B);
                          statusIcon = Icons.hourglass_empty_rounded;
                        }

                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${cls.name} • Jam ${journal.teachingHour}',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.onBackground,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      subject.name,
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 11.5.sp,
                                        color: AppTheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Sakit: ${journal.sickCount}  ·  Izin: ${journal.permissionCount}  ·  Alpa: ${journal.alphaCount}',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 10.sp,
                                        color: AppTheme.outline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(statusIcon, color: statusColor, size: 20.r),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: AppTheme.onBackground,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 11.5.sp,
          color: AppTheme.outline,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String text, {
    VoidCallback? onTap,
    IconData? actionIcon,
    Color? actionColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14.w, color: const Color(0xFF64748B)),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.5.sp,
              color: AppTheme.onBackground,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionIcon != null && onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: (actionColor ?? AppTheme.primaryColor).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(actionIcon, size: 12.w, color: actionColor ?? AppTheme.primaryColor),
            ),
          ),
      ],
    );
  }
}
